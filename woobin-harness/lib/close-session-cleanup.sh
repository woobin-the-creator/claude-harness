#!/bin/bash
# /close-session 워크트리·브랜치 정리 (bash 3.2 호환)
#
# 호출자: idle-return-guard.sh(UserPromptSubmit 훅, 정상 경로)와
#         skills/close-session/SKILL.md(훅이 안 걸렸을 때의 fallback).
# 둘이 같은 규칙을 쓰게 하려고 스크립트 하나로 뺐다 — 훅 쪽에만 넣으면 fallback이,
# 스킬 쪽에만 넣으면 정상 경로가 정리를 건너뛴다.
#
# 사용법: close-session-cleanup.sh <cwd>
# 출력:   사용자에게 보여줄 한국어 리포트(plain text)를 stdout으로. 정리할 게 없으면 아무것도 안 찍는다.
#         모델을 거치지 않고 종료 메시지에 그대로 붙으므로 토큰 비용 0.
# 환경변수: CLOSE_SESSION_DRY_RUN=1 → 판정만 하고 아무것도 지우지 않는다(리포트에 [dry-run] 표기).
#          CLOSE_SESSION_NO_FETCH=1 → 원격 fetch 생략(오프라인·속도).
#          CLOSE_SESSION_DISK_MIN_GB / _DISK_MAX_PCT / _MEM_MIN_PCT → 자원 임계값(기본 20 / 85 / 10).
#          CLOSE_SESSION_KEEP_APPS="A:B" → 이번 실행에서만 보존(콜론 구분).
#          CLOSE_SESSION_QUIT_APPS="A:B" → 이번 실행에서만 종료(conf 정책을 무시). 스택은 "docker/<프로젝트>".
#          CLOSE_SESSION_KEEP_CONF     → 정책 파일 경로(기본 ~/.claude/close-session-keep.conf).
#          CLOSE_SESSION_KEEP_AUTOMATION=1 → 자동화 브라우저 절을 통째로 끈다.
#          CLOSE_SESSION_KEEP_DOCKER=1     → 도커 스택 절을 통째로 끈다.
#
# 안전 규칙 (사용자 결정, 2026-08-05):
#   - 대상: 이 레포에 붙은 모든 워크트리(.claude/·.codex/·orca/ 무관). 단 본체와 현재 CWD 워크트리는 제외.
#   - 제거 조건 3개 전부: 미커밋 변경 없음 + HEAD가 origin/<default>의 조상 + locked 아님.
#     하나라도 어긋나면 **건드리지 않고 보고만** 한다(stash·--force 금지).
#   - 브랜치: origin/<default>에 머지된 것 + upstream이 gone 인 것. 삭제는 `git branch -d` 만 —
#     -D 를 쓰지 않으므로 미머지 커밋이 날아가는 경우가 구조적으로 없다(squash 머지된 gone 브랜치는
#     -d 가 거부하므로 삭제 명령을 안내만 하고 남긴다).
#
# 자원 규칙 (사용자 결정, 2026-08-07):
#   - 임계 미달이면 한 줄도 안 찍는다. 프로브는 전부 읽기 전용이고 합쳐서 1초 미만이다
#     (실측: df 5ms · memory_pressure 5ms · ps 25ms · docker system df 0.9s).
#   - 디스크 임계: 여유 20GB 미만 또는 사용률 85% 이상.
#     자동 삭제는 **docker dangling 이미지 + 빌드캐시뿐**이다(`image prune -f` + `builder prune -f`).
#     태그 붙은 미사용 이미지·볼륨·컨테이너는 건드리지 않는다 — 볼륨엔 dev/prod DB가 들어있어서
#     `system prune --volumes` 는 안내조차 하지 않는다. 나머지는 회수 여지만 보고한다.
#   - 메모리 임계: free 10% 미만. 프로세스를 죽이지 않는다 — 상위 소비 5개를 보고만 한다.
#     세션 종료가 RAM 을 직접 비워주지 못하므로 여기서 할 수 있는 건 판단 근거 제공까지다.
#
# 무엇을 끄는가 (사용자 결정, 2026-08-12):
#   목적은 세션이 띄우고 안 내린 **일회용** 자원을 걷어내는 것이다. 상시 쓰는 툴이 아니다.
#   그래서 대상을 두 갈래로 나눈다 — 갈라놓는 기준이 서로 다르기 때문이다.
#
#   (1) 출처로 잡는 것 — 이름으로는 구분이 불가능한 것들. 정책·frontmost 와 무관하게 끈다.
#       · 자동화 브라우저: Playwright 가 띄운 Chrome 도 프로세스 이름은 그냥 "Google Chrome" 이다.
#         --remote-debugging-* / --user-data-dir 서명으로 잡는다.
#       · 도커 스택: compose working_dir 이 이 레포(본체·워크트리) 안이면 이 세션 것으로 본다.
#
#   (2) 이름으로 잡는 것 — 사용자가 직접 켠 GUI 앱. conf 의 정책을 따른다.
#         keep     : 무조건 보존
#         ondemand : CLOSE_SESSION_QUIT_APPS 에 콕 집었을 때만 종료
#         idle     : 활동 경로가 N일째 안 바뀌었을 때만 종료. 경로를 못 읽으면 보존
#
#   판정 불가는 항상 보존 쪽으로 넘어간다 — 잘못 살려두는 대가는 메모리 몇 GB 지만,
#   잘못 죽이는 대가는 사용자가 쓰던 작업이다. (1)이 (2)의 keep 을 무시하는 것도 같은 계산이다:
#   거기서 날아갈 건 임시 프로필·재시작 가능한 컨테이너뿐이고, keep 이 걸리면 목적 자체가 무력화된다.
#
#   - 이전 버전은 APPS 를 공백 분리로 순회해서 여러 단어 이름(Google Chrome 등)을
#     pgrep 이 못 잡았다 — 사실상 보호되고 있었다. 목록을 줄 단위로 바꿔 고쳤다.
#     그때 "Google Chrome" 이 새로 죽게 되는데, 실측해보니 떠 있던 1894MB 가 전부
#     ms-playwright-mcp 인스턴스였다 — 즉 이름 기반 판정 자체가 틀린 층위였다.

