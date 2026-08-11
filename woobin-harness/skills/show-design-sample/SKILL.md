---
name: show-design-sample
description: 디자인 시안 샘플 페이지를 싸고 빠르게 만들어 GitHub Pages에 띄우고 URL을 준다. 앱 코드는 건드리지 않고 격리된 프리뷰 엔트리에서 실제 컴포넌트를 렌더한다. Use whenever the user wants 디자인 샘플·시안을 만들어 눈으로 보고 싶다고 할 때 — "시안 a/b/c 만들어서 보여줘", "프리뷰 페이지 위에 시안 샘플 만들어서 보여줘", "디자인 후보 N개 만들어서 띄워줘", "이 UI 여러 버전으로 만들어서 비교하게 해줘", "샘플 페이지 만들어줘", "show me design samples", "make a few UI variants I can look at". 고른 시안을 앱에 적용하거나 PR을 올리는 것은 이 스킬의 범위가 아니다 — URL 전달로 끝난다.
---

# show-design-sample

디자인 시안 N개를 **격리 프리뷰 엔트리**에서 만들어 **GitHub Pages**에 올리고 URL을 준다. 거기서 끝난다.

## 예산 — 초과하면 멈추고 보고한다

| 항목 | 상한 |
|---|---|
| 메인 루프 요청 | 25회 |
| 총 비용 | $3 |
| 벽시계 | 30분 |

초과가 보이면 그 자리에서 남은 단계와 함께 사용자에게 보고한다. 조용히 계속하지 않는다.

**비용은 전부 메인 컨텍스트 크기다.** 2026-08-11 실측(Pholex, 시안 3개): 총 $16.70 중 메인 루프 cache read가 $5.27(61%)이었고 컨텍스트가 46.4k→171k로 자랐다. 실제 산출물(빌더 3개)은 $3.09(18%)뿐이었다. 메인이 직접 읽고·고치고·브라우저를 몰면 그 값이 이후 **모든** 요청에 재청구된다. 아래 규율은 전부 "메인은 결정만, 손발은 위임"으로 수렴한다.

## 0. 전제 — 프리뷰 엔트리

시안은 **앱 코드를 건드리지 않고** `frontend/.preview/`(gitignore)의 별도 Vite 엔트리에서 렌더한다. 실제 컴포넌트를 상대경로로 import하므로 디자인 토큰·DOM 계층이 실물과 같고, 앱의 인증·권한·백엔드 경로는 타지 않는다.

**없으면 만든다. 짧게 확인만 받는다:**

> `frontend/.preview/`가 없습니다. 시안을 띄우려면 프리뷰 엔트리가 필요합니다. 만들까요? 앱 코드는 건드리지 않고 `.gitignore`에 들어갑니다.

"네"면 에이전트 1개에 위임한다. 요구사항:

- `frontend/.preview/index.html`, `main.tsx`, `vite.preview.config.ts`
- **`?variant=a|b|c` 쿼리 스위처 + 화면 위 전환 컨트롤.** 같은 상태에서 번갈아 봐야 차이가 느껴진다.
- 앱의 전역 스타일(`src/styles.css`, `src/fonts.css`)을 import — 시안이 겉돌면 비교가 무의미하다.
- 픽스처는 `.preview/fixtures.ts` 한 곳에. 실제 데이터의 **최장값**(가장 긴 이름·ID)을 포함해 폭 스트레스를 태운다.
- 앱의 tsconfig·빌드에 걸리지 않게 격리하고, `.gitignore`에 `frontend/.preview/`를 추가한다.
- 완료 판정: `npx vite build -c frontend/vite.preview.config.ts` 성공 + 산출물에 `index.html` 존재.

## 1. 스코프 — `Explore` 1회

`Explore` 에이전트 1개에 넘긴다. **메인에서 grep/Read로 훑지 않는다.**

- 손댈 컴포넌트의 **파일 경로**와 현재 구조
- 맞춰야 할 디자인 언어(간격·색 토큰·폰트·정렬)와 그 근거 파일 경로
- 픽스처에 쓸 실제 데이터 형태와 최장값

결과를 요약하지 말고 그대로 **`frontend/.preview/BRIEF.md`** 에 쓴다.

