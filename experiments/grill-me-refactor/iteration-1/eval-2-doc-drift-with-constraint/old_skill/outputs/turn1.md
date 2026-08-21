레포를 확인해보니 이미 거의 다 만들어져 있어요. 순서대로 설명할게요.

**이미 있는 것 (안 만들어도 됨)**

- `scripts/check-harness-docs.sh` — 훅·에이전트·스킬 개수를 `ls`로 직접 세서 README, `woobin-harness/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, `docs/workflow-spec.md`의 선언값과 대조하고, 훅·에이전트 파일이 `docs/workflow-spec.md` §4 인벤토리에 등재됐는지, `woobin-harness/`가 바뀌었는데 문서가 안 따라왔는지까지 git diff로 판정합니다. → **1번(개수 자동화)은 이미 해결돼 있어요.**
- `woobin-harness/hooks/harness-doc-sync-guard.sh` — `woobin-harness/` 아래 파일을 저장할 때마다(PostToolUse: Edit/Write/MultiEdit) 위 스크립트를 자동으로 돌려서 결과를 세션당 1회, 비차단으로 알려줍니다. Claude Code(`claude-hooks.json`)·Codex(`hooks.json`) 양쪽에 이미 wire돼 있고요. → **2번(빠뜨리면 알림)도 이미 해결돼 있어요.**
- 방금 직접 돌려봤는데 지금은 `동기화됨`(모든 개수 일치, exit 0)입니다 — 현재 훅 11개·에이전트 4개·스킬 28개가 문서와 다 맞아떨어져요.

즉 스킬을 하나 추가해서 `woobin-harness/skills/...`에 파일을 저장하는 순간, 이 훅이 자동으로 개수 불일치를 잡아서 알려주는 동작이 R14(2026-08-10)에 이미 만들어져 있었어요 — 지금 요청하신 것과 정확히 같습니다.

**그런데 3번("훅을 새로 만들기 싫다")이 애매해지는 지점이 있어요.** 방금 찾은 게 정확히 "훅"이거든요. 새로 *만들* 필요는 없지만, 계속 쓰려면 훅 하나(`harness-doc-sync-guard.sh`)가 계속 살아있는 채로 갑니다. 여기부터는 진짜 선택이 필요해요.

**Q1/2 — 이 검사를 어디서 계속 돌릴까요?**

1. **지금 있는 훅을 그대로 쓴다** — 아무것도 새로 안 만듦. 파일을 저장할 때마다 세션당 1회 비차단 알림. 바로 다음 스킬 추가부터 그대로 작동합니다.
2. **CI(GitHub Actions)로 옮기고 기존 훅은 뺀다** — `.github/workflows/`에 워크플로우를 새로 추가해 `check-harness-docs.sh`를 push/PR마다 돌리고, `harness-doc-sync-guard.sh`는 삭제합니다. 이 레포 자신의 R14 무효화 조건에 이미 이렇게 적혀 있어요 — *"CI가 같은 검사를 돌리게 됨 → PostToolUse 짝은 중복이므로 제거하고 스크립트만 남긴다."* 결과적으로 하네스 훅 개수가 11→10으로 줄고, 세션 내 알림 대신 PR 체크로 바뀝니다.

→ 1번은 손댈 게 없고, 2번은 워크플로우 파일을 새로 쓰고 기존 훅 하나를 지우는 작업(+ 그에 따른 문서 개수 갱신)이 필요해요. 이 저장소는 `github.com/woobin-the-creator/claude-harness`에 올라가 있어서 GitHub Actions는 바로 쓸 수 있는 인프라입니다.

**추천: 1번.** 이미 만들어져서 검증까지 끝난 걸 그대로 쓰는 게 제일 쌉니다. "훅을 새로 만들기 싫다"는 요청은 이미 있는 걸 재사용하면 애초에 걸리지 않고요. CI로 옮길 이유는 "세션 밖에서도(예: 다른 도구로 직접 파일을 고칠 때) 강제로 잡고 싶다" 같은 새 요구가 생길 때 커집니다.

어느 쪽으로 갈까요?