cwd="${1:-$PWD}"
cd "$cwd" 2>/dev/null || cd "$HOME" || exit 0

# ── 자원(디스크·메모리) ─────────────────────────────────────────────────────
# git 구간보다 먼저 잰다. 저장소 밖에서 /close-session 을 쳐도 자원 점검은 돌아야 하는데,
# 아래 git 게이트가 거기서 exit 하기 때문이다(디스크·메모리는 레포와 무관한 관심사다).
res=""

# df -P: POSIX 출력이라 장치명이 길어도 한 줄로 고정된다($4=여유KB, $5=사용률%).
disk=$(df -kP "$HOME" 2>/dev/null | tail -1)
avail_gb=$(printf '%s\n' "$disk" | awk '{printf "%d", $4/1048576}')
disk_pct=$(printf '%s\n' "$disk" | awk '{gsub(/%/,"",$5); printf "%d", $5}')
min_gb=${CLOSE_SESSION_DISK_MIN_GB:-20}
max_pct=${CLOSE_SESSION_DISK_MAX_PCT:-85}

if [ -n "$avail_gb" ] && { [ "$avail_gb" -lt "$min_gb" ] || [ "${disk_pct:-0}" -ge "$max_pct" ]; }; then
  res="$res
💾 디스크: 여유 ${avail_gb}GB · ${disk_pct}% 사용 — 임계(여유 ${min_gb}GB 또는 ${max_pct}%) 도달"

  # 데몬이 죽어 있으면 system df 가 즉시 실패한다 — 그걸 그대로 liveness 체크로 쓴다.
  dsd=$(docker system df --format '{{.Type}}|{{.Reclaimable}}' 2>/dev/null)
  if [ -n "$dsd" ]; then
    if [ -n "$CLOSE_SESSION_DRY_RUN" ]; then
      res="$res
  정리[dry-run]: docker image prune -f · docker builder prune -f"
    else
      # 둘 다 마지막 줄이 "Total reclaimed space: <크기>" 라 같은 sed 로 뽑힌다.
      f_img=$(docker image prune -f 2>/dev/null | sed -n 's/^Total[^:]*:[[:space:]]*//p')
      f_bc=$(docker builder prune -f 2>/dev/null | sed -n 's/^Total[^:]*:[[:space:]]*//p')
      res="$res
  정리: docker dangling 이미지 ${f_img:-0B} · 빌드캐시 ${f_bc:-0B} 회수"
    fi

    # 남는 회수 여지는 보고만. 태그 붙은 미사용 이미지는 재빌드·재pull 비용이 있고,
    # 볼륨엔 dev/prod DB 가 들어있어서 자동 삭제도 안내도 하지 않는다.
    left=$(printf '%s\n' "$dsd" | awk -F'|' '
      $1=="Images"        {i=$2}
      $1=="Local Volumes" {v=$2}
      END {printf "미사용 이미지 %s · 볼륨 %s", i, v}')
    res="$res
  남은 여지(수동): $left — 이미지만 비우려면  docker image prune -a"
  fi

  res="$res
  그 밖: npm 캐시  npm cache clean --force  ·  pnpm store prune  ·  ~/Library/Caches"
fi

# memory_pressure 는 macOS 전용이다. 없으면(리눅스 등) 이 절은 통째로 건너뛴다.
mem_free=$(memory_pressure 2>/dev/null | sed -n 's/^System-wide memory free percentage: *\([0-9]*\)%.*/\1/p')
mem_min=${CLOSE_SESSION_MEM_MIN_PCT:-10}
if [ -n "$mem_free" ] && [ "$mem_free" -lt "$mem_min" ]; then
  swap=$(sysctl -n vm.swapusage 2>/dev/null | sed 's/  */ /g')
  # 프로세스를 죽이지 않는다 — 무엇이 먹고 있는지만 보여주고 판단은 사용자가 한다.
  procs=$(ps -Ao rss=,pid=,comm= 2>/dev/null | sort -rn | head -5 | awk -v h="$HOME" '{
    rss=$1; pid=$2; $1=""; $2=""; sub(/^ +/, "");
    c=$0; if (index(c, h) == 1) c = "~" substr(c, length(h) + 1);
    if (length(c) > 52) c = "…" substr(c, length(c) - 50);
    printf "    %5dMB  %-6s %s\n", rss/1024, pid, c
  }')
  res="$res
🧠 메모리: 여유 ${mem_free}% — 임계(${mem_min}%) 도달   swap: ${swap:-n/a}
  상위 소비(RSS):
$procs"
fi

# ── 활성 자원 정리 (세션에서 켜진 VM · 앱 · 캐시) ─────────────────────────────
# 사용자 결정 (2026-08-09): /close-session 은 단순 handoff 방지가 아니라
# 세션 종료 시 켜둔 자원까지 정리한다. 임계치와 무관하게 항상 실행 —
# 세션 종료라는 맥락에서 "안 쓰는 걸 끄는 것"이 보수적일 필요가 없다.
# 단, frontmost 앱 · Hermes · Terminal · 시스템 데몬은 절대 건드리지 않는다.
cleanup=""

# 정책 파일은 3단계로 찾는다. 머신마다 켜둔 앱이 다르니 사용자 파일이 이겨야 하고,
# 그게 없는 새 머신에서도 정책이 **있긴 해야** 한다 — 없으면 전부 "정책 없음"이 되어
# 사용자가 직접 켠 앱까지 종료 대상이 된다. 즉 파일 부재의 기본값은 보수적인 쪽이 아니라
# 가장 공격적인 쪽이다. 그래서 동봉 기본값을 마지막 단계로 둔다.
#   1. CLOSE_SESSION_KEEP_CONF              명시 지정
#   2. ~/.claude/close-session-keep.conf    이 머신의 설정
#   3. 이 스크립트 옆의 close-session-keep.conf.default   새 머신의 출발점
if [ -n "$CLOSE_SESSION_KEEP_CONF" ]; then
  KEEP_CONF="$CLOSE_SESSION_KEEP_CONF"
elif [ -f "$HOME/.claude/close-session-keep.conf" ]; then
  KEEP_CONF="$HOME/.claude/close-session-keep.conf"
else
  KEEP_CONF="$(cd "$(dirname "$0")" 2>/dev/null && pwd)/close-session-keep.conf.default"
fi

# osascript 는 Automation/Accessibility 권한이 없는 컨텍스트에서 TCC 프롬프트를 띄우지도
# 못한 채 **영원히 블록된다**. 이 스크립트는 UserPromptSubmit 훅에서 동기로 도니까
# 그러면 세션이 통째로 멈춘다. macOS 엔 timeout(1) 이 없어서 직접 상한을 건다.
# 성공 시 stdout 그대로, 시간 초과면 124.
run_bounded() {
  local secs="$1"; shift
  local out pid i=0 limit
  limit=$(( secs * 10 ))
  out=$(mktemp -t close-session-bounded 2>/dev/null) || return 1
  # 서브셸로 감싸지 마라 — $! 가 osascript 자신이어야 kill 이 먹는다.
  "$@" >"$out" 2>/dev/null &
  pid=$!
  while [ "$i" -lt "$limit" ] && kill -0 "$pid" 2>/dev/null; do
    sleep 0.1
    i=$(( i + 1 ))
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill -9 "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    rm -f "$out"
    return 124
  fi
  wait "$pid" 2>/dev/null
  cat "$out"
  rm -f "$out"
  return 0
}

# 콜론 구분 목록에 이름이 있나. 앱 이름에 공백이 들어가므로 구분자는 반드시 ':' 다.
in_colon_list() {
  local name="$1" list="$2" a oldifs="$IFS"
  [ -n "$list" ] || return 1
  IFS=:; set -- $list; IFS="$oldifs"
  for a in "$@"; do
    [ "$a" = "$name" ] && return 0
  done
  return 1
}

# conf 의 앱 정책 조회. stdout: "keep" | "ondemand" | "idle|<일수>|<경로,경로…>" | ""
# (빈 값 = 정책 없음 = 기본 규칙대로 종료). 환경변수는 여기서 안 본다 — app_may_quit 에서 본다.
app_policy() {
  local name="$1" line
  [ -f "$KEEP_CONF" ] || return 0
  # 마지막 줄에 개행이 없어도 읽히도록 || [ -n "$line" ].
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    [ -z "$line" ] && continue
    [ "$line" = "keep|$name" ]     && { printf 'keep';     return 0; }
    [ "$line" = "ondemand|$name" ] && { printf 'ondemand'; return 0; }
    case "$line" in
      "idle|$name|"*) printf 'idle|%s' "${line#idle|$name|}"; return 0 ;;
    esac
  done < "$KEEP_CONF"
  return 0
}

