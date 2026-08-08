#!/usr/bin/env bash
# 컨텍스트 크기 경고 statusline (claude-buddy wrapper)
#
# 왜 wrapper인가: claude-buddy는 별도 저장소(~/codespace/claude-buddy)라
# buddy-status.sh를 직접 고치면 upstream 업데이트에서 지워진다.
# 이 스크립트가 stdin을 한 번 읽어 (1) 컨텍스트 경고 줄을 먼저 출력하고
# (2) 원본 stdin을 그대로 buddy-status.sh에 넘긴다.
#
# 왜 필요한가 (2026-07-28 실측): 세션 7b447615가 43k → 444k로 자라는 동안
# 아무 신호가 없어 180요청을 그대로 완주했고, cache read만 44.2M tok($22.08,
# 세션 비용의 66%)이 나갔다. 차단이 아니라 "지금 끊어야 할 때"의 상시 인지만 준다.

BUDDY="$HOME/codespace/claude-buddy/statusline/buddy-status.sh"

input=$(cat)

# ─── 컨텍스트 토큰 산출 ───────────────────────────────────────────────────────
# transcript의 마지막 assistant usage = 그 시점 프롬프트 전체 크기
# (input + cache_read + cache_creation). statusline은 1초마다 도므로
# transcript mtime이 그대로면 캐시된 값을 재사용한다.
ctx=""
tp=$(printf '%s' "$input" | jq -r '.transcript_path // empty' 2>/dev/null)

if [ -n "$tp" ] && [ -f "$tp" ]; then
    cdir="$HOME/.claude/statusline-ctx"
    mkdir -p "$cdir"
    key=$(basename "$tp" .jsonl)
    cache="$cdir/$key"
    mt=$(stat -f %m "$tp" 2>/dev/null || stat -c %Y "$tp" 2>/dev/null)

    if [ -f "$cache" ]; then
        read -r c_mt c_ctx < "$cache" 2>/dev/null
        [ "$c_mt" = "$mt" ] && ctx="$c_ctx"
    fi

    if [ -z "$ctx" ]; then
        ctx=$(tail -n 40 "$tp" 2>/dev/null | jq -rR '
            fromjson? // empty
            | select(.type == "assistant")
            | .message.usage // empty
            | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)
        ' 2>/dev/null | tail -n 1)
        case "$ctx" in ''|*[!0-9]*) ctx="" ;; esac
        [ -n "$ctx" ] && printf '%s %s\n' "$mt" "$ctx" > "$cache"
    fi
fi

# ─── 경고 줄 출력 ─────────────────────────────────────────────────────────────
# 200k = 장문 컨텍스트 프리미엄 구간 진입, 300k = 분할 권장
WARN=${CTX_WARN_THRESHOLD:-200000}
DANGER=${CTX_DANGER_THRESHOLD:-300000}

if [ -n "$ctx" ] && [ "$ctx" -gt 0 ] 2>/dev/null; then
    NC=$'\033[0m'
    k=$(( ctx / 1000 ))
    if [ "$ctx" -ge "$DANGER" ]; then
        printf '%s\n' "$(printf '\033[1;38;2;255;85;85m')⛔ ctx ${k}k — handoff 후 새 세션 권장${NC}"
    elif [ "$ctx" -ge "$WARN" ]; then
        printf '%s\n' "$(printf '\033[38;2;255;193;7m')⚠ ctx ${k}k — 작업 경계에서 끊을 것${NC}"
    else
        printf '%s\n' "$(printf '\033[2m')ctx ${k}k${NC}"
    fi
fi

# ─── 원본 stdin을 buddy에 그대로 전달 ─────────────────────────────────────────
[ -x "$BUDDY" ] && printf '%s' "$input" | "$BUDDY"

exit 0
