---
name: internal-sso-oidc
description: |
  사내 OIDC SSO(DS SSO 계열 — Hybrid Flow form_post + RS256 id_token)를 hexagonal
  백엔드(FastAPI 등)에 연동할 때 IdP 특성·SsoVerifier 포트 패턴·세션 JWT·사용자 provisioning·
  인프라·흔한 함정을 안내한다.
  트리거: 사내/internal SSO 로그인 연동, OIDC 콜백 구현, IdP claim 매핑, 세션 토큰 설계,
  SSO 500/422/무한 리다이렉트 디버깅, id_token 검증, nonce/Redis, redirect_uri 등록.
---

# internal-sso-oidc — 사내 OIDC SSO 연동 가이드

사내 IdP(DS SSO 계열)를 hexagonal 백엔드에 붙일 때의 **확정된 사실 + 포트 패턴 + 함정 체크리스트**.
Pholex에서 SSO 로그인을 끝까지 동작시키며 얻은 지식. 다음 연동을 며칠→반나절로 줄이는 게 목적.

> ⚠️ 실제 IdP 호스트·secret·인증서는 이 파일에 평문으로 넣지 말 것. `.env`로만 주입.

## 1. 이 IdP의 확정된 특성 (가장 중요 — 표준 OIDC와 다른 점)

| 항목 | 값 | 함의 |
|------|-----|------|
| IdP 종류 | **ADFS** (Microsoft AD FS) | 엔드포인트 `/adfs/...`, 로그아웃 `wa=wsignoutcleanup1.0`, secret 불필요 |
| Flow | **Hybrid Flow**, `response_mode=form_post`, `response_type=code id_token` | 콜백은 **POST**(폼 본문), GET 아님 |
| 콜백 폼 필드 | `code`, `id_token`, `state` | 셋 다 form 본문으로 도착 |
| id_token 서명 | **RS256** (IdP 공개 인증서 / JWKS로 검증) | `JWT_SECRET`(HS) 경로로 검증하면 무조건 실패 |
| **claim key** | email→`mail`, 사번→`sabun`, 이름→`username` | 표준 `email`/`sub`/`name` **아님** ← 500의 단골 원인 |
| 기타 claim | `deptname`(부서), `Mobile`, `x-ms-forwarded-client-ip` | |
| **권한 claim** | **없음** | auth는 IdP가 안 줌 → 코드에서 산정(`ADMIN_EMAILS`), 기본 `ENGINEER` 하드코딩 |
| **고유 ID** | **없음** (`sub`/`oid` 없음) — `sabun`이 유일 식별자 | users 테이블 unique 키 = `employee_number(sabun)`. 별도 `employee_id` 컬럼 두지 말 것(항상 중복) |
| userinfo 엔드포인트 | **미사용** | id_token 단독으로 모든 정보 확보 |
| nonce | id_token claim 안에 있음 | init에서 Redis 저장(TTL 5분) → 콜백에서 대조 후 소비(삭제) |

## 2. 아키텍처 — SsoVerifier 포트 (4 메서드)

세션 토큰 create/verify까지 이 포트가 담당(real=서명 JWT, dev=plain). fake/real 분리로 사외 개발 가능.

```python
class SsoVerifier(Protocol):
    async def init_login(self, return_url: str) -> str: ...          # authorize URL
    async def verify_callback(self, code, id_token, state) -> SsoIdentityDTO: ...  # RS256+nonce+claim
    async def create_session_token(self, identity) -> str: ...       # real=HS256 JWT, dev=plain
    async def verify_session_token(self, token) -> SsoIdentityDTO: ...# JWT decode → identity
```

- **세션 토큰 = HS256 JWT** (claims: employee_number/username/email/auth_level/iat/exp, exp 180분). create와 verify가 **같은 `JWT_SECRET`** 사용(대칭). **plain 사번 쿠키 금지**(위조 가능 → 사칭).
- **dev bypass**: 콜백을 타지 않는다. `sso_init`이 `DEV_SSO_BYPASS`일 때 세션을 즉시 생성하고 리다이렉트.
- 권한 승격은 usecase에서: IdP=ENGINEER 고정 → `email ∈ ADMIN_EMAILS`면 ADMIN. 최종 auth_level이 JWT에 들어감.