# 활동 경로들이 전부 <일수>보다 오래됐으면 0(=idle, 종료 가능), 아니면 1(=보존).
# 판정 불가(기준 시각 생성 실패·읽히는 경로 없음)도 1 이다 — 모르면 안 죽인다.
app_is_idle() {
  local days="$1" paths="$2" ref cutoff p hit any=0 oldifs="$IFS"
  # BSD date(macOS) 우선, 없으면 GNU date. 둘 다 실패하면 판정 불가.
  cutoff=$(date -v-"${days}"d +%Y%m%d%H%M 2>/dev/null) \
    || cutoff=$(date -d "-${days} days" +%Y%m%d%H%M 2>/dev/null) \
    || return 1
  [ -n "$cutoff" ] || return 1
  ref=$(mktemp -t close-session-keep 2>/dev/null) || return 1
  touch -t "$cutoff" "$ref" 2>/dev/null || { rm -f "$ref"; return 1; }

  IFS=,; set -- $paths; IFS="$oldifs"
  for p in "$@"; do
    case "$p" in "~/"*) p="$HOME/${p#\~/}" ;; esac
    [ -e "$p" ] || continue
    any=1
    # head -1 이 파이프를 닫아 find 가 SIGPIPE 로 조기 종료한다 — 활성인 앱(흔한 경우)에서
    # 트리를 끝까지 훑지 않는다. -quit 은 find 구현마다 있고 없어서 안 쓴다.
    hit=$(find "$p" -maxdepth 4 -newer "$ref" -print 2>/dev/null | head -1)
    [ -n "$hit" ] && { rm -f "$ref"; return 1; }
  done
  rm -f "$ref"
  [ "$any" = 1 ] || return 1
  return 0
}

