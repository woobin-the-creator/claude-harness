# Task 1: 플랜 진입 가드 정규식 확장

**Files:**
- Modify: `woobin-harness/hooks/plan-session-boundary-guard.sh:33`

**Interfaces:**
- Consumes: 없음
- Produces: 없음 (훅 내부 변경). Task 3이 이 변경 사실을 `home/HARNESS-LOG.md` #17에 옮긴다.

**배경:** 이 훅은 "플랜 작성에 들어가기 전 세션 경계를 상기시킨다"가 목적이고, ctx ≥120k일 때만 발화한다. 2026-08-10 7일 전수에서 플랜 진입 프롬프트 3건 중 1건(`플랜 문서 작성하자`, ctx 138k)이 트리거 정규식에 안 걸려 새어나갔다. `플랜 작성`은 두 어절이 붙어 있어야만 매치되는데 사이에 "문서"가 끼었기 때문이다.

- [ ] **Step 1: 실패하는 테스트를 먼저 작성**

`/tmp/t1.sh`로 저장한다. 훅은 ctx가 임계 미만이면 조용히 나가므로, **정규식만** 떼어내 검사한다.

```sh
#!/bin/sh
# 현재 정규식(수정 전)
RE_OLD='writing-plans|플랜 작성|플랜 짜|플랜 가자|플랜으로 가|계획 작성|계획 세워|구현 계획|implementation plan'
# 기대: 아래 3개는 전부 매치해야 한다
for s in "플랜 문서 작성하자" "계획 문서 작성해줘" "플랜 작성하자"; do
  printf '%s' "$s" | grep -qiE "$RE_OLD" && echo "MATCH: $s" || echo "MISS : $s"
done
# 기대: 아래 2개는 매치되면 안 된다(오탐 회귀)
for s in "작업계획대로 진행되면 생기는 엣지케이스 조사해줘" "이 플랜 실행 결과를 요약해줘"; do
  printf '%s' "$s" | grep -qiE "$RE_OLD" && echo "FALSE-POS: $s" || echo "ok       : $s"
done
```

- [ ] **Step 2: 실행해서 실패를 확인**

Run: `sh /tmp/t1.sh`
Expected: `MISS : 플랜 문서 작성하자` 와 `MISS : 계획 문서 작성해줘` 가 나온다(이게 재현하려는 결함).

- [ ] **Step 3: 정규식을 수정**

`woobin-harness/hooks/plan-session-boundary-guard.sh` 33행을 아래로 교체한다. `플랜 작성`·`계획 작성`을 `.{0,8}` 삽입 허용형으로 바꾸고 나머지 어구는 그대로 둔다.

```sh
echo "$prompt" | grep -qiE 'writing-plans|플랜.{0,8}작성|플랜 짜|플랜 가자|플랜으로 가|계획.{0,8}작성|계획 세워|구현 계획|implementation plan' || exit 0
```

같은 파일 14행 부근(`# 플랜 구현 킥오프 프롬프트는 sdd-kickoff-guard.sh 담당이라 여기서는 제외한다.` 아래)에 근거 한 줄을 덧붙인다.

```sh
# 2026-08-10: `플랜 작성`은 붙어 있어야만 매치돼 "플랜 문서 작성하자"가 새어나갔다(7일 전수, 진입 3건 중 1건).
# 어구 목록은 유지하되 `플랜`/`계획`과 `작성` 사이 8자까지 허용한다. 넓은 의미 탐지는 오탐 2/5라 채택하지 않았다.
```

- [ ] **Step 4: 테스트를 수정 후 정규식으로 다시 실행**

`/tmp/t1.sh`의 `RE_OLD` 값을 위 Step 3의 새 정규식으로 바꾼 뒤 실행한다.

Run: `sh /tmp/t1.sh`
Expected: `MATCH:` 3개, `ok       :` 2개. `MISS`·`FALSE-POS`가 하나도 없어야 한다.

- [ ] **Step 5: 멀티바이트 `.` 동작을 실제 로케일에서 확인**

`grep -E`의 `.`가 UTF-8 문자 단위로 매칭되는지 확인한다(바이트 단위면 8자 여유가 실제로는 2~3자다).

Run:
```sh
printf '%s' "플랜 아주아주긴문서 작성하자" | grep -qiE '플랜.{0,8}작성' && echo "char-mode" || echo "byte-mode(재검토 필요)"
```
Expected: `char-mode`. `byte-mode`가 나오면 `.{0,8}`을 `.{0,24}`로 올리고 Step 4를 다시 돌린다.

- [ ] **Step 6: 커밋**

```bash
git add woobin-harness/hooks/plan-session-boundary-guard.sh
git commit -m "fix(hooks): 플랜 진입 가드가 '플랜 문서 작성' 어구를 놓치던 정규식 수정"
```
