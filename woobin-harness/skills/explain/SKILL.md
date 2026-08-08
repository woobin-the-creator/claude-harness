---
name: explain
description: 대화에서 논의한 개념·구조·결정·트레이드오프를 데이터 플로우 인포그래픽(HTML+inline SVG)으로 시각화하고, Playwright로 PNG 렌더 후 브랜치 커밋 SHA 기반 raw URL로 GitHub issue에 임베드한다. Use when 사용자가 /explain을 호출하거나, 방금 논의한 내용을 "그림/인포그래픽/시각화해서 gh issue에 올려달라"고 할 때.
---

# explain

방금 대화에서 다룬 개념·결정을 **데이터 플로우 인포그래픽**으로 그려 gh issue에 임베드한다.

## 핵심 디자인 규칙 (사용자 취향 — 어기지 말 것)

1. **텍스트를 박스에 담기만 하지 말 것.** 반드시 노드를 화살표로 연결한 **흐름(파이프라인)**으로 그린다. "보기 좋은 텍스트 박스 나열"은 실패다.
2. **비교/선택이면 후보를 나란히.** 공통 소스에서 **분기 → (각 경로) → 합류** 구조로 두고, *차이 나는 구간만* 배지로 강조한다(예: "무변경 ✓" vs "수정 ⚠️"). 한 후보만 그리면 비교가 안 된다.
3. **색 규약**: 추천/현재 흐름 = 파랑 실선, 대안/미구현 = 회색 점선, 주의/미연결 = 주황 점선 + ✕, 데이터 저장소 = 초록 탱크(🛢), 화면/결과 = 옅은 파랑.
4. 하단에 **범례 + 추천 strip**(결론 한 줄). 우측/하단에 "무엇이 다른가" 요약을 곁들이면 좋다.
5. 언어는 **한국어**, 결론(추천)을 명시. 이모지로 노드 성격 표시(🏭 외부, 🔌 포트, ⚙️ usecase, 🖥️ 화면 등).
6. inline `<svg viewBox>`, arrowhead는 `<marker markerUnits="userSpaceOnUse">`, 텍스트는 `dominant-baseline:middle`. 한글 폰트 `-apple-system,"Apple SD Gothic Neo","Noto Sans KR"`.

좋은 예시 출력물: `history/lotsource-vs-repository.html` (이 skill이 처음 만들어진 레포에 있으면 참고).

## 워크플로

1. **시각화 대상 확정** — 직전 대화에서 핵심 흐름/결정을 추린다. 노드(단계)와 화살표(데이터 이동), 분기/합류, 미구현 경로를 식별.
2. **HTML 작성** — `history/<slug>.html`. 위 디자인 규칙대로 inline SVG. `width`/`viewBox` 고정.
3. **PNG 렌더** — `node ~/.claude/skills/explain/scripts/render.cjs <html> <png> <width> <height>` (시스템 Chrome 채널, deviceScaleFactor 2).
4. **눈으로 확인** — 렌더된 PNG를 Read로 열어 한글 깨짐·겹침·잘림 점검. 문제 있으면 좌표 고쳐 재렌더.
5. **자산 커밋** — `docs/<slug>-viz` 브랜치 생성 → html·png 커밋(co-author trailer) → push. main은 건드리지 않는다.
6. **raw URL 구성** — `git rev-parse HEAD`로 SHA. `https://raw.githubusercontent.com/<owner>/<repo>/<SHA>/history/<slug>.png` (SHA 고정 = 브랜치 지워도 영구).
7. **public 확인** — `gh repo view --json visibility`. **private면 raw URL이 issue에서 안 보인다** → 사용자에게 알리고 멈춘다.
8. **issue 생성** — `gh issue create --title ... --body-file`. 본문 = 이미지 임베드 + 핵심 결론/비교표 + HTML 원본 링크.
9. **정리·보고** — 임시 body 파일 삭제, issue URL과 raw URL HTTP 200을 보고. 브랜치를 main에 머지(PR)할지 물어본다.

## 배포 명령 모음

```bash
# 5~6
git checkout -b docs/<slug>-viz
git add history/<slug>.html history/<slug>.png
git commit -q -m "docs(history): <제목> 시각화

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
git push -q -u origin docs/<slug>-viz
SHA=$(git rev-parse HEAD)
# 7~8
gh repo view --json visibility,nameWithOwner
gh issue create --title "<제목>" --body-file <(...)   # 또는 임시 .md 파일
```

이미지 마크다운: `![<alt>](https://raw.githubusercontent.com/<owner>/<repo>/<SHA>/history/<slug>.png)`

## 주의

- 임베드 이미지는 **반드시 커밋 SHA URL** (브랜치명 URL은 브랜치 삭제 시 깨짐). 본문 내 HTML 소스 링크는 브랜치 경로라도 무방하되, main 머지를 권한다.
- 렌더는 `channel: 'chrome'`으로 시스템 Chrome을 쓴다(브라우저 다운로드 불필요). 없으면 `npx playwright install chromium`.
- gh issue는 raw HTML/CSS를 sanitize하므로 HTML을 본문에 직접 넣지 않는다 — 항상 이미지로 임베드한다.
