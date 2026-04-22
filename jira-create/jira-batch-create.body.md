# Jira 이슈 일괄 생성

작업 계획 문서(Spec Kit 등)를 파싱하여 Epic / PBI(Story·Task) / Sub-task를 일괄 생성한다.

**설계 전제**:
- 입력 문서는 `/jira-batch-create-setup`으로 등록한 템플릿 규칙에 부합해야 한다.
- 문서에서 추출 가능한 필드(요약·계층·파일 경로·목적)는 그대로 쓰고, 추출 불가한 필드(AC·우선순위·SP·증거·추정치)는 자동 추정·기본값으로 메운다.
- 사용자 개입은 **Step 4 최종 미리보기 1회**만. 문서가 권위 있는 단일 소스라는 원칙을 지킨다.
- 수정이 필요한 경우 미리보기에서 이슈 단위로만 재조정한다.


## Step 1 — 작업 계획 문서 입력 및 파싱

### 1-1. 입력 수집

- `$ARGUMENTS`에 파일 경로(`.md` 확장자 또는 `/`로 시작)가 있으면 Read 도구로 로드
- 둘 다 없으면: "작업 계획 문서 파일 경로를 입력하세요." 1회만 질문

> `$ARGUMENTS`는 Step 0-2에서 이미 PROJECT_KEY 감지로 소비됐을 수 있다. 나머지 토큰 중 `.md` 확장자 / `/`로 시작하는 경로만 문서 입력으로 해석한다.

### 1-2. 템플릿 매칭

`{{CONFIG_DIR}}/jira-sdd-templates.yml`을 Read 도구로 로드한다.

- **파일 없음 또는 비어있음**: "SDD 템플릿이 등록되어 있지 않습니다. `/jira-batch-create-setup`을 먼저 실행하세요." 출력 후 중단.
- **파일 있음**: 문서 첫 H1 헤딩을 추출하고, 등록된 템플릿의 `match` 패턴과 순차 비교.
  - 일치 템플릿 있음: "템플릿 `{이름}`과 매칭되었습니다." 안내 후 해당 파싱 규칙 사용.
  - 일치 없음: "등록된 SDD 템플릿과 일치하지 않습니다. `/jira-batch-create-setup`으로 템플릿을 등록하세요." 출력 후 중단.

### 1-3. 파싱

매칭된 템플릿 규칙을 적용하여 문서를 파싱한다:

- `headings` 규칙으로 Epic / Story / Phase 분류
- `tasks` 규칙으로 Task / Sub-task 분류 및 parent 연결
  - Sub-task 판별: 템플릿의 `tags` 배열과 순차 매칭
    - `[USn]` 태그: 해당 번호의 User Story를 parent로 연결
    - `[Tnnn]` 태그: 해당 ID의 Task를 parent로 연결 (예: `[T002]` → T002 Task가 parent)
  - 두 패턴 모두 해당하지 않는 체크리스트 항목: Task(PBI), Epic이 parent
- `metadata` 규칙으로 목적·목표·AC 힌트·파일 경로 추출
- Phase 그룹(`issue: false`)은 이슈로 생성하지 않지만, 하위 Task의 컨텍스트로 보관
- `[P]` 플래그는 정보용, `(Priority: P1)` 등은 우선순위 힌트로 저장
- `(estimate: 2d)` 같은 추정치 힌트가 있으면 추출 (없으면 빈 값)

파싱 결과는 이슈 트리(번호·타입·요약·parent·file_path·목적 텍스트·우선순위 힌트·추정치 힌트) 구조로 메모리에 보관한다. **여기서 사용자에게 묻지 않는다.** 파싱 자체가 실패하면 명확한 에러 메시지와 함께 중단.


## Step 2 — 필드 자동 보강 (무대화)

문서에서 추출 불가한 필드를 config 기본값·모델 추정으로 **질문 없이** 채운다.

### 2-0. 이슈 타입 맵 확보

Jira 인스턴스 언어가 한국어이면 `Epic`이 아닌 `에픽`만 수용하는 식으로 이슈 타입 이름이 로컬라이즈된다. Phase A/B/C가 공통으로 쓸 **`ISSUE_TYPE_MAP`**을 배치당 1회 구축한다.

