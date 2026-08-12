# Design Workflow 설계 명세

**상태:** 합의 완료

**작성일:** 2026-08-12

**대상 이슈:** #7, #8
**작업명:** `design-workflow`(첫 구현의 작업명이며 값싼 이름 변경은 허용)

## 1. 문제와 목표

현재 세 체계는 서로 다른 강점을 갖지만 한 작업에서 자연스럽게 이어지지 않는다.

- `interface-design`은 그린필드 방향 탐색, 제품 고유 signature, 시각적 craft review에 강하다.
- `design-rules`는 프로젝트별 값, 실데이터 치수, 실패 선례, 접근성 실측과 규칙 진화에 강하다.
- `carbon-design-system/ibm-products`는 규칙을 컴포넌트 계약·토큰 린트·Story·접근성 및 시각 회귀 CI에 분산해 실행하는 데 강하다.

목표는 세 문서를 합치는 것이 아니다. 사용자는 하나의 디자인 동료를 호출하되, 내부 Router가 작업을 분류하고 필요한 전문 모듈만 읽는 디자인 운영 루프를 만든다.

```text
작업 분류
  → 필요한 경우 방향 탐색
  → 프로젝트 시스템·근거 확인
  → 구현 가능한 결정을 컴포넌트/테스트/린트 계약으로 변환
  → 실제 렌더·데이터·접근성으로 리뷰
  → 실패와 예외를 축적하고 검증된 규칙을 승격
```

## 2. 사용자 경험

사용자는 내부 모듈명을 선택하지 않는다. 평소처럼 하나의 스킬을 호출한다.

```text
$design-workflow 주문 관리 화면에 일괄 상태 변경을 추가해줘.
$design-workflow 신규 제조 모니터링 웹앱의 방향을 잡고 첫 화면을 만들어줘.
$design-workflow 이 PR의 UI를 리뷰해줘. 수정은 하지 마.
$design-workflow 같은 테이블 줄바꿈 문제가 반복된다. 다시 생기지 않게 막아줘.
```

Router는 작업 시작 시 한 줄로 분류 결과를 알린다.

```text
작업 유형: 기존 시스템의 증분 변경 · 사용 모듈: system-evidence → implementation-contracts → review
```

### 2.1 기존 프로젝트 첫 사용

현재 작업과 관련된 코드·토큰·공용 컴포넌트·인접 화면만 조사한다. 다수 패턴은 `observed`일 뿐 프로젝트 정책으로 자동 확정하지 않는다. `DESIGN.md`가 없어도 구현·리뷰·가드 생성은 정상 진행한다. 지속할 가치가 있는 방향·예외·선례가 생겼을 때만 파일 생성을 제안한다.

### 2.2 그린필드 첫 사용

Direction 모듈이 사용자·핵심 과업·도메인 어휘·색 세계·피해야 할 기본값·signature·focal point를 좁힌다. 사용자가 방향을 고른 뒤 foundation과 primitive를 만들고 대표 화면에서 검증한다. `DESIGN.md`는 선택한 방향을 다음 세션에 보존하는 선택적 산출물이다.

### 2.3 공식 디자인 시스템이 있는 기존 프로젝트

공식 문서와 실제 공용 컴포넌트·semantic token이 일반 스킬 기본값보다 우선한다. 새 signature나 토큰을 발명하지 않는다. 잘못 쓰기 쉬운 상호작용은 프로젝트 스택에 맞는 wrapper, hook, validator 또는 test로 내린다.

### 2.4 문법이 혼재한 레거시 프로젝트

기존 패턴을 방언별로 나누고 `legacy`, `observed`, `adopted`를 구별한다. 현재 범위를 바꾸는 경우에만 사용자에게 국소 적용·인접 마이그레이션·전체 마이그레이션 중 선택을 묻는다.

### 2.5 작은 증분 변경

Direction을 생략하고 관련 결정과 컴포넌트 계약만 읽는다. 전체 프로젝트 감사, signature 재탐색, 전 viewport 전수 검증을 하지 않는다. 작은 일은 작은 경로로 끝난다.

### 2.6 대규모 리디자인

기존 브랜드·컴포넌트·학습된 상호작용을 제약으로 삼아 Direction을 다시 연다. 새 방향은 즉시 기존 정본을 덮지 않고 `candidate`로 병행 검증한 뒤 승인되어야 `adopted`가 된다.

### 2.7 리뷰 전용

diff 범위와 현재 정본만 읽고 findings를 `blocker`, `should-fix`, `note`로 보고한다. 취향을 결함으로 보고하지 않고, 사용자가 수정도 요청하지 않았다면 파일을 쓰지 않는다.

### 2.8 반복 실패의 가드 승격