# 종료해도 되나? 0=종료, 1=보존. 보존이면 사유를 skip_reason 에 담는다.
#
# 우선순위 — 위가 이긴다:
#   1. CLOSE_SESSION_KEEP_APPS  (이번 실행만 보존)   ← 두 환경변수에 다 있으면 보존이 이긴다
#   2. CLOSE_SESSION_QUIT_APPS  (이번 실행만 종료)   ← conf 의 keep·ondemand·idle 을 전부 무시
#   3. conf 의 정책
# 두 환경변수가 conf 를 이기는 이유는 같다 — 지금 이 실행에 대한 **명시적 지시**이기 때문이다.
# 충돌하면 보존으로 넘긴다. 이 스크립트에서 모호함은 항상 안 죽이는 쪽이다.
app_may_quit() {
  local name="$1" pol d days paths
  skip_reason=""
  if in_colon_list "$name" "$CLOSE_SESSION_KEEP_APPS"; then
    skip_reason="CLOSE_SESSION_KEEP_APPS"; return 1
  fi
  in_colon_list "$name" "$CLOSE_SESSION_QUIT_APPS" && return 0
  pol=$(app_policy "$name")
  case "$pol" in
    keep)
      skip_reason="keep 목록"; return 1 ;;
    ondemand)
      skip_reason="ondemand — CLOSE_SESSION_QUIT_APPS 에 넣어야 종료"; return 1 ;;
    "idle|"*)
      d="${pol#idle|}"; days="${d%%|*}"; paths="${d#*|}"
      if app_is_idle "$days" "$paths"; then
        skip_reason=""; return 0
      fi
      skip_reason="최근 ${days}일 내 사용(또는 활동 경로 판정 불가)"; return 1 ;;
  esac
  return 0
}

# --- VM (Claude Desktop Linux 샌드박스, UTM, Parallels) ---
vm_pids=$(pgrep -f "com.apple.Virtualization.VirtualMachine" 2>/dev/null)
if [ -n "$vm_pids" ]; then
  # Claude.app 이 띄운 VM 이면 앱을 정상 종료 → VM 도 함께 내려감.
  # 단 Claude 가 보존 대상이면 VM 도 못 내린다 — 앱을 안 끄고 보고만 한다.
  if pgrep -x "Claude" >/dev/null 2>&1 && ! app_may_quit "Claude"; then
    cleanup="$cleanup
🖥️  VM: Claude Desktop VM 실행 중 — Claude 보존($skip_reason)이라 유지. 직접 끄려면 Claude 를 종료해라"
  elif pgrep -x "Claude" >/dev/null 2>&1; then
    if [ -n "$CLOSE_SESSION_DRY_RUN" ]; then
      cleanup="$cleanup
🖥️  VM[dry-run]: Claude Desktop VM 종료 예정 (osascript quit)"
    else
      run_bounded 10 osascript -e 'quit app "Claude"' >/dev/null; sleep 3
      # 여전히 살아있으면 직접 종료
      if pgrep -f "com.apple.Virtualization.VirtualMachine" >/dev/null 2>&1; then
        echo "$vm_pids" | while IFS= read -r pid; do kill "$pid" 2>/dev/null; done
        sleep 2
        echo "$vm_pids" | while IFS= read -r pid; do kill -9 "$pid" 2>/dev/null; done
      fi
      cleanup="$cleanup
🖥️  VM: Claude Desktop VM 종료"
    fi
  else
    # Claude.app 없이 떠 있는 VM — 사용자가 직접 판단하도록 보고만
    cleanup="$cleanup
🖥️  VM: 알 수 없는 Virtualization VM 실행 중 (PID $(echo "$vm_pids" | tr '\n' ' ')) — 수동 확인 필요"
  fi
fi

