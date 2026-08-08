# 사내 OIDC(ADFS) Real SSO 어댑터 — 레퍼런스 템플릿 (마스킹 적용)
# ✅ 사내 검증됨 (2026-06-06): 아래 3개 수정(redirect_uri=APP_BASE_URL, urlencode, PyJWT)
#    적용 후 실제 ADFS SSO 로그인 E2E 정상 확인됨.
#
# 출처: Pholex real/sso_verifier.py 를 마스킹 + 버그 수정한 버전.
# 실제 값(IdP 호스트/client_id/secret/cert/내부IP)은 모두 settings(=env)로만 주입.
#
# 원본 대비 수정(3):
#   1) redirect_uri = APP_BASE_URL 기반 (원본은 SSO_RETURN_URL="/" 사용 → "//api/..." 버그)
#   2) authorize URL 을 urllib.parse.urlencode 로 인코딩 (원본은 raw join → scope 공백 등 깨짐)
#   3) JWT 라이브러리 = PyJWT (import jwt). deps 도 "PyJWT" (python-jose 아님)
from __future__ import annotations

import logging
import secrets
import time
from urllib.parse import urlencode

import jwt  # PyJWT
from cryptography import x509
from cryptography.hazmat.primitives.asymmetric import rsa

import redis.asyncio as redis

from app.config import settings
from app.ports.dto import SsoIdentityDTO

logger = logging.getLogger(__name__)


class RealSsoVerifier:
    """사내 OIDC(ADFS) Hybrid Flow 검증기. id_token=RS256, 세션=HS256 JWT, nonce=Redis."""

    def __init__(self) -> None:
        self._issuer = settings.IDP_LOGIN_URL          # https://<IDP_HOST>/adfs/oauth2/authorize/
        self._client_id = settings.IDP_CLIENT_ID       # <CLIENT_ID>
        self._jwks_uri = settings.IDP_JWKS_URI         # https://<IDP_HOST>/adfs/.well-known/jwks.json (정적 cert 쓰면 미사용)
        self._cert_path = settings.SSO_CERT_PATH       # /app/certs/sso.cert (IdP 서명 공개 인증서)
        self._secret_key = settings.JWT_SECRET         # <SECRET> (세션 JWT 서명)
        self._algorithm = settings.JWT_ALGORITHM       # "HS256"
        self._token_expiry = settings.JWT_ACCESS_TOKEN_EXPIRE_MINUTES * 60
        self._redis = (
            redis.from_url(settings.REDIS_URL, decode_responses=True)
            if settings.REDIS_URL else None
        )

    async def init_login(self, return_url: str) -> str:
        """authorize URL 반환 (Hybrid Flow). nonce 를 Redis 에 5분 TTL 로 저장(리플레이 방지)."""
        state = secrets.token_urlsafe(32)
        nonce = secrets.token_urlsafe(32)
        if self._redis:
            await self._redis.set(f"nonce:{nonce}", "1", ex=300)  # async! sync 클라이언트면 저장 안 됨
        else:
            logger.error("Redis not configured — nonce not stored")

        params = {
            "client_id": self._client_id,
            # ★ redirect_uri 는 APP_BASE_URL 기반. IdP 등록 redirect_uri 와 정확히 일치해야 함.
            "redirect_uri": f"{settings.APP_BASE_URL}/api/auth/callback",
            "response_type": "code id_token",  # Hybrid Flow
            "response_mode": "form_post",      # 콜백을 POST 본문으로
            "scope": "openid profile email",
            "state": state,
            "nonce": nonce,
        }
        return f"{self._issuer}?{urlencode(params)}"  # ★ 적절한 URL 인코딩

    async def verify_callback(self, code: str, id_token: str, state: str) -> SsoIdentityDTO:
        """id_token RS256 서명 검증 + nonce(Redis 소비) + claim 추출."""
        public_key = await self._load_public_key()
        try:
            decoded = jwt.decode(
                id_token,
                key=public_key,
                algorithms=["RS256"],
                options={"require": ["exp", "iat", "nonce"], "verify_aud": False},  # ADFS는 aud 미검증
            )
        except jwt.ExpiredSignatureError as e:
            raise PermissionError(f"ID token expired: {e}")
        except jwt.InvalidTokenError as e:
            raise PermissionError(f"Invalid ID token: {e}")

        # nonce 소비(consume): 삭제된 키 수로 존재 확인
        nonce = decoded.get("nonce")
        if self._redis:
            if not await self._redis.delete(f"nonce:{nonce}"):
                raise PermissionError("Invalid or expired nonce")

        # 사내 ADFS claim key 매핑 (표준 email/sub/name 아님!)
        return SsoIdentityDTO(
            employee_number=str(decoded["sabun"]),   # 사번
            username=str(decoded["username"]),       # 이름
            email=str(decoded["mail"]),              # 이메일
            auth_level="ENGINEER",                   # IdP 미제공 → 하드코딩(권한 승격은 usecase의 ADMIN_EMAILS)
        )

    async def create_session_token(self, identity: SsoIdentityDTO) -> str:
        """세션 쿠키용 HS256 JWT 생성 (claims: employee_number/username/email/auth_level/iat/exp)."""
        now = int(time.time())
        payload = {
            "employee_number": identity.employee_number,
            "username": identity.username,
            "email": identity.email,
            "auth_level": identity.auth_level,  # 이미 ADMIN_EMAILS 반영된 최종 권한
            "iat": now,
            "exp": now + self._token_expiry,
        }
        return jwt.encode(payload, self._secret_key, algorithm=self._algorithm)

    async def verify_session_token(self, token: str) -> SsoIdentityDTO:
        """세션 JWT(HS256) 검증 → identity. 위조/만료 시 PermissionError."""
        if not token:
            raise PermissionError("empty session token")
        try:
            decoded = jwt.decode(
                token, self._secret_key, algorithms=[self._algorithm],
                options={"require": ["exp", "employee_number"]},
            )
        except jwt.ExpiredSignatureError as e:
            raise PermissionError(f"Session token expired: {e}")
        except jwt.InvalidTokenError as e:
            raise PermissionError(f"Invalid session token: {e}")
        return SsoIdentityDTO(
            employee_number=str(decoded.get("employee_number")),
            username=str(decoded.get("username")),
            email=str(decoded["email"]) if decoded.get("email") else None,
            auth_level=decoded.get("auth_level", "ENGINEER"),
        )

    async def _load_public_key(self):
        """IdP 서명 공개 인증서(PEM, X.509)에서 RSA 공개키 추출. (JWKS fetch 대신 정적 cert 방식)"""
        if not self._cert_path:
            raise PermissionError("SSO_CERT_PATH not configured")
        try:
            with open(self._cert_path, "rb") as f:
                cert = x509.load_pem_x509_certificate(f.read())
            public_key = cert.public_key()
            if not isinstance(public_key, rsa.RSAPublicKey):
                raise PermissionError("Certificate is not an RSA public key")
            return public_key
        except FileNotFoundError:
            raise PermissionError(f"SSO certificate not found: {self._cert_path}")


# 의존성 (backend/pyproject.toml):
#   "PyJWT>=2.8"            # import jwt — id_token RS256 검증 + 세션 HS256 JWT
#   "cryptography>=42.0"    # X.509 인증서 파싱
#   "redis>=5.0"            # redis.asyncio (nonce 저장/소비) — sync 클라이언트 금지
#   "python-multipart>=0.0.9"  # form_post 파싱