반복 횟수는 일반화 검토 신호이지 자동 CI 승격 조건이 아니다. 공통 원인을 확인한 뒤 가장 낮은 유효 계층을 고른다.

```text
산문 → 공용 API/컴포넌트 정규화 → 정적 검사 → unit/a11y/browser test → CI failure gate
```

현재 범위의 컴포넌트·테스트 가드는 “다시 발생하지 않게 막아줘”라는 요청에 포함된다. 새 의존성, 공개 API 변경, 대규모 마이그레이션, CI failure gate 활성화는 별도 승인이 필요하다.

### 2.9 외부 선례 도입

외부 구현은 `external-precedent`의 `candidate`로 시작한다. vendor API를 제거한 일반 계약을 추출하고 로컬 문제·대표 사례에서 검증한 뒤에만 `adopted`로 승격한다. 외부 사례를 `local-incident`로 기록하지 않는다.

### 2.10 렌더 도구가 없는 환경

정적 검사, 타입, unit test, fixture 검증은 계속한다. clipping, 테마 대비, focus ring처럼 렌더가 필요한 항목은 `unverified`로 명시한다. 도구 부재를 성공으로 보고하지 않는다.

## 3. 아키텍처

### 3.1 Router

항상 읽는 짧은 `SKILL.md`다. 다음 축만 판정하고 각 모듈의 세부 규칙을 중복 소유하지 않는다.

- 프로젝트 상태: `greenfield | established | mixed | legacy`
- 작업 모드: `direction | implementation | review | enforcement`
- 변경 크기: `incremental | redesign`
- 정본 상태: managed `DESIGN.md` / unmanaged `DESIGN.md` / 없음
- 실행 환경: 코드 검사, 브라우저, 스크린샷, 테스트, CI 가능 여부

### 3.2 Direction

그린필드와 대규모 리디자인에만 사용한다. 제품 고유 방향, 후보 비교, focal point, signature, 금지 기본값을 소유한다. 기존 시스템의 작은 변경에서는 읽지 않는다.

### 3.3 System & Evidence

프로젝트의 실제 컴포넌트·토큰·인접 화면을 authority로 읽고 실데이터 치수, 정보 구조, 접근성 측정, 로컬 실패와 외부 선례를 구별한다. 현 `design-rules`의 프로젝트별 값/근거 모델을 계승한다.

### 3.4 Implementation Contracts

IBM Products에서 일반화한 아래 계약을 프로젝트 스택에 맞게 구현한다.

- `input → validate → normalize → render | refuse`
- `available space → measure → affordance reserve → prefix fit`
- `overlay open → initial focus → close → launcher focus restore`
- `async state → label + icon + disabled/action state`

Carbon class, React PropTypes, Storybook, Chromatic은 보편 규칙으로 가져오지 않는다.

### 3.5 Review

실제 렌더가 가능하면 desktop/mobile, 긴 값/짧은 값, light/dark, loading/empty/error, focus/keyboard/reduced-motion을 확인한다. Squint/Swap/Signature/Token test와 blocker/should-fix/note를 사용한다. 리뷰 전용 요청에서는 수정하지 않는다.

### 3.6 Evolution

결정의 provenance, 상태, waiver와 enforcement를 관리한다. 상태는 아래 closed enum을 사용한다.

```text
observed → candidate → adopted → component-enforced → ci-enforced → retired
```

`observed`는 기존 코드에서 발견했으나 사람이 확정하지 않은 관행이다. `candidate`는 검증 중인 제안이다. `adopted`부터 프로젝트 기본값이다. 뒤의 두 상태는 실제 경로가 존재할 때만 사용한다.

## 4. 선택적 구조화 `DESIGN.md`

`DESIGN.md`는 기능 플래그나 설치 조건이 아니다. 없어도 모든 기능이 동작한다. 파일이 없으면 코드·토큰·인접 화면을 현재 작업의 임시 정본으로 사용하고, 보존 가치가 생긴 시점에만 생성을 제안한다.

이미 다른 목적으로 쓰는 `DESIGN.md`가 있고 `design_workflow` 표식이 없으면 이를 덮거나 오류로 처리하지 않는다. validator는 `DESIGN_UNMANAGED`와 exit 0을 반환한다.

### 4.1 사람이 읽는 영역

- 제품 방향과 톤
- 피해야 할 기본값
- color/type/spacing/radius/depth/motion의 의도와 코드 authority
- interaction contract 설명
- legacy와 migration 범위
- 검증되지 않은 항목

실제 token 값과 component prop 목록은 복제하지 않고 코드 경로를 가리킨다.

### 4.2 기계가 읽는 영역

YAML frontmatter는 활성화와 schema version만 소유한다.

```yaml
---
design_workflow:
  enabled: true
  schema_version: 1
---
```

