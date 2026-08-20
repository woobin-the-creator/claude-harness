# show-design-sample Reference

이 문서는 런타임 계약 밖의 근거만 둔다. `SKILL.md`는 짧게 유지하고, 여기서 왜 그 계약을 택했는지 설명한다.

## 측정 메모

- 2026-08-11 Pholex 시안 3개 실측: 총 $16.70. 메인 루프는 92요청, 컨텍스트는 46.4k -> 171k.
- 메인 비용 구성: cache read $5.27(61%), cache write $1.83(21%), output $1.60(18%).
- 빌더 3개 비용은 $3.09(18%)였고, 나머지 대부분은 메인의 읽기/조정 오버헤드였다.
- 벽시계는 1h42m였고 그중 42분은 순차 질문 대기였다.
- 브라우저 검증 서브에이전트 49건 중 렌더 불가 3건은 전부 백엔드 500, 권한 게이트, `VITE_DEMO_MODE` 미적용 때문이었다. 컴포넌트 오작성 근거는 없었다.
- `/tmp` 배포 클론은 권한 분류기에 걸렸고, `.preview/.deploy` 캐시 재사용은 그 실패를 피했다.

## 측정 목표

- 목표는 `$3 / 25 requests / 30 minutes`이지만 아직 이 새 경로의 post-release 실측은 없다.
- 따라서 현재 문서는 목표를 기록만 하고 달성했다고 주장하지 않는다.

## 채택한 결정

- 후보 개수 질문보다 후보 집합 해석을 먼저 한다. 기존 대화 라벨이 이미 있으면 그 입력을 재사용하는 편이 더 싸고 빠르다.
- `N <= 3`은 Sonnet 5 빌더 1개가 가장 싸다. 탐색과 공용 맥락을 한 번만 읽고 variant 파일만 여러 개 쓰면 된다.
- `N >= 4` 또는 명시적 병렬 요청에서만 `BRIEF.md` + variant별 병렬 빌더를 쓴다. 이때만 중복 탐색 절감 이득이 분명하다.
- 배포 기본값은 GitHub Pages다. 로컬 서빙은 명시 요청 때만 쓴다.

## 기각한 대안

- variant별 스크린샷과 Playwright: Sonnet 5로 에러 없는 mock 생성이 가능했고, 브라우저/이미지 문맥은 속도와 비용 목표에 반했다.
- 메인 루프 단독 구현: cache-read 증폭과 컨텍스트 누적이 이미 관측됐다.
- `N <= 3`에서도 variant별 에이전트: 이미지 루프가 없는 조건에서는 탐색과 통합 중복만 늘어난다. 아직 repo 비교 실측도 없다.
- tracked `.gitignore`: `.git/info/exclude`가 같은 로컬 ignore 효과를 주면서 repo diff를 만들지 않는다.
- 스캐폴드나 후보 수를 매번 재확인: deterministic setup과 기존 대화 후보로 common path를 바로 해결할 수 있다.
- local-first 전달: 사용자가 기본 전달면으로 GitHub Pages를 선택했다.

## 참고 링크

- Vite GitHub Pages base 안내: https://vite.dev/guide/static-deploy.html#github-pages
- Anthropic Claude Sonnet 5 발표: https://www.anthropic.com/news/claude-sonnet-5
- WebDev Arena leaderboard: https://web.lmarena.ai/leaderboard