**알고리즘**:

1. `jira_search(jql="project = {PROJECT_KEY}", fields="issuetype", limit=50)` 실행.
2. 응답의 `issues[].fields.issuetype.name`을 고유 집합으로 수집.
3. 표준 키(영문) → 실제 인스턴스 이름으로 매핑:

   ```
   ISSUE_TYPE_MAP = {
     "Epic":     <수집 집합 중 "에픽" | "Epic" 일치>,
     "Story":    <"스토리" | "Story">,
     "Task":     <"작업" | "Task">,
     "Sub-task": <"하위 작업" | "Sub-task" | "Subtask">,
     "Spike":    <"스파이크" | "Spike">  # 없으면 null
   }
   ```

4. 필수 타입(Epic / Story / Task / Sub-task) 중 매핑 실패가 있으면:
   > "프로젝트 {PROJECT_KEY}에서 {표준 키} 이슈 타입을 찾을 수 없습니다. 프로젝트의 이슈 타입 설정을 확인하세요."
   출력 후 중단.

5. Spike는 옵셔널 — 없으면 `null`로 두고, SDD에 Spike가 있을 때만 중단한다.

**재사용**: Phase A/B/C의 `issue_type` 필드는 항상 `ISSUE_TYPE_MAP[<표준 키>]`를 참조한다. 본문에서 `"Epic"`, `"Story"`, `"Task"`, `"Subtask"` 같은 영문 리터럴을 직접 쓰지 않는다.

### 2-1. assignee 식별자 획득

1. `jira_search(jql="assignee = currentUser()", limit=1, fields="assignee")` 실행.
2. 응답의 `issues[0].fields.assignee` 객체에서 아래 우선순위로 식별자 1개를 확보하여 `{ASSIGNEE}` 변수에 저장:
   - `accountId` (있으면 우선)
   - `emailAddress`
   - `displayName`
3. `issues`가 비어있거나 세 필드가 모두 부재하면 "현재 사용자 assignee 식별자를 조회할 수 없습니다. 본인이 담당자인 이슈가 1건 이상 있어야 합니다." 출력 후 중단.

`{ASSIGNEE}`는 Phase A/B/C 전체에서 재사용한다 (1회만 조회). MCP의 `jira_create_issue` / `jira_batch_create_issues`는 assignee 필드에 email, display name, account ID를 모두 수용하므로 식별자 종류는 무관하다.

> `jira_get_user_profile`의 `user_identifier`가 JQL 함수형 `currentUser()`를 지원하지 않고, search fallback의 assignee 객체에도 accountId가 없을 수 있어 accountId 강제 획득 경로는 사용하지 않는다.

### 2-2. 우선순위

다음 우선순위로 결정:
1. 문서의 우선순위 힌트(`(Priority: P1)` 등) — 있으면 해당 이슈에만 적용
2. Step 0의 `DEFAULT_PRIORITY` — 전체 기본값
3. `Medium` — 최종 fallback

### 2-3. 스프린트

`jira_get_sprints_from_board({BOARD_ID})` 호출.
- 활성 스프린트 1개 이상: 가장 최근 활성 스프린트 자동 선택.
- 활성 스프린트 없음: 백로그로 생성 (스프린트 배정 스킵).

### 2-4. 증거 형태

- **Epic**: `배포 URL` 고정 (최종 산출물 수준)
- **PBI / Sub-task**: Step 0의 `DEFAULT_EVIDENCE` > `PR 링크` fallback

### 2-5. description 조립

이슈 description의 Markdown 구조를 아래로 고정한다. AC와 증거는 커스텀 필드로 분리되므로 description에 포함하지 않는다.

```
## 목적
{문서에서 추출한 Phase 목적 / US 목표 / Task 설명 + 필요 시 자동 보강}

## 범위
**포함**
- {파일 경로 1}
- {파일 경로 2}
- {파일 경로 3 또는 "외 N개"}

**제외**
- {자동 보강: 이 티켓 범위를 벗어나는 명백한 항목}
```