복잡한 lifecycle 데이터는 의존성 없는 확정적 파싱을 위해 marker 사이의 JSON으로 둔다.

````markdown
<!-- design-workflow:data:start -->
```json
{
  "schemaVersion": 1,
  "project": { "state": "established", "directionStatus": "adopted" },
  "authorities": [
    { "kind": "color-tokens", "path": "src/styles/tokens.css" },
    { "kind": "components", "path": "src/components" }
  ],
  "decisions": []
}
```
<!-- design-workflow:data:end -->
````

### 4.3 결정 레코드

```json
{
  "id": "table-cell-wrapping",
  "status": "component-enforced",
  "source": {
    "type": "local-incident",
    "references": ["eval/2026-08-11-complex-filter-modal"]
  },
  "rule": "테이블 셀은 기본적으로 한 줄로 표시한다.",
  "localEvidence": ["incident-table-density-001"],
  "enforcement": [
    { "type": "component", "path": "src/components/TableCell.tsx" }
  ],
  "waivers": []
}
```

불변조건:

- `id`는 kebab-case이며 파일 안에서 유일하다.
- `local-incident`는 하나 이상의 source reference와 local evidence를 가진다.
- `external-precedent`는 로컬 검증 없이 `adopted` 이상이 될 수 없다.
- `component-enforced`와 `ci-enforced`는 존재하는 enforcement path를 가진다.
- temporary waiver는 `reason`, `owner`, ISO 날짜 `expires`를 모두 가진다.
- 경로 검사는 프로젝트 루트 밖으로 탈출하지 않는다.

validator 인터페이스:

```text
node scripts/validate-design-md.mjs [<repo-root-or-DESIGN.md>]
```

- 파일 없음: exit 0, `DESIGN_ABSENT path=<path>`
- unmanaged 파일: exit 0, `DESIGN_UNMANAGED path=<path>`
- valid managed 파일: exit 0, `DESIGN_OK schema=1 decisions=<n>`
- invalid managed 파일: exit 1, 줄마다 안정적인 `DESIGN_E_*` 오류 코드

## 5. 권위 순서

1. 사용자가 이번 작업에서 명시적으로 확정한 결정
2. 프로젝트의 공식 디자인 문서와 managed `DESIGN.md`의 adopted 이상 결정
3. 실제 공용 컴포넌트와 semantic token
4. 인접 화면의 일관된 관행(`observed`, 아직 정책 아님)
5. 스킬의 근거 기반 일반 규율
6. 스킬의 취향 기본값

보안·접근성의 비협상 요구사항은 취향 override보다 우선한다.

## 6. 권한 모델

자동으로 가능한 일:

- 기존 코드와 토큰을 `observed`로 보고
- 실행한 테스트와 incident evidence 추가
- 사용자가 요청한 범위의 component/test 가드 구현
- 실제 구현·검증 경로가 생긴 결정을 `component-enforced`로 표시

승인이 필요한 일:

- `candidate → adopted`로 프로젝트 기본값 확정
- 공개 컴포넌트 API 변경
- 새 의존성 설치
- 기존 화면의 대규모 마이그레이션
- CI failure gate 활성화
- 기존 waiver, exception, legacy 동작 제거

## 7. 기존 스킬과의 경계

- `design-workflow`가 프로세스, 작업 분류, 산출물, lifecycle을 소유한다.
- `design-rules`는 기존 직접 호출을 보존하는 compatibility entry가 되고, concrete UI 판단에 필요한 새 모듈만 읽도록 얇아진다.
- `show-design-sample`은 복수 후보를 격리 렌더·공유할 때만 호출한다. 단일 구현이나 review-only에는 호출하지 않는다.
- 자동 트리거 경쟁을 막기 위해 `design-rules` description에서 방향 탐색·후보 선택 트리거를 제거한다.

현재 HEAD에 없는 `17994e0`의 #5/#6 개선(라벨 가시성, table nowrap/ellipsis, 선례 3칸·3줄 상한)은 cherry-pick으로 옛 파일을 되살리지 않고 새 모듈의 해당 섹션에 이식한다. `a61a9ab`의 벤치는 측정 방법만 새 eval에 계승한다.

## 8. #8 소스 재검증으로 교정된 사항

- IBM `ActionSet`은 잘못된 조합을 콘솔에 보고하고 순서를 정규화하지만 렌더를 거부하지 않는다. validation, normalization, render refusal은 별개 단계로 기록한다.
- `.avt/baseline` 경로 설정은 있으나 `.avt/`가 gitignore되어 pin의 추적 트리에 baseline이 없다. “버전 관리된 기존 위반 동결”로 서술하지 않는다.
- legacy `TagSet`과 `useOverflowItems` 기반 `TagOverflow`는 동일 구현이 아니다. 일반화 대상은 measurement contract다.
- IBM Products에도 root typecheck 부재, rule denylist와 `test.skip`의 owner/reason/expiry 부재가 있다. vendor 구현을 이상형으로 취급하지 않는다.

