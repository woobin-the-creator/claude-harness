---
name: show-design-sample
description: 디자인 시안 샘플 페이지를 빠르게 만들어 GitHub Pages 기본 경로로 띄우고 URL을 준다. 앱 소스는 건드리지 않고 `.preview/` 격리 엔트리와 로컬 스크립트만 사용한다. 후보 비교나 복수 시안을 요청받았을 때 이 스킬을 사용한다.
---

# show-design-sample

앱 `src/`는 바꾸지 않는다. 프리뷰 인프라는 `<app-dir>/.preview/` 아래에만 두고, 로컬 제외는 tracked `.gitignore`가 아니라 `.git/info/exclude`로 처리한다. Playwright, 브라우저 도구, 스크린샷, 이미지 생성은 사용하지 않는다. 기본 전달 경로는 GitHub Pages이고, 로컬은 사용자가 명시했을 때만 쓴다.

## 1. 후보 집합 우선

가장 최근에 **assistant가 제시한 후보 라벨과 설명**이 정본이다. 다시 제안하거나 재확인하지 않는다. 고신뢰 매핑이면 짧게 알리고 바로 진행한다. 막는 경우는 `부분 집합`이 모호하거나 새 방향이 더 필요한 경우뿐이다.

| 대화 상태 | 사용자 표현 | 처리 |
|---|---|---|
| 최신 후보 집합 `{A,B,C}` | bare `3개`, `3개 다`, `다`, `전부` | `A+B+C` 즉시 생성 |
| 최신 후보 집합 `{A,B,C}` | `A와 C` | `A+C` 즉시 생성 |
| 최신 후보 집합 `{A,B,C}` | bare `2개` | `부분 집합`을 **한 번**만 묻는다: `A+B`, `A+C`, `B+C`. 가장 구조 대비가 큰 쌍을 추천 |
| 최신 후보 집합 `{A,B,C}` | bare `4개` | 네 번째 방향을 한 번만 묻는다 |
| 후보 집합 없음 | 단수 샘플 요청 | 추론한 후보 1개 생성 |
| 후보 집합 없음 | 복수/비교 요청 | 구조적으로 다른 후보 3개 생성 |

## 2. 빌더 토폴로지

`N <= 3`이면 `scripts/init-preview.sh`로 프리뷰를 준비한 뒤 **Sonnet 5 에이전트 1개**만 쓴다. 프롬프트에는 선택된 라벨/설명, `APP_DIR`, 아래 제약을 넣는다.

- 대상 컴포넌트와 디자인 토큰 소스를 한 번만 읽는다.
- 프로젝트의 실제 전역 스타일/폰트 엔트리만 import하고 내용을 복사하지 않는다.
- `.preview/variants/<label>.tsx`와 synthetic `.preview/fixtures.ts`만 쓴다.
- `.preview/main.tsx`, Vite 인프라, `src/`는 수정하지 않는다.
- Playwright, 브라우저, 스크린샷, 이미지 생성은 호출하지 않는다.
- 결과는 경로와 variant별 한 줄만 반환하고 diff는 반환하지 않는다.

`N >= 4`이거나 사용자가 병렬을 명시하면 read-only 탐색 1회로 최대 20줄 `<app-dir>/.preview/BRIEF.md`를 만든 뒤 라벨별 Sonnet 빌더를 병렬 실행한다. variant별 에이전트는 이 분기에서만 허용한다.

## 3. 실행 순서

1. 후보 라벨을 결정한다.
2. `scripts/init-preview.sh <repo-root> [app-dir]`를 실행한다. `APP_DIR_REQUIRED`일 때만 app dir을 한 번 묻는다.
3. 선택된 빌더 토폴로지를 실행한다.
4. `scripts/build-preview.sh <app-dir>`를 실행한다.
5. `fixtures.ts`가 synthetic인지 확인하고, `.preview/.dist` 파일 목록을 출력한다.
6. 기본 경로: `scripts/deploy-preview.sh <app-dir> [owner/repo]`. exit `3`과 `NEW_PUBLIC_REPO_REQUIRED=<owner/repo>`이면 public repo 생성 여부를 묻고 `--create-public`으로 한 번만 재실행한다.
7. 사용자가 로컬을 **명시**했을 때만 `scripts/serve-preview.sh <app-dir>`를 대신 실행한다.
8. variant URL과 variant별 한 줄 tradeoff를 돌려주고, 애플리케이션 소스는 바뀌지 않았다고 명시한다.

**배포 레포는 프로젝트별로 하나를 상시 재사용한다. 시안마다 새로 만들지 마라.**

| 프로젝트 | 프리뷰 레포 | URL |
|---|---|---|
| Pholex | `woobin-the-creator/pholex-preview` | https://woobin-the-creator.github.io/pholex-preview/ |
| claude-harness | `woobin-the-creator/claude-harness-preview` | https://woobin-the-creator.github.io/claude-harness-preview/ |

목록에 없으면 `<project>-preview`로 만들고 **이 표에 한 줄 추가한다.** 이슈 번호를 레포 이름에 박지 마라 — 재사용하면서 이름과 내용이 어긋난다.

## 4. 출력 규약

- GitHub Pages 기본: `PREVIEW_URL`, `PREVIEW_VERSION`, 그리고 `?variant=<label>` 링크를 준다.
- 로컬 명시 요청: `vite preview --host 127.0.0.1` URL만 준다.
- 핸드오프는 `.preview/variants/*.tsx`와 synthetic fixtures 위치만 적는다.

세부 근거, 실측, 기각한 대안, 참고 링크는 `REFERENCE.md`에 둔다.
