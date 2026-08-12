# bench — 스킬 효과 블라인드 벤치마크

스킬을 고친 뒤 **실제로 산출물이 달라지는지**를 재는 자리. 같은 프롬프트를 스킬 없이 / 스킬 적용으로
각각 돌려 블라인드로 비교한다.

Pholex 워크트리 안에만 있던 기존 벤치마크는 untracked라 워크트리를 지우면 프롬프트·기준선이 같이
사라졌다. 그래서 여기로 옮겨 커밋한다.

## 왜 헤드리스로 도는가

**측정하는 세션이 스킬 본문을 컨텍스트에 갖고 있으면 "스킬 없이" 팔이 오염된다.**
그래서 두 팔 모두 `claude -p`로 독립 컨텍스트에서 돌린다. 메인 세션은 지시와 판정만 한다.

| 팔 | 격리 | 스킬 |
|---|---|---|
| `no-skill` | `--setting-sources project` | 없음 |
| `with-skill` | `--setting-sources project` | `--plugin-dir <레포>/woobin-harness` |

`--plugin-dir`가 핵심이다. 이걸 빼면 **설치본**(`~/.claude/plugins/cache/.../<version>/`)이 로드돼
방금 고친 내용이 아니라 옛 버전을 재게 된다.

## 도는 법

```bash
bash <케이스>/run-no-skill.sh      # 팔 1
bash <케이스>/run-with-skill.sh    # 팔 2
bash <케이스>/make-blind.sh        # X/Y 무작위 배정 + 크기 패딩
bash <케이스>/deploy.sh            # GitHub Pages 발행
bash <케이스>/wait-pages.sh        # 200 뜰 때까지 대기
```

정답은 `<케이스>/.mapping.json`. **판정 전에 열지 마라.**

## 유효성 점검 — 판정 전에 반드시

두 가지를 transcript에서 확인해야 결과가 의미를 갖는다. transcript 경로는
`~/.claude/projects/<작업디렉터리를 -로 치환>/<session_id>.jsonl`이고 `session_id`는 `run.json`에 있다.

1. **스킬이 실제로 호출됐나** — `Skill` tool_use의 `skill` 값
2. **개정본이 로드됐나** — 이번에 새로 쓴 문구를 transcript에서 grep. 0건이면 설치본이 로드된 것이라
   측정이 무효다

## 함정 (실측)

- **자리비움 핸드오프 훅이 헤드리스 팔 안에서도 발화한다.** 2026-08-12 `with-skill` 팔이
  `~/.claude/idle-handoffs/` 쓰기 거부로 지연돼 `run.json`이 한참 0바이트였다. 실패가 아니다.
- **블라인드는 파일 크기로 샌다.** 두 팔의 바이트 수가 다르면 그것만으로 식별된다.
  `make-blind.sh`가 주석으로 패딩해 크기를 맞춘다.
- **발행 클론(`.deploy/`)을 `/tmp`에 만들지 마라** — `git add`가 권한 분류기에 막힌다.
  워크트리 안에 만들고 `.gitignore`로 뺀다(`show-design-sample` §4).
- **디렉터리를 `eval/`로 짓지 마라** — 셸 가드가 `eval`이 든 명령을 거부해 스크립트 없이는 다루기 어렵다.

## 케이스

| 케이스 | 프롬프트 | 잰 것 |
|---|---|---|
| `2026-08-12-lot-dashboard` | 제조 랏 추적 대시보드(KPI 4 + 8행 7컬럼 테이블 + 필터 + 테마 토글) | 이슈 #5 라벨 가시성 · #6 테이블 컴팩트 |

프롬프트가 KPI와 다컬럼 테이블을 **실제 데이터 길이로** 요구하므로 두 규칙이 모두 관찰되는 화면이 나온다.