# --- 자동화 브라우저 (e2e·MCP 가 띄우고 안 내려간 것) ---
# 이 절이 종료 스텝의 **본래 목적**이다. 아래 유휴 앱 절과 달리 앱 이름이 아니라
# 프로세스 서명으로 잡는다 — Playwright 가 띄운 Chrome 도 프로세스 이름은 그냥
# "Google Chrome" 이라 이름으로는 일상용과 구분이 불가능하다(2026-08-12 실측:
# 떠 있던 "Google Chrome" 1894MB 가 전부 ms-playwright-mcp 인스턴스였다).
#
# frontmost 여부·keep 목록과 무관하게 죽인다. 프로필이 임시 디렉터리라 날아갈
# 사용자 데이터가 없고, 이름 기반 keep 이 여기에 걸리면 목적 자체가 무력화된다.
# 정말 살려야 하면 CLOSE_SESSION_KEEP_AUTOMATION=1.
if [ -z "$CLOSE_SESSION_KEEP_AUTOMATION" ]; then
  # --type= 있는 건 렌더러/GPU 헬퍼다. 최상위만 죽이면 자식은 같이 내려간다.
  auto_procs=$(ps -axo pid=,rss=,args= 2>/dev/null | awk '
    /--type=/ { next }
    /--remote-debugging-pipe|--remote-debugging-port|--enable-automation|--headless/ ||
    /--user-data-dir=[^ ]*(ms-playwright|playwright|puppeteer|\/var\/folders\/|\/tmp\/)/ {
      print $1 "\t" $2
    }')
  if [ -n "$auto_procs" ]; then
    auto_n=$(printf '%s\n' "$auto_procs" | grep -c .)
    # 최상위 RSS 만 더하면 크게 과소보고된다 — 브라우저 메모리는 렌더러/GPU 헬퍼에 있다
    # (실측: 최상위 277MB, 트리 전체 1894MB). 부모를 죽이면 자식도 같이 내려가므로
    # 회수량은 트리 전체로 센다.
    auto_mb=$(ps -axo pid=,ppid=,rss= 2>/dev/null | awk \
      -v roots="$(printf '%s\n' "$auto_procs" | cut -f1 | tr '\n' ' ')" '
      { pid[NR]=$1; ppid[NR]=$2; rss[NR]=$3; n=NR }
      END {
        split(roots, r, " ")
        for (i in r) if (r[i] != "") mark[r[i]]=1
        changed=1
        while (changed) {
          changed=0
          for (i=1; i<=n; i++) if (!mark[pid[i]] && mark[ppid[i]]) { mark[pid[i]]=1; changed=1 }
        }
        for (i=1; i<=n; i++) if (mark[pid[i]]) s+=rss[i]
        print int(s/1024)
      }')
    if [ -n "$CLOSE_SESSION_DRY_RUN" ]; then
      cleanup="$cleanup
🤖 자동화 브라우저[dry-run]: ${auto_n}개 종료 예정 (${auto_mb}MB) — PID $(printf '%s\n' "$auto_procs" | cut -f1 | tr '\n' ' ')"
    else
      printf '%s\n' "$auto_procs" | cut -f1 | while IFS= read -r p; do kill "$p" 2>/dev/null; done
      sleep 2
      printf '%s\n' "$auto_procs" | cut -f1 | while IFS= read -r p; do kill -9 "$p" 2>/dev/null; done
      cleanup="$cleanup
🤖 자동화 브라우저: ${auto_n}개 종료 (${auto_mb}MB 회수)"
    fi
  fi
fi

# --- 도커 스택 (세션 중 띄우고 안 내린 것) ---
# 자동화 브라우저와 같은 목적이고, 판정 기준도 같은 성격이다 — 이름이 아니라 **출처**로 잡는다.
# compose 프로젝트의 working_dir 이 이 레포(본체 또는 워크트리) 안이면 이 세션이 띄운 것으로 본다.
# 그 밖의 프로젝트는 다른 일이 쓰고 있을 수 있어 **보고만** 한다.
#
# stop 이지 down 이 아니다. down 은 컨테이너·네트워크를 지워서 되돌리기가 비싸고,
# 메모리 회수라는 목적에는 stop 으로 충분하다(`docker start` 로 그대로 복구된다).
# 볼륨은 어느 쪽이든 안 건드린다 — dev/prod DB 가 거기 있다.
#
# 정책은 앱과 같은 conf 를 쓰되 이름 앞에 'docker/' 를 붙인다. 정책 엔진·우선순위가 하나뿐이어야
# 앱은 지켜지고 스택은 안 지켜지는 식으로 갈라지지 않는다:
#   keep|docker/<프로젝트>      ·  ondemand|docker/<프로젝트>
#   CLOSE_SESSION_QUIT_APPS="docker/myapp"
# 접두사가 'docker/' 이지 'docker:' 가 아닌 이유는 콜론이 그 환경변수들의 구분자라서다 —
# "docker:myapp" 은 "docker" 와 "myapp" 두 항목으로 쪼개져 아무것도 매칭되지 않는다.
# 절 전체를 끄려면 CLOSE_SESSION_KEEP_DOCKER=1.
if [ -z "$CLOSE_SESSION_KEEP_DOCKER" ]; then
  # 구분자로 탭을 쓰지 마라. 탭은 POSIX 의 IFS **공백문자**라 IFS 로 지정해도 연속 구분자가
  # 하나로 합쳐진다 — compose 라벨이 빈 단독 컨테이너에서 필드가 통째로 밀려, 컨테이너
  # 이름이 프로젝트명 자리에 들어간다. US(0x1f)는 비공백이라 빈 필드가 보존된다.
  US=$(printf '\037')
  # 데몬이 죽어 있으면 즉시 실패한다 — 그걸 그대로 liveness 체크로 쓴다(위 disk 절과 같은 방식).
  dps=$(docker ps --format "{{.ID}}${US}{{.Label \"com.docker.compose.project\"}}${US}{{.Label \"com.docker.compose.project.working_dir\"}}${US}{{.Names}}" 2>/dev/null)
  if [ -n "$dps" ]; then
    # 이 레포에 속한 경로 전부. 워크트리는 레포 안(.claude/worktrees/)에도, 밖(~/.paseo/worktrees/)에도
    # 있어서 toplevel 하나로는 못 덮는다.
    prefixes=$(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
    [ -n "$prefixes" ] || prefixes=$(pwd)

    mine=""; others=0; loose=0
    while IFS="$US" read -r cid proj wdir cname; do
      [ -n "$cid" ] || continue
      if [ -z "$proj" ]; then
        loose=$(( loose + 1 ))   # compose 라벨 없는 단독 컨테이너 — 출처를 알 수 없다
        continue
      fi
      match=0
      while IFS= read -r pfx; do
        [ -n "$pfx" ] || continue
        case "$wdir" in "$pfx"|"$pfx"/*) match=1; break ;; esac
      done <<EOFPFX
$prefixes
EOFPFX
      if [ "$match" = 1 ]; then
        mine="$mine
$proj"
      else
        others=$(( others + 1 ))
      fi
    done <<EOFDPS
$dps
EOFDPS

    mine=$(printf '%s\n' "$mine" | grep -v '^[[:space:]]*$' | sort -u)
    while IFS= read -r proj; do
      [ -n "$proj" ] || continue
      if ! app_may_quit "docker/$proj"; then
        [ -n "$CLOSE_SESSION_DRY_RUN" ] && cleanup="$cleanup
🛡️  스택[dry-run]: $proj 보존 ($skip_reason)"
        continue
      fi
      cids=$(docker ps -q --filter "label=com.docker.compose.project=$proj" 2>/dev/null)
      [ -n "$cids" ] || continue
      n=$(printf '%s\n' "$cids" | grep -c .)
      # MemUsage 는 "123.4MiB / 7.77GiB" 꼴이다. 앞쪽만 쓴다.
      mb=$(docker stats --no-stream --format '{{.MemUsage}}' $cids 2>/dev/null | awk '
        { v=$1
          if (v ~ /GiB$/)      { sub(/GiB$/,"",v); s += v * 1024 }
          else if (v ~ /MiB$/) { sub(/MiB$/,"",v); s += v }
          else if (v ~ /KiB$/) { sub(/KiB$/,"",v); s += v / 1024 }
        } END { print int(s) }')
      if [ -n "$CLOSE_SESSION_DRY_RUN" ]; then
        cleanup="$cleanup
🐳 스택[dry-run]: $proj 정지 예정 — 컨테이너 ${n}개 (${mb:-0}MB)"
      else
        docker stop $cids >/dev/null 2>&1
        cleanup="$cleanup
🐳 스택: $proj 정지 — 컨테이너 ${n}개 (${mb:-0}MB 회수).  docker start 로 복구"
      fi
    done <<EOFMINE
$mine
EOFMINE

    # 남의 것은 절대 안 건드린다. 다만 메모리를 찾는 중이라면 알고는 있어야 한다.
    if [ "$others" -gt 0 ] || [ "$loose" -gt 0 ]; then
      cleanup="$cleanup
🐳 스택: 이 레포 밖 compose 컨테이너 ${others}개 · compose 아닌 컨테이너 ${loose}개 실행 중 — 손대지 않음"
    fi
  fi
fi

# --- 유휴 앱 (브라우저 · 채팅 · 미디어) ---
# frontmost 앱은 보호. 100MB+ 메모리 사용하는 후보만.
frontmost=$(run_bounded 5 osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true')
frontmost_rc=$?

# ⚠️ 줄 단위다. 공백 구분으로 되돌리지 마라 — "Google Chrome" 이 두 토큰으로 쪼개져
# pgrep 이 아무것도 못 잡고, 여러 단어 이름 앱이 통째로 조용히 누락된다(2026-08-12 수정).
APPS="Google Chrome
Chromium
Vivaldi
Brave Browser
Discord
Slack
Microsoft Teams
Zoom
Telegram
KakaoTalk
Spotify
Notion
Obsidian
Logi Options+
Perplexity
Comet
Orca
Paseo"

# frontmost 를 못 알아냈으면 앱 절을 통째로 건넌다. 빈 문자열로 진행하면 지금 쓰고 있는
# 앱이 보호를 잃는다 — 판정 불가는 보존 쪽으로 넘긴다는 이 스크립트의 규칙 그대로다.
if [ "$frontmost_rc" -ne 0 ] || [ -z "$frontmost" ]; then
  cleanup="$cleanup
🛡️  앱: frontmost 판정 실패(osascript 권한/응답 없음) — 앱 정리를 건너뜀"
  APPS=""
fi

while IFS= read -r app; do
  [ -n "$app" ] || continue
  [ "$app" = "$frontmost" ] && continue
  pgrep -x "$app" >/dev/null 2>&1 || continue

  if ! app_may_quit "$app"; then
    # 보존은 정상이라 평소엔 안 찍는다(무소식이 곧 안 건드렸다는 뜻). dry-run 때만
    # 보여준다 — 예외 설정이 먹었는지 확인하는 게 dry-run 의 용도다.
    [ -n "$CLOSE_SESSION_DRY_RUN" ] && cleanup="$cleanup
🛡️  앱[dry-run]: $app 보존 ($skip_reason)"
    continue
  fi

  # 메모리 합산 (여러 프로세스일 수 있음)
  mem_kb=$(ps -axo rss=,comm= 2>/dev/null | grep -i "$app" | awk '{sum+=$1} END {print sum+0}')
  [ "${mem_kb:-0}" -lt 102400 ] && continue   # 100MB 미만이면 둠
  mem_mb=$(( mem_kb / 1024 ))
  if [ -n "$CLOSE_SESSION_DRY_RUN" ]; then
    cleanup="$cleanup
🔲  앱[dry-run]: $app (${mem_mb}MB) 종료 예정"
  else
    run_bounded 10 osascript -e "quit app \"$app\"" >/dev/null; sleep 1
    pgrep -x "$app" >/dev/null 2>&1 && pkill -x "$app" 2>/dev/null
    cleanup="$cleanup
🔲  앱: $app 종료 (${mem_mb}MB 회수)"
  fi
done <<EOF
$APPS
EOF

# --- 개발 캐시 (재생성됨, 안전) ---
cache_dirs="$HOME/Library/Caches/com.openai.codex
$HOME/Library/Caches/pip
$HOME/Library/Caches/pnpm
$HOME/Library/Caches/go-build
$HOME/Library/Caches/electron
$HOME/Library/Caches/orca-updater
$HOME/Library/Caches/Homebrew
$HOME/Library/Caches/claude-cli-nodejs"
cache_freed_kb=0
while IFS= read -r dir; do
  [ -d "$dir" ] || continue
  sz=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
  [ "${sz:-0}" -lt 51200 ] && continue   # 50MB 미만이면 스킵
  if [ -n "$CLOSE_SESSION_DRY_RUN" ]; then
    cleanup="$cleanup
🧹 캐시[dry-run]: $(basename "$dir") ($(( sz / 1024 ))MB) 삭제 예정"
  else
    rm -rf "${dir:?}/"* 2>/dev/null
    cache_freed_kb=$(( cache_freed_kb + sz ))
  fi
done <<EOF
$cache_dirs
EOF
if [ "$cache_freed_kb" -gt 0 ] && [ -z "$CLOSE_SESSION_DRY_RUN" ]; then
  cleanup="$cleanup
🧹 캐시: $(( cache_freed_kb / 1024 ))MB 정리"
fi

# 정리 결과가 있으면 res 앞에 붙인다 (자원 점검 결과보다 먼저 표시)
if [ -n "$cleanup" ]; then
  res="${cleanup}
${res}"
fi

# ── git 구간 게이트 ─────────────────────────────────────────────────────────
# 서브모듈/워크트리 어디서 호출돼도 공용 저장소 기준으로 판단한다.
if ! git rev-parse --show-toplevel >/dev/null 2>&1; then
  [ -n "$res" ] && printf '%s\n' "$res"
  exit 0
fi

default=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's@^origin/@@')
[ -n "$default" ] || default=main

# fetch 는 유일한 네트워크 접근이자 유일한 행 위험이다. 자격증명 프롬프트로 멈추지 않게 막고,
# 오프라인이면 조용히 실패시켜 마지막으로 알던 ref 로 degrade 한다.
if [ -z "$CLOSE_SESSION_NO_FETCH" ]; then
  GIT_TERMINAL_PROMPT=0 git fetch --prune --quiet origin 2>/dev/null
fi

base="origin/$default"
git rev-parse --verify --quiet "$base" >/dev/null 2>&1 || base=""

repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
self_wt="$repo_root"
main_wt=$(git worktree list --porcelain 2>/dev/null | sed -n '1s/^worktree //p')

# 절대경로를 본체 기준 상대경로로 줄여 읽기 쉽게. 바깥(.codex/·orca/)이면 ~ 축약만.
short_path() {
  case "$1" in
    "$main_wt"/*) printf '%s' "${1#$main_wt/}" ;;
    "$HOME"/*)    printf '~/%s' "${1#$HOME/}" ;;
    *)            printf '%s' "$1" ;;
  esac
}

removed_wt=""
kept_wt=""
wt_branches=""

consider_wt() {
  [ -n "$wt" ] || return 0
  [ "$wt" = "$main_wt" ] && return 0
  [ "$wt" = "$self_wt" ] && return 0

  local label reason dirty
  label=$(short_path "$wt")
  [ -n "$br" ] && label="$label ($br)"

  if [ "$locked" = "1" ]; then
    kept_wt="$kept_wt
  유지: $label — locked"
    [ -n "$br" ] && wt_branches="$wt_branches
$br"
    return 0
  fi

  if [ ! -d "$wt" ]; then
    return 0   # 경로가 사라진 껍데기 — 아래 prune 이 처리한다
  fi

  # `git worktree remove` 는 --force 없이는 미추적 파일에도 거부한다. 그래서 추적/미추적을
  # 나눠 보여준다 — "미추적만 7건"이면 사용자가 지워도 되는 빌드 산출물인지 바로 판단한다.
  local untracked
  dirty=$(git -C "$wt" status --porcelain 2>/dev/null | grep -c .)
  untracked=$(git -C "$wt" status --porcelain 2>/dev/null | grep -c '^??')
  if [ "${dirty:-0}" -gt 0 ]; then
    kept_wt="$kept_wt
  유지: $label — 미커밋 ${dirty}건(추적 $((dirty - untracked)) · 미추적 ${untracked})"
    [ -n "$br" ] && wt_branches="$wt_branches
$br"
    return 0
  fi

  if [ -z "$base" ]; then
    kept_wt="$kept_wt
  유지: $label — 기준 브랜치(origin/$default) 없음"
    [ -n "$br" ] && wt_branches="$wt_branches
$br"
    return 0
  fi

  if ! git merge-base --is-ancestor "$sha" "$base" 2>/dev/null; then
    kept_wt="$kept_wt
  유지: $label — origin/$default 에 미머지"
    [ -n "$br" ] && wt_branches="$wt_branches
$br"
    return 0
  fi

  if [ -n "$CLOSE_SESSION_DRY_RUN" ]; then
    removed_wt="$removed_wt
  제거[dry-run]: $label"
    return 0
  fi

  if reason=$(git worktree remove "$wt" 2>&1); then
    removed_wt="$removed_wt
  제거: $label"
  else
    kept_wt="$kept_wt
  유지: $label — 제거 실패: $(printf '%s' "$reason" | head -1)"
    [ -n "$br" ] && wt_branches="$wt_branches
$br"
  fi
}

wt=""; sha=""; br=""; locked=0
# 파이프 대신 here-doc — 파이프면 루프가 서브셸에서 돌아 누적 변수가 전부 버려진다.
while IFS= read -r line; do
  case "$line" in
    "worktree "*) consider_wt; wt=${line#worktree }; sha=""; br=""; locked=0 ;;
    "HEAD "*)     sha=${line#HEAD } ;;
    "branch refs/heads/"*) br=${line#branch refs/heads/} ;;
    "locked"*)    locked=1 ;;
  esac
done <<EOF
$(git worktree list --porcelain 2>/dev/null)
EOF
consider_wt

[ -n "$CLOSE_SESSION_DRY_RUN" ] || git worktree prune 2>/dev/null

# ── 브랜치 ──────────────────────────────────────────────────────────────────
deleted_br=""
kept_br=""
current_br=$(git branch --show-current 2>/dev/null)

merged_list=""
[ -n "$base" ] && merged_list=$(git branch --merged "$base" --format='%(refname:short)' 2>/dev/null)
gone_list=$(git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads/ 2>/dev/null \
  | grep '\[gone\]$' | sed 's/ \[gone\]$//')

candidates=$(printf '%s\n%s\n' "$merged_list" "$gone_list" | grep -v '^$' | sort -u)

while IFS= read -r b; do
  [ -n "$b" ] || continue
  [ "$b" = "$default" ] && continue
  [ "$b" = "$current_br" ] && continue
  printf '%s\n' "$wt_branches" | grep -qxF "$b" && continue   # 남은 워크트리가 쓰는 중

  # dry-run 이면 -d 를 돌리지 않고 같은 판정(= base 의 조상인가)만 흉내낸다.
  if [ -n "$CLOSE_SESSION_DRY_RUN" ]; then
    if [ -n "$base" ] && git merge-base --is-ancestor "$b" "$base" 2>/dev/null; then
      deleted_br="$deleted_br
  삭제[dry-run]: $b"
    else
      kept_br="$kept_br
  유지[dry-run]: $b — 원격에서 사라졌지만 미머지 커밋 있음 → 확인 후  git branch -D $b"
    fi
    continue
  fi

  if git branch -d "$b" >/dev/null 2>&1; then
    if printf '%s\n' "$merged_list" | grep -qxF "$b"; then
      deleted_br="$deleted_br
  삭제: $b (머지됨)"
    else
      deleted_br="$deleted_br
  삭제: $b (원격에서 사라짐)"
    fi
  else
    kept_br="$kept_br
  유지: $b — 원격에서 사라졌지만 미머지 커밋 있음 → 확인 후  git branch -D $b"
  fi
done <<EOF
$candidates
EOF

# ── 리포트 ──────────────────────────────────────────────────────────────────
out=""
[ -n "$removed_wt$kept_wt" ] && out="$out
🧹 워크트리$removed_wt$kept_wt"
[ -n "$deleted_br$kept_br" ] && out="$out
🌿 브랜치$deleted_br$kept_br"
out="$out$res"

[ -n "$out" ] && printf '%s\n' "$out"
exit 0