## 9. 출처와 라이선스

- `Dammyjay93/interface-design`, commit `2f9be3206855bcb2d1d0af262c8bae25cba6658d`, MIT.
- `carbon-design-system/ibm-products`, commit `eeff1e98ac8332f60a90d015dea2ba7c38edd26d`, Apache-2.0.
- 현 저장소 `design-rules`와 local issues #5–#8.

첫 버전은 외부 소스를 복사하지 않고 분석된 메커니즘을 새 문장과 추상 계약으로 재작성한다. 외부 경로·commit·license는 `references/sources.md`에 남긴다. 이후 substantial code/text를 가져오면 해당 license notice를 함께 배포한다.

## 10. 범위 밖

- React/Vue/Svelte를 직접 파싱하는 범용 디자인 CLI
- 전용 visual regression SaaS 또는 baseline 저장소
- Carbon 컴포넌트·토큰의 runtime dependency
- 모든 주관적 craft 판단의 자동화
- `DESIGN.md` 강제 생성
- 기존 프로젝트 전체의 자동 정규화
- CI failure gate의 무승인 활성화

## 11. 거절한 대안

### 하나의 대형 스킬

그린필드 탐색·증분 변경·리뷰·가드 생성이 매번 같은 컨텍스트에 들어가 작은 작업의 비용과 트리거 충돌이 커지므로 거절했다.

### 처음부터 schema/CLI 중심 플랫폼

강제력은 높지만 프레임워크 adapter와 장기 호환성 관리가 먼저 필요해 검증되지 않은 규율보다 인프라를 먼저 만드는 꼴이 되므로 거절했다.

### 자유 형식 `DESIGN.md`

사람은 읽기 쉽지만 lifecycle, evidence, enforcement path를 확정적으로 검증할 수 없어 거절했다.

### `DESIGN.md`와 별도 machine registry

두 정본의 drift를 막는 동기화 시스템이 추가로 필요하므로 거절했다.

### `DESIGN.md` 필수화

기존 프로젝트 첫 사용과 작은 수정이 설정 파일 생성 때문에 막히며, 이미 다른 목적의 `DESIGN.md`를 침범할 수 있어 거절했다.

### 모든 UI 작업에서 설치 직후 자동 호출

프로젝트가 채택하지 않은 스킬이 예상치 못한 분석 비용을 만들 수 있어 거절했다. managed `DESIGN.md`가 있으면 암묵 호출하고, 없으면 명시 호출이 기본이다.

### 항상 명시 호출

채택한 프로젝트에서도 평범한 UI 변경이 정본과 어긋나기 쉬워 거절했다.

### 자연어 워크플로만 제공

기존 `design-rules`의 “기계 가드로 승격” 정책을 실제로 실행·검증할 공통 기반이 계속 비게 되므로 거절했다.

### 첫 버전부터 전용 범용 CLI

별도 제품 규모의 adapter·waiver·release 관리가 필요하므로 거절했다. 여러 프로젝트에서 반복 검증된 가드만 이후 승격한다.

### 모든 상태 승격에 승인 요구

evidence 추가와 이미 요청된 범위의 가드 구현까지 작업을 자주 멈추므로 거절했다.

### 반복 횟수만으로 자동 CI 승격

서로 다른 원인을 한 규칙으로 일반화하고 팀 정책을 예고 없이 바꿀 수 있어 거절했다.

## 12. 완료 조건

- 사용자가 하나의 스킬을 호출하고 내부 모듈을 고르지 않아도 열 가지 주요 시나리오가 올바르게 라우팅된다.
- `DESIGN.md`가 없음·unmanaged·valid managed인 세 경우 모두 작업을 막지 않는다. invalid managed 파일만 명확한 오류가 된다.
- 외부 선례, 로컬 관찰, 로컬 사고, 사용자 결정이 구별된다.
- review-only는 파일을 수정하지 않고, enforcement 요청은 권한 경계를 넘지 않는다.
- `design-rules` 직접 호출은 계속 동작하되 새 Router와 자동 트리거가 경쟁하지 않는다.
- 공통 validator는 Node 표준 라이브러리만 사용하고 fixture test를 통과한다.
- 적어도 기존 첫 사용, 그린필드, 증분 변경, review-only, guard 승격, managed/unmanaged/absent DESIGN의 routing contract가 테스트된다.
- 플러그인 문서·개수·version이 동기화되고 plugin validation과 설치 dry-run이 통과한다.