- 파일 경로가 3개 초과면 상위 3개 + "외 N개"로 표기.
- Epic은 파일 경로가 없으므로 "**포함**"에 하위 PBI 요약(타입·요약 1줄씩) 또는 주요 기능 목록을 대체로 배치한다.
- `FIELD_AC`가 `(none)`인 인스턴스에 한해 **예외적으로** description 하단에 `## 완료 조건` 섹션을 추가해 AC 저장처 부재를 보완한다.

### 2-6. AC 자동 생성

이슈 유형별로 판정 가능한 AC 항목을 생성한다. 각 이슈당 최대 5개.

- **Epic**: "하위 PBI 전체 완료" + 비즈니스 목표 달성 문장. 예: "소셜 로그인을 통한 가입 전환율이 측정 가능한 상태가 된다"
- **Story**: "사용자가 {행동}을 하면 {결과}가 된다" 템플릿. 문서에 "독립 테스트" 항목이 있으면 그것을 AC로 변환.
- **Task**: 기술 완료 조건. 예: "파일이 생성된다", "인터페이스가 정의된다"
- **Sub-task**: "구현 완료", "테스트 통과" 수준 완료 조건. 부모 PBI의 AC를 달성하기 위한 실행 단위임을 고려.
- **Spike**: 학습·의사결정 완료 문장. 예: "X 방식의 적용 가능성 여부가 결론으로 도출된다"

판정 불가능한 추상적 표현("잘 동작한다", "충분히 조사한다" 등)은 사용하지 않는다.

### 2-7. SP 자동 추정 (PBI만)

Sub-task에는 SP를 부여하지 않는다. Epic에도 부여하지 않는다.

| 점수 | 기준 |
|------|------|
| 1 | 매우 단순, AC 1~2개, 불확실성 없음 |
| 2 | 작은 기능/수정, AC 2~3개 |
| 3 | 일반 규모, AC 3~4개 |
| 5 | 범위가 넓거나 의존성/불확실성 존재 |
| 8 | 범위 크고 분할 검토 필요 |

하위 Sub-task 수, AC 항목 수, 문서의 Phase 컨텍스트를 고려하여 추천한다. 8pt는 Step 4 미리보기에서 경고만 표시하고 차단하지 않는다.

`FIELD_SP`가 `(none)`이면 이 항목 전체를 스킵한다.

### 2-8. 추정치

문서에 `(estimate: 2d)` 같은 힌트가 있으면 추출, 없으면 빈 값(생략).

### 2-9. 필드 출처(origin) 메타 관리

각 필드를 `{ value, origin }` 구조로 내부 보관한다. **이 메타는 Step 4 터미널 렌더링에만 사용**하며, Step 5 Jira payload에는 포함하지 않는다(Step 5-0에서 strip).

origin 값은 3가지:
- `doc`: 문서에서 그대로 추출 (예: 요약, 파일 경로, Phase/US 목적 원문)
- `auto`: 자동 생성·보강 (예: AC 전부, "제외" 섹션, 비즈니스 목표 문장, SP, 우선순위 fallback)
- `user`: 사용자가 Step 4에서 수정·확정 (Step 4 수정 플로우에서만 부여)

내부 표현 예시:
```
{
  "summary":       { "value": "로그인 페이지에 소셜 버튼 추가", "origin": "doc" },
  "purpose":       { "value": "...", "origin": "doc" },
  "purpose_extra": { "value": "전환율 측정을 위해...", "origin": "auto" },
  "ac": [
    { "value": "소셜 로그인 버튼이 표시된다", "origin": "auto" },
    ...
  ],
  "evidence":      { "value": "PR 링크", "origin": "auto" },
  "priority":      { "value": "High", "origin": "doc" },
  "sp":            { "value": 3, "origin": "auto" }
}
```

Step 3~4는 `value`로 렌더·검증하고, origin은 (B) 블록 마커 매핑에만 쓰인다.


## Step 3 — 콘텐츠 길이 검증 (자동 축약)

사용자 질문 없이 초과 항목을 자동 축약한다.

| 필드 | 제한 |
|------|------|
| 요약 | 100자 이내, 1문장 |
| 목적 | 2~3문장 이내 |
| 범위 포함/제외 | 각 3개 이내 |
| AC 항목 | 최대 5개, 항목당 1~2줄 |
| 증거 | 1~2줄 |