**이 파일이 있어야 빌더 N개가 각자 앱을 다시 훑지 않는다.** 실측에서 브리프 없이 띄운 빌더 3개가 36.5k → 82k·97k·121k로 자랐고 그 증가분이 전부 중복 탐색이었다.

## 2. 시안 차별점 — 왕복하지 않는다

N개 시안이 **구조·상호작용**으로 어떻게 다를지 먼저 제안하고, `AskUserQuestion` **1배치**로 확정한다. 순차 질문으로 왕복하지 마라 — 실측 1h42m 중 42분이 그 대기였다.

**색만 다른 N개는 실패다.** N 기본값은 3, 단일 개선이면 1.

## 3. 병렬 제작

시안마다 에이전트 1개를 **동시에** 띄운다(sonnet).

- 프롬프트에 `BRIEF.md` **경로**를 넘긴다. 메인이 배경을 요약해 전달하지 않는다.
- 파일명을 시안별로 분리한다: `.preview/variants/A.tsx` · `B.tsx` · `C.tsx`. 공용 파일(`main.tsx`·스위처·`fixtures.ts`)은 **오케스트레이터가 한 번만** 수정한다.
- **`frontend/src/`를 수정하면 그 자리에서 BLOCKED 보고.** 이 스킬은 앱을 건드리지 않는다.
- 리포트는 **파일 경로 + 한 줄 요약**만. diff를 메인으로 끌어오지 않는다.
- **worktree를 나누지 않는다.** 파일명이 분리돼 있어 충돌이 없다. 실측이 지지한 건 격리가 아니라 위임이다.

## 4. 빌드 + 배포

**스크린샷 검증을 하지 않는다.** 사용자가 실물을 직접 만지는 게 이 구조의 요점이다. 실측: 브라우저 검증 49건 중 렌더 불가 3건이 전부 백엔드·인증·권한 게이트 원인이었고, 프리뷰 엔트리는 그 경로를 타지 않는다.

대신 두 게이트로 대체한다(둘 다 추가 비용 0):

1. `npx vite build -c frontend/vite.preview.config.ts` 성공 + 산출물에 `index.html` 존재
2. push 후 `curl -sI <url>` → 200

**배포 레포는 프로젝트별로 하나를 상시 재사용한다. 시안마다 새로 만들지 마라.**

| 프로젝트 | 프리뷰 레포 | URL |
|---|---|---|
| Pholex | `woobin-the-creator/pholex-preview` | https://woobin-the-creator.github.io/pholex-preview/ |

목록에 없으면 `<project>-preview`로 만들고 **이 표에 한 줄 추가한다.** 이슈 번호를 레포 이름에 박지 마라 — 재사용하면서 이름과 내용이 어긋난다.

```bash
git clone --depth 1 <preview-repo> frontend/.preview/.deploy
rm -rf frontend/.preview/.deploy/*
cp -r <dist-preview>/* frontend/.preview/.deploy/
touch frontend/.preview/.deploy/.nojekyll
cd frontend/.preview/.deploy && git add -A && git commit -m "preview: <주제>" && git push
```

**클론은 반드시 워크트리 안(`frontend/.preview/.deploy/`)에 만든다.** `/tmp`에 클론하면 `git add`가 권한 분류기에 막힌다 — 2026-08-11 실측에서 배포가 정확히 여기서 멈췄다. 그래도 막히면 사용자에게 위 마지막 줄을 그대로 준다.

Pages 활성화는 레포당 최초 1회만:

```bash
gh api -X POST repos/<owner>/<repo>/pages -f 'source[branch]=main' -f 'source[path]=/'
```

첫 배포는 1~2분 걸린다. 이후 재사용 시 push 즉시 반영된다.

## 5. 공개 노출 규율

**Pages는 공개 사이트다.** private 레포여도 그렇다(Free는 private Pages 불가, Pro/Team도 사이트가 공개로 뜬다 — 접근 제한 Pages는 Enterprise 전용). 그래서 앱 레포가 아니라 별도 public 프리뷰 레포에 **빌드 산출물만** 올린다.

확인 범위가 좁다 — 올라가는 건 프리뷰 엔트리 산출물뿐이고 앱 `public/`의 영상·문서는 **애초에 대상이 아니다.** 볼 곳은 한 군데:

- `frontend/.preview/fixtures.ts`에 실제 사번·이름·부서명·lot id·내부 URL이 없는지. 사내 프로젝트면 건너뛰지 마라.