## 3. 엔드포인트 계약

- `GET  /api/auth/sso/init` — dev: 세션 즉시 생성 / real: 307 → IdP authorize URL
- `POST /api/auth/callback` — **form_post**(code/id_token/state). **이 경로가 IdP 등록 redirect_uri·init_login redirect_uri와 정확히 일치해야 함** (불일치 시 422/무한루프)
- `GET  /api/auth/session` — 쿠키 JWT 검증 → 사용자 정보(없으면 `{authenticated:false}`)
- `POST /api/auth/logout` — 쿠키 만료

`python-multipart` 의존성 필요(form_post 파싱). 없으면 `RuntimeError: Form data requires "python-multipart"`.

## 4. 사용자 provisioning

`UserRepository.upsert(UserRecordDTO)` — `employee_number`(sabun) unique 키로 `INSERT … ON CONFLICT DO UPDATE last_login`. **UnitOfWork와 분리**(자기 세션을 직접 열고 commit — lot UoW에 묶지 말 것). users 테이블: `id SERIAL PK, employee_number UNIQUE NOT NULL, username, email, auth, created_at, last_login`.

## 5. 인프라

- **Redis** — nonce 저장/소비. **반드시 `redis.asyncio`** (sync 클라이언트는 `await ...set()`이 안 먹어 nonce 미저장).
- **IdP 공개 인증서** — backend 컨테이너에 마운트(`/app/certs/sso.cert`), `SSO_CERT_PATH`로 지정. 개인키/인증서는 gitignore.
- **미러 레지스트리** — 사내 폐쇄망은 Docker Hub 차단. `DOCKER_REGISTRY`(끝 슬래시) + PIP/APT/NPM 미러 env 필수. 안 하면 `docker compose up`이 pull 타임아웃.
- **compose 단일 관리** — `docker run`과 compose를 섞지 말 것(네트워크 갈라져 nginx가 `backend` DNS 못 찾음). 전부 `docker compose up`으로.

## 6. 함정 체크리스트 ⭐ (증상 → 원인 → 처치)

| 증상 | 원인 | 처치 |
|------|------|------|
| `ValidationError: email Input should be valid string` (500) | claim key 불일치(`email` vs `mail`) | claim 추출을 `mail`/`sabun`/`username`으로 |
| `null value in column / employee_id` | 없는 고유 ID로 upsert | `employee_number(sabun)` 단일키, employee_id 컬럼 제거 |
| `RuntimeError: ... unit of work context` | UserRepository를 lot UoW 세션에 묶음 | real adapter가 자기 세션 직접 open/commit |
| `PermissionError: Invalid or expired nonce` + Redis 키 없음 | **sync** redis 클라이언트로 nonce 미저장 | `import redis.asyncio as redis`, 모든 호출 await |
| 무한 리다이렉트(session 매번 401) | 세션 토큰 포맷 불일치(콜백=plain vs 검증=JWT) | 세션=HS256 JWT 양쪽 통일 |
| `422 missing code/id_token` | response_mode≠form_post 또는 redirect_uri 경로 불일치 | `response_mode=form_post`, 콜백 경로=`/api/auth/callback` 일치 |
| `Form data requires python-multipart` | 의존성 누락 | `pip install python-multipart` |
| `docker compose up` pull 타임아웃 → nginx `host not found in upstream backend` | 미러 미설정 → docker run 우회 → 네트워크 분리 | `DOCKER_REGISTRY` 등 설정 후 compose로 일괄 기동 |
| redirect_uri 가 `//api/auth/callback` (이중 슬래시) | `SSO_RETURN_URL`("/")로 redirect_uri 조립 | **`APP_BASE_URL`** 로 조립 (SSO_RETURN_URL은 로그인 후 복귀 경로용) |
| authorize URL 파라미터 깨짐(scope 공백 등) | 쿼리 raw join, 인코딩 누락 | `urllib.parse.urlencode(params)` |
| `import jwt` 인데 deps는 python-jose | PyJWT API(`import jwt`)와 의존성 불일치 | 의존성 = **PyJWT**(python-jose 아님) |