- 초과 필드는 원문 의미를 보존하며 축약한다.
- 축약된 이슈·필드 목록은 Step 4 미리보기 하단에 1줄 요약으로 포함 (예: "축약: 이슈 #3 목적, 이슈 #7 AC 2건").


## Step 4 — 미리보기 + 확인 (유일한 게이트)

구조: (A) 계층 요약 테이블 → (B) 이슈별 전문 블록 또는 자동 생성 전략 요약 → (C) 확인 질문.

### (A) 계층 요약 테이블

```
| # | 타입 | 요약 | 상위 | 우선순위 | SP | 증거 |
|---|------|------|------|---------|-----|------|
| 1 | Epic     | 소셜 로그인 통합            | -  | Medium | - | 배포 URL |
| 2 | Story    | ↳ 로그인 페이지 소셜 버튼   | #1 | High   | 3 | PR 링크  |
| 5 | Sub-task | ↳↳ 소셜 버튼 컴포넌트 구현 | #2 | Medium | - | PR 링크  |
```

- 계층은 "상위" 컬럼(#N) + 요약 앞 `↳` 접두어로 표현(Markdown 공백 손실 회피).
- SP / 증거 / 추정치 슬롯이 `(none)`이면 해당 컬럼 전체를 숨긴다.
- 8pt PBI가 있으면 테이블 아래에 경고 1줄("⚠️ 8pt PBI가 포함되어 있습니다. 분할을 검토하세요.").

### (B) 이슈별 전문 블록 / 자동 생성 전략 요약

**출력 분량 규칙 (토큰 비용 관리)**:
- 이슈 수 **≤ 5개**: (B-1) 전문 블록을 전체 이슈에 대해 출력.
- 이슈 수 **> 5개**: (B-2) "🤖 자동 생성 전략 요약" 3~5줄만 출력. 개별 이슈 전문은 (C)의 "특정 이슈 보기"에서 요청 시만 표시.

**필드 출처 마커** (origin → 접두 마커):

| origin | 접두 마커 | 의미 |
|--------|----------|------|
| `doc`  | (없음)   | 문서에서 그대로 추출. 검토 우선순위 낮음. |
| `auto` | `🤖`     | 자동 생성. 검토 필요. |
| `user` | `👤`     | 사용자가 수정·확정. 재검토 불필요. |

> **이 마커는 터미널 렌더링 전용이다.** Jira payload에는 포함하면 안 된다. Step 5-0에서 strip·검증한다.

#### (B-1) 전문 블록 예시

```
─────────────────────────────────
## 이슈 #2 — 로그인 페이지 소셜 버튼 (Story, 3pt, High)
상위: #1 (소셜 로그인 통합)

### description
## 목적
소셜 OAuth 공급자를 통해 로그인 페이지에서 가입·로그인을 수행할 수 있게 한다.
🤖 전환율 측정을 위해 버튼별 클릭 이벤트를 수집한다.

## 범위
**포함**
- src/components/LoginButton.tsx
- src/pages/Login.tsx

**제외**
🤖 기존 이메일 로그인 플로우 변경

### AC (커스텀 필드)
🤖 1. 소셜 로그인 버튼이 로그인 페이지에 표시된다
🤖 2. 버튼 클릭 시 OAuth 인증 플로우가 시작된다
🤖 3. 인증 성공 시 기본 대시보드로 리다이렉트된다

### 증거
🤖 PR 링크
─────────────────────────────────
```

#### (B-2) 자동 생성 전략 요약 예시

```
### 🤖 자동 생성 전략 요약
- 우선순위: 문서의 "(Priority: P1)" 힌트 → #7~#10 High 적용. 나머지는 config 기본값 Medium.
- AC: Epic은 비즈니스 목표, Story는 "독립 테스트" 항목 변환, Sub-task는 "구현 완료/테스트 통과" 템플릿.
- 증거: config 미설정 → PBI/Sub-task는 "PR 링크", Epic은 "배포 URL" fallback.
- SP: Story는 하위 Sub-task 수 + AC 수 기반, Task는 독립 단위 2~3pt, Sub-task 미부여.
- 추정치: 문서에 힌트 없어 전체 생략.
```

### (C) 확인 질문

AskUserQuestion 선택지는 이슈 수에 따라 달라진다:

- 이슈 **≤ 5개**: "이대로 생성" / "수정" / "취소" (3지)
- 이슈 **> 5개**: "이대로 생성" / "특정 이슈 보기" / "수정" / "취소" (4지)

#### (C-1) "특정 이슈 보기" 선택 시

1. "전문을 볼 이슈 번호를 입력하세요 (예: 7)." 자유 입력 질문.
2. 해당 이슈의 (B-1) 블록만 출력.
3. (C) 재질문. 반복 가능, 아무것도 변경하지 않는다.

#### (C-2) "수정" 선택 시

1. "수정할 이슈 번호를 입력하세요 (예: 2)." 자유 입력 질문.
2. 해당 이슈의 (B-1) 블록을 출력.
3. AskUserQuestion(multiSelect): "수정할 필드를 선택하세요." — 목적 / 범위 / AC / 증거 / 우선순위 / SP / 요약.
4. 선택된 필드마다:
   - **목적·범위·AC·증거**: AskUserQuestion "어떻게 변경할까요?" — 더 구체적으로 / 더 간결하게 / 다른 관점으로 (힌트 입력) / 직접 작성. "다른 관점"은 자유 입력 힌트를 받아 재생성, "직접 작성"은 자유 입력으로 새 값을 받는다.
   - **요약·우선순위·SP**: 직접 입력만.
5. **수정된 필드의 origin을 `user`로 갱신**. 마커는 🤖 → 👤로 바뀐다.
6. (A) 요약 테이블 + (이슈 ≤ 5개인 경우에만) 해당 이슈의 (B-1) 블록 재출력 → (C) 재질문. 전체 이슈의 (B) 블록을 다시 출력하지 않는다.
7. 사용자가 "이대로 생성"을 선택할 때까지 반복. **수정 반복이 5회를 초과**하면 "수정이 자주 반복되고 있습니다. 문서를 보강 후 재실행하는 것이 효율적일 수 있습니다." 안내를 1회 출력.

**수정 불가 필드**: 계층 구조(parent), 타입(Epic/Story/Task/Sub-task), 파일 경로. 이건 문서에서 추출한 값이며, 바꾸려면 문서를 수정해 재실행해야 한다. (C-2) 필드 선택지에 노출하지 않는다.

#### (C-3) "이대로 생성" 선택 시: Step 5로 진행.

#### (C-4) "취소" 선택 시: 아무것도 생성하지 않고 종료.


## Step 5 — Jira 이슈 생성

### 5-0. payload 정화 (필수 선행)

Phase A/B/C 어떤 호출이든 payload를 조립하기 전에 아래 규칙을 적용한다.

1. Step 2-9의 필드 객체(`{ value, origin }`)에서 **`value`만 추출**. origin은 버린다.
2. 문자열 필드(description, AC 항목, 증거, 요약)에 **`🤖` 또는 `👤` 문자가 남아 있지 않은지 최종 검증**. 발견되면 strip하고 "⚠️ 렌더링 마커 누수 — strip 처리됨: 이슈 #N 필드 {field}" 경고를 결과 리포트에 포함한다.
3. 검증 통과한 순수 텍스트만 MCP 도구로 전달한다.

### 5-1. 생성 순서

3단계 계층의 의존 관계를 보장한다:
1. **Phase A**: Epic 생성 (key 확보 필수)
2. **Phase B**: PBI(Story/Task) 생성 — `jira_batch_create_issues` + 후처리 체인
3. **Phase C**: Sub-task 생성 — `jira_create_issue` 단건 호출 (parent 필수라 batch 불가)

> **Phase B와 C의 경로가 다른 이유**
> - `jira_batch_create_issues`는 `additional_fields`를 지원하지 않는다(허용 필드: project_key / summary / issue_type / description / assignee / components). parent·priority·커스텀 필드는 후처리로 붙여야 한다.
> - Sub-task는 Jira 제약상 create 시점에 parent가 필수다. parent 없이는 생성 자체가 거절된다.
> - Phase B(Story/Task)는 제약 1만 있고, Phase C(Sub-task)는 1·2 둘 다 있어 batch 불가.

### 5-2. Phase A — Epic 생성

`jira_create_issue`로 단건 생성한다:
- `project_key`: Step 0의 `{PROJECT_KEY}`
- `issue_type`: `ISSUE_TYPE_MAP["Epic"]`
- `summary`: 확정된 요약
- `assignee`: 2-1에서 확보한 `{ASSIGNEE}`
- `description`: **설정하지 않는다** (빈 티켓)

Epic 후처리 (3단계 호출 체인, 단건 스킬과 동일 패턴):
- **호출 2** — `jira_update_issue`: 커스텀 필드(AC/EV) + priority
  ```json
  {
    "{FIELD_AC}": "1. AC 항목 1\n2. AC 항목 2",
    "{FIELD_EV}": "증거 텍스트",
    "priority": {"name": "Medium"}
  }
  ```
- **호출 3** — `jira_update_issue`: description만 단독 설정
  ```json
  {
    "description": "## 목적\n...\n\n## 범위\n**포함**\n- ...\n\n**제외**\n- ..."
  }
  ```

생성된 Epic의 issue_key를 내부 참조(`#1` 등)에 매핑한다. Epic 생성 실패 시 전체 중단(하위 이슈의 parent 지정 불가).

### 5-3. Phase B — PBI 일괄 생성

`jira_batch_create_issues`를 `validate_only: true`로 사전 검증 후 `validate_only: false`로 실제 생성:

```
jira_batch_create_issues({
  issues: [
    { project_key: "PROJ", summary: "...", issue_type: ISSUE_TYPE_MAP["Story"], assignee: "{ASSIGNEE}" },
    { project_key: "PROJ", summary: "...", issue_type: ISSUE_TYPE_MAP["Task"],  assignee: "{ASSIGNEE}" },
    ...
  ],
  validate_only: false
})
```

검증 실패 건은 에러 원인과 함께 리포트하고 사용자에게 알린다.

각 PBI 후처리 (순차 루프):
- **호출 2** — `jira_update_issue`: 커스텀 필드(SP/AC/EV) + parent(Epic key) + priority + timetracking
  ```json
  {
    "{FIELD_SP}": 3,
    "{FIELD_AC}": "1. AC 항목 1\n2. AC 항목 2",
    "{FIELD_EV}": "증거 텍스트",
    "parent": "{EPIC_KEY}",
    "priority": {"name": "High"},
    "timetracking": {"originalEstimate": "2d"}
  }
  ```
  - `{FIELD_SP}`·`{FIELD_AC}`·`{FIELD_EV}`가 `(none)`이면 해당 키 생략.
  - `timetracking.originalEstimate`는 추정치가 있는 경우만 포함.
- **호출 3** — `jira_update_issue`: description 단독 설정
  ```json
  { "description": "## 목적\n...\n\n## 범위\n..." }
  ```

> **자동화 룰 우회**: parent 설정이 description을 빈 템플릿으로 덮어쓰는 Jira 자동화 룰이 존재하므로, description은 반드시 마지막 호출에서 단독 설정한다. 이 순서는 변경하지 않는다.

각 PBI의 issue_key를 내부 참조에 매핑한다. 부분 실패 시 성공 건만 후속 처리하고, 실패 PBI의 하위 Sub-task는 보류한다.

### 5-4. Phase C — Sub-task 개별 생성

Sub-task는 batch 경로 대신 각 항목마다 아래 **3단계 호출 체인**을 **순차 실행**한다. Phase B와 동일한 3단계 구조를 쓰되 호출 1에서 parent를 함께 설정하는 점만 다르다.

> **Sub-task 타입명**: `issue_type`에는 Step 2-0에서 확보한 `ISSUE_TYPE_MAP["Sub-task"]`를 사용한다. 프로젝트에 Sub-task 타입이 없으면 Step 2-0이 이미 중단시키므로 이 시점에는 반드시 유효한 값이 있다.

**호출 1 — `jira_create_issue` (parent 포함 생성)**:
- `project_key`: `{PROJECT_KEY}`
- `issue_type`: `ISSUE_TYPE_MAP["Sub-task"]`
- `summary`: 확정된 요약
- `assignee`: 2-1에서 확보한 `{ASSIGNEE}`
- `description`: **설정하지 않는다**
- `additional_fields`:
  ```json
  { "parent": "{PBI_KEY}" }
  ```
- priority·커스텀 필드·timetracking은 호출 1에 포함하지 않는다.

**호출 2 — `jira_update_issue` (커스텀 필드 + priority + timetracking)**:
```json
{
  "{FIELD_AC}": "1. 완료 조건 1\n2. 완료 조건 2",
  "{FIELD_EV}": "증거 텍스트",
  "priority": {"name": "Medium"},
  "timetracking": {"originalEstimate": "4h"}
}
```
- `{FIELD_AC}`·`{FIELD_EV}` `(none)` 시 키 생략.
- `timetracking.originalEstimate`는 추정치가 있는 경우만.
- **Sub-task에는 `{FIELD_SP}`를 부여하지 않는다.**
- `parent`는 호출 1에서 이미 설정됨 → 호출 2에 포함하지 않는다.
- **description은 호출 2에 포함하지 않는다** (호출 3에서 단독 설정).

**호출 3 — `jira_update_issue` (description 단독)**:
```json
{
  "description": "## 목적\n...\n\n## 범위\n..."
}
```

> **Phase C가 3단계인 이유**
> Jira Cloud는 `description`(ADF 문서 구조)과 커스텀 필드(plain text)를 한 payload에 혼합하면 ADF 검증을 실패시킨다. Phase B와 동일한 3단계로 분리하면 안전하다. Phase B와의 유일한 차이는 호출 1에서 parent를 함께 설정한다는 점(Sub-task는 Jira 제약상 parent가 create 시점에 필수).

**병렬성**: 같은 부모 PBI 아래 Sub-task를 병렬 호출하지 않는다. 자동화 룰 재진입 타이밍 리스크를 피하기 위해 전체 순차 실행.

**부분 실패 처리**: 특정 Sub-task의 호출 1/2/3 중 어느 단계라도 실패하면 해당 Sub-task만 실패·부분 완료로 집계하고, 나머지 Sub-task 생성은 중단 없이 계속한다. 실패 항목은 Step 7 리포트에 `⚠️ 부분 완료` 또는 `❌ 생성 실패`로 반영.

### 5-5. 스프린트 일괄 배정

Step 2-3에서 스프린트를 선택한 경우 `jira_add_issues_to_sprint`로 일괄 배정:

```
jira_add_issues_to_sprint(
  sprint_id: "{스프린트 ID}",
  issue_keys: "PROJ-101,PROJ-102,PROJ-103,..."
)
```

같은 스프린트의 모든 이슈를 1회 호출로 처리한다. 실패 시 경고만 표시하고 수동 배정을 안내한다.


## Step 6 — Slack DM 알림

> SLACK_ID가 `(none)`이면 이 Step 전체를 스킵한다.

`slack_post_message`로 DM 채널(`SLACK_ID`)에 전송한다. 이슈 URL은 Phase A/B/C 생성 응답의 `self` 필드에서 Jira 도메인을 추출해 `{domain}/browse/{KEY}`로 조립한다.

```
새 Jira 티켓이 일괄 생성되었습니다 🎟️ ({N}건)

*[<{URL}|PROJ-101>] 소셜 로그인 통합* (Epic)
*[<{URL}|PROJ-102>] 로그인 페이지에 소셜 버튼 추가* (Story, 3pt)
  • [<{URL}|PROJ-105>] 소셜 버튼 컴포넌트 구현 (Sub-task)
  • [<{URL}|PROJ-106>] 로그인 폼 레이아웃 조정 (Sub-task)
*[<{URL}|PROJ-103>] OAuth2 콜백 엔드포인트 구현* (Task, 5pt)

• 스프린트: Sprint 24  |  총 SP: 8pt
```

> **실패 처리**: Slack 전송이 실패해도 Jira 이슈 생성은 이미 완료된 상태다. Step 7 결과 출력에 `⚠️ Slack DM 전송 실패: {에러 요약}` 한 줄을 추가하고 워크플로우를 정상 종료한다. 재시도하거나 Jira 이슈를 롤백하지 않는다.


## Step 7 — 결과 리포트

**성공 시**:
```
✅ Jira 이슈가 일괄 생성되었습니다. ({성공}/{전체} 성공)

| # | 키 | 타입 | 요약 | SP |
|---|-----|------|------|----|
| 1 | PROJ-101 | Epic     | 소셜 로그인 통합                | -  |
| 2 | PROJ-102 | Story    | ↳ 로그인 페이지에 소셜 버튼 추가 | 3  |
| 5 | PROJ-105 | Sub-task | ↳↳ 소셜 버튼 컴포넌트 구현      | -  |
| ...

스프린트: Sprint 24  |  총 SP: 8pt

📨 Slack DM으로 알림을 전송했습니다.        ← Slack 전송 성공 시
⚠️ Slack DM 전송 실패: {에러 요약}          ← Slack 활성이지만 전송 실패 시
🔕 Slack 알림이 비활성 상태입니다.            ← SLACK_ID=(none)일 때
                                              (위 세 줄 중 정확히 하나만 출력)
```

**부분 실패 시**:
```
⚠️ 일부 이슈에서 문제가 발생했습니다. ({성공}/{전체} 성공, {N}건 주의)

| # | 키 | 상태 | 비고 |
|---|-----|------|------|
| 1 | PROJ-101 | ✅ 완료 | - |
| 2 | PROJ-102 | ⚠️ 부분 완료 | description 미설정 |
| 3 | -        | ❌ 생성 실패 | issue type 'Spike' not found |
| 4 | -        | ⏸️ 보류     | 상위 이슈(#3) 생성 실패 |
```

AskUserQuestion: "실패 건을 재시도하시겠습니까?" (예/아니오)
- **예**: 실패 건만 추출하여 Step 5의 해당 Phase부터 재실행.
  - Phase A/B 생성 실패: `jira_create_issue` 단건으로 fallback.
  - Phase C 생성 실패: 이미 단건 경로이므로 해당 Sub-task 3단계 체인 재실행.
  - 후처리(호출 2/3) 실패: 해당 `jira_update_issue`만 재실행.
- **아니오**: 현재 상태로 종료. 실패 건은 수동 보정을 안내.

Step 5-0의 마커 strip 경고가 있었다면 리포트 맨 하단에 "⚠️ 렌더링 마커 누수 N건 감지 — 자동 strip됨" 요약 1줄을 추가한다.


## 가이드라인

- 문서 내용을 단일 소스로 신뢰한다. 문서에 없는 정보는 Step 2의 자동 보강 규칙에 따라 메운다.
- 배치 전체에 걸친 공통 값(우선순위·증거 형태)은 config에서 로드하고, 사용자에게 묻지 않는다.
- 사용자 개입은 Step 4 (C) 확인 질문 **1회가 기본**. 수정이나 "특정 이슈 보기"를 선택한 경우에만 추가 질문이 발생한다.
- 🤖·👤 마커는 **터미널 렌더링 전용**이다. Step 5-0에서 반드시 strip 검증.
- 생성된 이슈는 절대 삭제하지 않는다. 부분 실패 시 리포트 + 재시도로 대응.
- Phase A/B/C 모두 3단계 호출 체인을 유지한다. Phase A·B는 "빈 티켓 → 커스텀 필드+parent → description", Phase C는 "create with parent → 커스텀 필드 → description". description을 항상 마지막 단독 호출로 분리해 Jira Cloud ADF 검증과 자동화 룰 덮어쓰기를 동시에 회피한다.
- `description`에는 목적과 범위만 작성한다. AC·증거는 커스텀 필드로 분리. description에 AC·증거를 넣으면 Jira가 잘못 파싱한다.
- AC는 예/아니오로 판정 가능한 형태로 작성한다.
- Sub-task에는 스토리 포인트를 부여하지 않는다.
- Slack 알림은 SLACK_ID가 `(none)`이 아닌 경우에만 전송.
- 이슈 URL은 MCP 응답의 `self` 필드에서 Jira 도메인을 추출해 구성한다. 절대 URL을 코드에 하드코딩하지 않는다.
- 이슈 타입명은 Jira 인스턴스 언어에 맞춘다(영문/한국어 모두 지원).
- PBI는 2~3일, Sub-task는 1일 내 완료 가능한 크기를 기준으로 추정. 초과 시 분할 검토를 권고한다.