올라갈 파일 목록을 사용자에게 **먼저** 명시한다. 공개는 되돌리기 어렵다(캐시·인덱싱).

## 6. 전달하고 끝낸다

- 시안별 링크(`...?variant=a`)와 **각 시안의 특징·트레이드오프 2줄**.
- 마지막 줄에 핸드오프:
  > 시안은 `frontend/.preview/variants/{A,B,C}.tsx`에만 있습니다. 앱에는 아직 반영되지 않았습니다.
- **여기서 끝이다.** 앱 적용·PR·merge·데모 녹화는 이 스킬의 범위가 아니다.

## 체크리스트

- [ ] `frontend/.preview/` 확인 → 없으면 짧게 물어보고 에이전트로 생성
- [ ] `Explore` 1회 → `BRIEF.md` 저장 (메인에서 grep/Read 금지)
- [ ] 시안 차별점 제안 → `AskUserQuestion` 1배치로 확정
- [ ] 빌더 N개 동시 스폰, `BRIEF.md` 경로 전달, 파일명 분리
- [ ] 빌드 성공 + `index.html` 존재
- [ ] `fixtures.ts` 실데이터 검사 → 올라갈 파일 목록 사용자에게 명시
- [ ] `.deploy/`(워크트리 안) 클론 → push → `curl -sI` 200
- [ ] URL + 트레이드오프 2줄 + 핸드오프 한 줄 → 종료
- [ ] 예산(25요청 / $3 / 30분) 초과 시 멈추고 보고

## 함정

- **메인에서 시안 파일을 편집하는 것** — 실측된 최대 낭비. "이것만 빨리"가 바로 그 동작이다.
- **메인에서 grep/Read로 코드를 훑는 것** — `BRIEF.md`가 존재하는 이유다.
- **메인에서 브라우저를 직접 모는 것** — 이 스킬은 스크린샷 검증을 아예 하지 않는다.
- **`frontend/src/` 수정** — 범위 밖이다. 고른 시안 적용은 별도 작업.
- **시안끼리 차이가 없는 것** — 색만 다른 N개는 비교가 안 된다.
- **`/tmp`에 배포 클론** — `git add`가 막힌다.
- **`fixtures.ts`에 실데이터** — 공개 사이트다.
- **PR·merge·녹화로 넘어가는 것** — URL 전달로 끝이다.

## 기각한 대안

| 대안 | 기각 사유 |
|---|---|
| 정적 목업 HTML | 가장 싸지만 실제 DOM·CSS 계층에서만 나는 버그를 구조적으로 못 본다(실측: `will-change: transform`이 containing block을 만들어 `position: fixed` 툴팁이 240px 밀린 건). "기존 디자인에 어울리는가"를 판단할 수 없다. |
| 실제 앱 코드 수정 + 빌드 게이트 | 고른 시안이 곧 프로덕션 코드라는 장점이 있으나 worktree 격리·cherry-pick·게이트가 전부 따라붙는다. 실측 $16.70의 골격이 이것이었다. |
| worktree 시안별 격리 | 파일명 분리로 충돌이 0이라 값을 하지 않는다. 실측이 지지한 건 위임이다. |
| 세션 3분할(S1/S2/S3) | 근거였던 실측은 274요청짜리 PR 워크플로 기준이다. 한 세션 분량으로 줄어 `/clear` 3회가 "빠르게"를 해친다. 빌더 공통 입력만 `BRIEF.md`로 남겼다. |
| `screenshot-verifier` 최소 검증 | 막으려던 실패 모드 3건이 전부 백엔드·인증·권한 원인이고 프리뷰 엔트리는 그 경로를 안 탄다. 남은 실패는 빌드가 잡는다. |
| 프리뷰 엔트리를 앱 레포에 커밋 | 프로덕션 무관 디렉터리가 남아 시그니처 변경 때 썩는다. 재생성($0.3~0.5)이 싸다. |
| 후속 스킬 신설 | 카탈로그 자체가 매 요청 baseline 비용이다. 핸드오프 한 줄로 대체. |
| 로컬 dev / 정적+로컬 서빙 경로 | 더 싸지만 목표가 Pages로 고정됐다. 3지선다를 없애 분기 판단 비용을 뺀다. |