## 7. 환경변수 레퍼런스 (.env / .env.prod)

```
ADAPTER_MODE=real
DEV_SSO_BYPASS=false
IDP_LOGIN_URL=...        IDP_LOGOUT_URL=...      IDP_CLIENT_ID=...      IDP_JWKS_URI=...
SSO_CERT_PATH=/app/certs/sso.cert
APP_BASE_URL=https://<도메인:포트>          # redirect_uri = {APP_BASE_URL}/api/auth/callback
JWT_SECRET=...  JWT_ALGORITHM=HS256  JWT_ACCESS_TOKEN_EXPIRE_MINUTES=180
ADMIN_EMAILS=a@corp,b@corp                  # IdP 미제공 권한 승격
REDIS_URL=redis://redis:6379/0
DATABASE_URL=postgresql+asyncpg://...
DOCKER_REGISTRY=<사내 미러>/   PIP_INDEX_URL=...  APT_MIRROR=...  NPM_REGISTRY_URL=...
HTTPS_PORT=10004                            # host:443 매핑
```

## 8. 레퍼런스 구현 & ADFS 운영 디테일

### 8.1 Real 어댑터 레퍼런스 (복붙 템플릿)
→ **`reference-real-adapter.py`** (이 skill 폴더). 마스킹 + 버그수정된 `RealSsoVerifier` 전체
(4개 메서드 + `_load_public_key`). 다음 연동은 이 파일을 베이스로 env만 채우면 됨.
**✅ 사내 ADFS 환경에서 로그인 E2E 검증 완료 (2026-06-06).**

### 8.2 ADFS 엔드포인트 구조
```
authorize: https://<IDP_HOST>/adfs/oauth2/authorize/?client_id=<CLIENT_ID>
             &redirect_uri=https://<INTERNAL_IP>:<PORT>/api/auth/callback
             &response_type=code%20id_token&response_mode=form_post
             &scope=openid%20profile%20email&state=<S>&nonce=<N>
JWKS:      https://<IDP_HOST>/adfs/.well-known/jwks.json   (정적 cert 쓰면 미사용)
token:     https://<IDP_HOST>/adfs/oauth2/token            (Hybrid Flow에선 미사용)
logout:    https://<IDP_HOST>/adfs/ls/?wa=wsignoutcleanup1.0
```

### 8.3 redirect_uri 등록 절차 (ADFS 관리콘솔)
1. `https://<IDP_HOST>/adfs/management/` (IdP 관리자 권한)
2. Relying Party Trusts → Add → **Claims aware**
3. Identifier = `https://<INTERNAL_IP>:<PORT>/api/auth/callback`
4. Issuance Authorization = Permit all (또는 그룹 제한)
5. Endpoint: Redirect URI = 위와 동일, Response Type=`code id_token`, Response Mode=`form_post`
6. Client ID 발급(UUID). **Secret 불필요**(Hybrid form_post)
7. 서명 인증서: IdP 생성 → RP가 공개키(cert) 다운로드 → `sso.cert`로 배치
8. Claim Rules: `sabun`/`username`/`mail`/`deptname`/`Mobile` 내보내기
9. 저장 후 즉시 활성. **새 도메인/포트마다 redirect_uri 추가 등록** 필요.

### 8.4 로그아웃 / 세션 만료 재인증
- **로그아웃(RP-initiated)**: 백엔드 `/logout`이 쿠키 삭제 → 프론트가
  `window.location.assign(IDP_LOGOUT_URL)`로 IdP 로그아웃.
  `IDP_LOGOUT_URL=https://<IDP_HOST>/adfs/ls/?wa=wsignoutcleanup1.0`
  (post_logout_redirect_uri 미지원 시 앱 메인으로 수동 복귀).
- **세션 만료 재인증(silent)**:
  - Pholex JWT 만료(180분) → `/session` 401 → 프론트가 `/api/auth/sso/init`로 →
    **IdP 세션 살아있으면 사용자 개입 없이 즉시 재인증**(callback 복귀).
  - IdP 세션도 만료(보통 8h) → IdP 로그인 화면.
  - 별도 "세션 만료" 페이지 불필요.
