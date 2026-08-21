좋아요, 2번(CI로 옮기고 기존 훅은 제거)으로 갈게요. 남은 Q2도 물어보는 대신 제 추천대로 정리해서, 진행할 가정들을 한 번에 확정할게요.

(Q2였던 질문: CI가 ✗(실패)를 잡았을 때 실제로 머지를 막을지, 아니면 지금 훅처럼 정보성으로만 보여줄지 — 제 추천은 "정보성"이었습니다. 1인이 유지보수하는 개인 하네스 레포라 강제 게이트보다 가시성이면 충분하고, 원래 훅의 설계 철학(비차단, CLAUDE.md의 "소프트 개입 우선")과도 맞아요. 이 추천대로 갑니다.)

**진행할 가정들 — 다르면 말씀해주세요:**

- `.github/workflows/harness-doc-sync.yml`을 새로 추가해 `sh scripts/check-harness-docs.sh`를 모든 브랜치 push + `main` 대상 PR마다 돌린다 — 경로 필터는 두지 않는다. — 검사 자체가 몇 초짜리라, 경로 필터로 아끼는 것보다 필터에 안 걸려 놓치는 케이스(예: README만 고쳤을 때)를 막는 게 더 안전.
- CI 실패는 **정보성으로만 둔다** — GitHub 브랜치 보호(필수 체크)에는 등록하지 않는다. — 위 Q2 추천과 같은 이유(1인 레포, 비차단 철학).
- `ubuntu-latest` 러너에 `jq`가 기본 설치돼 있다고 보고 별도 설치 스텝을 넣지 않는다. — 스크립트가 `plugin.json` 버전 비교에 `jq`를 쓰기 때문에, 틀리면 CI 자체가 깨짐.
- 기존 `woobin-harness/hooks/harness-doc-sync-guard.sh`는 **삭제**한다(주석 처리나 미참조 방치가 아니라). — 이 레포에 "wire 안 된 잔재"가 이미 한 번 문제였던 전례가 README에 남아 있어서.
- `claude-hooks.json`·`hooks.json` 양쪽에서 해당 훅 항목을 제거한다.
- 훅 개수가 11 → 10으로 줄어드는 데 맞춰 README·두 `plugin.json`·`.claude-plugin/marketplace.json`·`docs/workflow-spec.md`(§4 인벤토리에서 해당 훅 행 삭제, R14 항목을 "PostToolUse 짝 제거"로 갱신)를 함께 고치고, 두 `plugin.json`의 `version`을 같이 올린다. — CLAUDE.md 자체 규칙("고칠 때 같이 고쳐야 하는 것").

이대로 진행해도 될까요? 확인해주시면 바로 플랜 작성(writing-plans)으로 넘어갈게요.
