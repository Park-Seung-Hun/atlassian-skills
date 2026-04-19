# Jira 이슈 일괄 생성

SDD(설계 문서)를 파싱하여 Epic / PBI(Story·Task) / Sub-task를 일괄 생성한다.
SDD 파싱 규칙은 `/jira-batch-create-setup`으로 등록한 템플릿을 사용한다.
모든 이슈의 모든 필드를 빠짐없이 채운다.


## Step 1 — SDD 입력 및 파싱

### 1-1. 입력 수집

- `$ARGUMENTS`에 파일 경로(`.md` 확장자 또는 `/`로 시작)가 있으면 Read 도구로 파일 로드
- `$ARGUMENTS`에 SDD 본문이 직접 포함되어 있으면 그대로 사용
- 둘 다 없으면 AskUserQuestion: "SDD 파일 경로를 입력하거나, SDD 내용을 붙여넣어 주세요."

### 1-2. 템플릿 매칭

`{{CONFIG_DIR}}/jira-sdd-templates.yml`을 Read 도구로 로드한다.

- **파일 없음 또는 비어있음**: "SDD 템플릿이 등록되어 있지 않습니다. `/jira-batch-create-setup`을 먼저 실행하세요." 출력 후 중단.
- **파일 있음**: SDD 첫 H1 헤딩을 추출하고, 등록된 템플릿의 `match` 패턴과 순차 비교.
  - 일치하는 템플릿 있음: "템플릿 `{이름}`과 매칭되었습니다." 안내 후 해당 파싱 규칙 사용.
  - 일치 없음: "등록된 SDD 템플릿과 일치하지 않습니다. `/jira-batch-create-setup`으로 템플릿을 등록하세요." 출력 후 중단.

### 1-3. 파싱

매칭된 템플릿 규칙을 적용하여 SDD를 파싱한다:

- 템플릿의 `headings` 규칙으로 Epic / Story / Phase 분류
- 템플릿의 `tasks` 규칙으로 Task / Sub-task 분류 및 parent 연결
  - Sub-task의 parent: 태그(예: `[US1]`)에서 번호를 추출하여 해당 Story를 parent로 연결
  - Task의 parent: Epic
- 템플릿의 `metadata` 규칙으로 목적 / 목표 / AC 힌트 / 파일 경로 추출
- Phase 그룹(`issue: false`)은 이슈로 생성하지 않지만, 하위 Task의 컨텍스트(목적 등)로 활용
- `[P]` 플래그는 정보용, `(Priority: P1)` 등은 우선순위 힌트로 저장

### 1-4. 파싱 결과 확인

파싱 결과를 요약 테이블로 출력한다:

```
SDD 파싱 결과 ({N}건)

| # | 타입 | 요약 | 상위 | 우선순위 힌트 |
|---|------|------|------|-------------|
| 1 | Epic | 플레이그라운드 비교모드 | - | - |
| 2 | Task | Compare 모드 타입 정의 생성 | #1 | - |
| 3 | Story | 비교모드 탭 전환 | #1 | P1 |
| 4 | Sub-task | PlaygroundTabs 컴포넌트 생성 | #3 | - |
```

AskUserQuestion: "이대로 진행 / 수정 / 취소"

- "수정": 수정할 이슈 번호와 내용을 질문 → 반영 후 다시 테이블 출력
- "취소": 중단


## Step 2 — 배치 기본값 수집

SDD에서 추출할 수 없는 공통 필드를 1회 수집한다.

### 2-1. 우선순위

- SDD에서 추출한 Priority 힌트가 있는 이슈는 해당 값을 기본 적용
- 나머지 이슈에 대해 AskUserQuestion: "기본 우선순위를 선택하세요."
  - Highest / High / Medium (추천) / Low / "개별 지정"

### 2-2. 스프린트

Step 0에서 확정한 `{BOARD_ID}`로 `jira_get_sprints_from_board`를 호출한다.
- 활성 스프린트가 있으면 AskUserQuestion에 `"(추천)"` 표시
- 활성 스프린트가 없으면 "백로그로 생성합니다." 안내

### 2-3. 증거 형태

> FIELD_EV가 `(none)`이면 이 항목 전체를 스킵한다.

AskUserQuestion: "증거 형태의 기본값을 선택하세요."
- "PR 링크" (추천) / "Confluence 문서 링크" / "스크린샷·로그" / "개별 지정"


## Step 3 — 개별 이슈 보강 (전체 필드 채우기)

Claude가 SDD 컨텍스트를 활용해 전체 이슈의 초안을 일괄 생성하고, 사용자는 수정이 필요한 것만 터치한다.

### 3-1. 요약 검증

각 이슈의 summary를 검증한다:
- 100자 초과 시 축약 제안
- 결과 중심이 아닌 경우 구체화 제안

전체 목록을 테이블로 출력:
```
| # | 타입 | 요약 | 수정 제안 |
|---|------|------|----------|
| 1 | Epic | 소셜 로그인 통합 | - |
| 2 | Story | 로그인 페이지에 소셜 로그인 버튼 추가 | - |
```

AskUserQuestion: "수정할 이슈 번호를 입력하세요. (없으면 Enter)"

### 3-2. 목적 + 범위 일괄 초안

SDD의 Phase 목적, User Story 목표, Task의 파일 경로를 활용해 각 이슈의 목적(1~2문장) + 범위(포함/제외)를 일괄 생성한다.

- 범위의 "포함"에 SDD에서 추출한 `file_path`를 자연스럽게 반영
- Phase의 `목적` 텍스트를 하위 Task / Sub-task의 목적 컨텍스트로 활용
- User Story의 `목표` 텍스트를 해당 Story 및 하위 Sub-task의 목적에 반영

각 이슈의 초안을 출력:
```
## 이슈 #1 — 소셜 로그인 통합 (Epic)
**목적**: ...
**포함**: ...
**제외**: ...

## 이슈 #2 — 로그인 페이지에 소셜 로그인 버튼 추가 (Story)
**목적**: ...
**포함**: ...
**제외**: ...
```

AskUserQuestion: "수정할 이슈 번호를 입력하세요. (없으면 Enter)"
- 수정할 이슈만 개별 목적/범위 재수집

### 3-3. AC 일괄 초안

> FIELD_AC가 `(none)`이면 이 항목 전체를 스킵한다.

이슈 유형별 기준으로 AC를 자동 생성한다:
- **Story**: User Story의 "독립 테스트" 항목 + 사용자 관점 행동/결과 기준
- **Task**: 기술적 완료 기준 (파일 생성, 설정 적용 등)
- **Sub-task**: 구현 완료 / 테스트 통과 기준
- **Epic**: 하위 PBI 전체 완료 기준

AC는 예/아니오로 판정 가능한 형태로 작성한다. 판정 불가능한 추상적 표현("잘 동작한다", "충분히 조사한다" 등)은 구체화한다. 각 이슈당 최대 5개.

```
## 이슈 #2 — 로그인 페이지에 소셜 로그인 버튼 추가 (Story)
1. 소셜 로그인 버튼이 로그인 페이지에 표시된다
2. 버튼 클릭 시 OAuth 인증 플로우가 시작된다
3. ...

## 이슈 #3 — OAuth2 콜백 엔드포인트 구현 (Task)
1. ...
```

AskUserQuestion: "수정할 이슈 번호를 입력하세요. (없으면 Enter)"

### 3-4. 증거 형태

> FIELD_EV가 `(none)`이면 이 항목 전체를 스킵한다.

Step 2에서 공통 기본값을 선택했으면 모든 이슈에 일괄 적용한다.
"개별 지정"이면 테이블로 제시 → 수정만 받는다.

### 3-5. 개별 지정 필드

Step 2에서 "개별 지정"을 선택한 필드(우선순위 등)가 있을 때만 실행한다.

테이블로 제시:
```
| # | 요약 (앞 30자) | 우선순위 |
|---|---------------|---------|
| 1 | 소셜 로그인 통합... | Medium |
| 2 | 로그인 페이지에... | High |
```

AskUserQuestion: "변경할 항목이 있으면 `번호.필드=값` 형식으로 입력하세요. (예: `2.priority=High`) 없으면 Enter."

### 3-6. 최초 추정치

테이블로 일괄 제시 (미입력 허용):
```
| # | 요약 (앞 30자) | 추정치 |
|---|---------------|--------|
| 1 | 소셜 로그인 통합... | - |
| 2 | 로그인 페이지에... | - |
```

AskUserQuestion: "추정치를 입력하세요. `번호=값` 형식. (예: `2=2d, 3=4h`) 없으면 Enter."

### 3-7. 스토리 포인트 일괄 추천 (PBI만)

> FIELD_SP가 `(none)`이면 이 항목 전체를 스킵한다.
> Sub-task에는 스토리 포인트를 부여하지 않는다.

모든 필드 수집이 완료된 후 다음 기준으로 점수를 판단한다:

| 점수 | 기준 |
|------|------|
| 1 | 매우 단순, AC 1~2개, 불확실성 없음 |
| 2 | 작은 기능/수정, AC 2~3개 |
| 3 | 일반 규모, AC 3~4개 |
| 5 | 범위가 넓거나 의존성/불확실성 존재 |
| 8 | 범위 크고 분할 검토 필요 |

SDD의 Phase 정보, 하위 Sub-task 수, AC 항목 수를 고려하여 추천한다:
```
| # | 요약 | 하위 Sub-task | 추천 SP | 근거 |
|---|------|-------------|--------|------|
| 2 | 로그인 페이지에... | 2개 | 3 | AC 3개, 일반 규모 |
| 3 | OAuth2 콜백... | 0개 | 5 | 외부 의존성 |
```

AskUserQuestion: "수정할 이슈가 있으면 `번호=포인트` 형식으로. 없으면 Enter."
- 8pt 선택 시: "8pt는 분할을 먼저 검토해야 하는 크기입니다. 이대로 진행하시겠습니까?" 경고


## Step 4 — 콘텐츠 길이 검증

단건과 동일 기준을 전체 이슈에 일괄 적용한다:

| 필드 | 제한 |
|------|------|
| 요약 | 100자 이내, 1문장 |
| 목적 | 2~3문장 이내 |
| 범위 포함/제외 | 각 3개 이내 |
| AC 항목 | 최대 5개, 항목당 1~2줄 |
| 증거 | 1~2줄 |

초과 항목이 있으면 해당 이슈 번호와 필드를 리스트로 보여주고 축약을 제안한다.
모든 항목이 기준 이내이면 "콘텐츠 길이 검증 통과" 안내 후 다음 단계로 진행한다.


## Step 5 — 미리보기 & 확인

전체 이슈를 계층 구조로 출력한다:

```
## 일괄 생성 미리보기 ({N}건)

| # | 타입 | 요약 | 상위 | 우선순위 | SP | 추정치 | 스프린트 |
|---|------|------|------|---------|-----|--------|---------|
| 1 | Epic | 소셜 로그인 통합 | - | Medium | - | - | Sprint 24 |
|   2 | Story | 로그인 페이지에 소셜 버튼 추가 | #1 | High | 3 | 2d | Sprint 24 |
|     5 | Sub-task | 소셜 버튼 컴포넌트 구현 | #2 | Medium | - | 1d | Sprint 24 |
|     6 | Sub-task | 로그인 폼 레이아웃 조정 | #2 | Medium | - | 4h | Sprint 24 |
|   3 | Task | OAuth2 콜백 엔드포인트 구현 | #1 | Medium | 5 | 3d | Sprint 24 |

총 스토리 포인트: 8pt
```

상세 보기 (각 이슈의 목적/범위/AC/증거):
- 접힌 형태로 표시하되, 사용자가 요청하면 펼쳐서 보여준다

AskUserQuestion: "이대로 생성 / 수정 / 취소"

- "수정": 수정할 번호와 필드를 질문 → Step 3의 해당 항목으로 부분 회귀
- "취소": 중단


## Step 6 — Jira 이슈 생성

### 6-1. assignee 확인

`jira_search`로 `assignee = currentUser()` 이슈를 조회하여 현재 사용자 email을 확인한 후 `jira_get_user_profile`로 accountId를 획득한다. (1회만 실행)

### 6-2. 생성 순서 결정

3단계 계층의 의존 관계를 보장한다:
1. **Phase A**: Epic 생성 (key 확보 필수)
2. **Phase B**: PBI(Story/Task) 생성 (Epic key를 parent로 사용)
3. **Phase C**: Sub-task 생성 (PBI key를 parent로 사용)

### 6-3. Phase A — Epic 생성

`jira_create_issue`로 단건 생성한다:
- `project_key`: Step 0에서 로드한 `{PROJECT_KEY}`
- `issue_type`: Jira 인스턴스 언어에 맞는 Epic 타입명
- `summary`: 확정된 요약
- `assignee`: 6-1에서 획득한 email
- `description`: **설정하지 않는다** (빈 티켓)

Epic 후처리 (3단계 호출 체인):
- **호출 2**: `jira_update_issue` — 커스텀 필드(AC/EV) + priority
  ```json
  {
    "{FIELD_AC}": "1. AC 항목 1\n2. AC 항목 2",
    "{FIELD_EV}": "증거 텍스트"
  }
  ```
- **호출 3**: `jira_update_issue` — description만 단독 설정
  ```json
  {
    "description": "## 목적\n{확정된 목적 텍스트}\n\n## 범위\n**포함**\n- ...\n\n**제외**\n- ..."
  }
  ```

생성된 Epic의 issue_key를 내부 참조(`#1` 등)에 매핑한다.
Epic 생성 실패 시 전체 중단한다 (하위 이슈의 parent를 지정할 수 없음).

### 6-4. Phase B — PBI 일괄 생성

`jira_batch_create_issues`를 사용한다.

먼저 `validate_only: true`로 사전 검증:
```
jira_batch_create_issues({
  issues: [
    { project_key: "PROJ", summary: "...", issue_type: "Story", assignee: "user@example.com" },
    { project_key: "PROJ", summary: "...", issue_type: "Task", assignee: "user@example.com" },
    ...
  ],
  validate_only: true
})
```

검증 실패 건이 있으면 에러 원인을 리포트하고 사용자에게 수정을 요청한다.
검증 통과 후 `validate_only: false`로 실제 생성한다.

> **batch API 제한**: `jira_batch_create_issues`는 priority, additional_fields(커스텀 필드, parent)를 지원하지 않는다. 기본 필드(summary, issue_type, assignee)만 설정 가능.

각 PBI 후처리 (루프):
- **호출 2**: `jira_update_issue` — 커스텀 필드(SP/AC/EV) + parent(Epic key) + priority + timetracking
  ```json
  {
    "{FIELD_SP}": 3,
    "{FIELD_AC}": "1. AC 항목 1\n2. AC 항목 2",
    "{FIELD_EV}": "증거 텍스트",
    "parent": "{EPIC_KEY}",
    "timetracking": {"originalEstimate": "2d"}
  }
  ```
  - `{FIELD_SP}`: 스토리 포인트 (FIELD_SP가 `(none)`이면 이 키 자체를 생략)
  - `{FIELD_AC}`: AC 항목을 `\n` 구분 번호 목록으로 작성 (FIELD_AC가 `(none)`이면 생략)
  - `{FIELD_EV}`: 증거 텍스트 (FIELD_EV가 `(none)`이면 이 키 자체를 생략)
  - `parent`: Epic의 issue_key
  - `timetracking.originalEstimate`: 입력한 경우만 포함
- **호출 3**: `jira_update_issue` — description만 단독 설정
  ```json
  {
    "description": "## 목적\n{확정된 목적 텍스트}\n\n## 범위\n**포함**\n- ...\n\n**제외**\n- ..."
  }
  ```

> **자동화 룰 우회**: parent 설정이 description을 빈 템플릿으로 덮어쓰므로, description은 반드시 마지막에 단독 호출한다. 이 순서는 절대 변경하지 않는다.

각 PBI의 issue_key를 내부 참조에 매핑한다.
부분 실패 시: 성공 건만 후속 처리, 실패 PBI의 하위 Sub-task도 보류한다.

### 6-5. Phase C — Sub-task 일괄 생성

Phase B와 동일한 패턴으로 처리한다:

`jira_batch_create_issues`로 일괄 생성 (`validate_only` 사전 검증 포함).

각 Sub-task 후처리:
- **호출 2**: `jira_update_issue` — 커스텀 필드(AC/EV) + parent(PBI key) + priority + timetracking
  ```json
  {
    "{FIELD_AC}": "1. 완료 조건 1\n2. 완료 조건 2",
    "{FIELD_EV}": "증거 텍스트",
    "parent": "{PBI_KEY}",
    "timetracking": {"originalEstimate": "4h"}
  }
  ```
  - Sub-task에는 스토리 포인트를 부여하지 않는다 (`{FIELD_SP}` 키 생략)
- **호출 3**: `jira_update_issue` — description만 단독 설정

> **Sub-task 주의**: parent를 호출 2에서 설정해야 한다. `jira_create_issue` 또는 `jira_batch_create_issues` 시점에 parent를 설정하면 자동화 룰이 즉시 발동하여 이후 커스텀 필드 설정이 초기화될 수 있다.

부분 실패 시: 성공 건만 후속, 실패 건 리포트.

### 6-6. 스프린트 일괄 배정

스프린트를 선택한 경우 `jira_add_issues_to_sprint`로 일괄 배정한다:
```
jira_add_issues_to_sprint(
  sprint_id: "{스프린트 ID}",
  issue_keys: "PROJ-101,PROJ-102,PROJ-103,..."
)
```

같은 스프린트의 모든 이슈를 1회 호출로 처리한다.
실패 시 경고만 표시, 수동 배정을 안내한다.


## Step 7 — Slack DM 알림 전송

> SLACK_ID가 `(none)`인 경우 이 Step 전체를 스킵한다.

`slack_post_message`로 DM 채널(`SLACK_ID`)에 전송한다:

```
새 Jira 티켓이 일괄 생성되었습니다 🎟️ ({N}건)

*[PROJ-101] 소셜 로그인 통합* (Epic)
*[PROJ-102] 로그인 페이지에 소셜 로그인 버튼 추가* (Story, 3pt)
  • [PROJ-105] 소셜 버튼 컴포넌트 구현 (Sub-task)
  • [PROJ-106] 로그인 폼 레이아웃 조정 (Sub-task)
*[PROJ-103] OAuth2 콜백 엔드포인트 구현* (Task, 5pt)

• 스프린트: Sprint 24  |  총 SP: 8pt
• 링크: [Jira 보드 URL]
```

> **실패 처리**: Slack 전송이 실패해도 Jira 이슈 생성은 이미 완료된 상태다. `slack_post_message` 호출이 실패하면 Step 8 결과 출력에 `⚠️ Slack DM 전송 실패: {에러 요약}` 한 줄을 추가하고 워크플로우를 정상 종료한다. 재시도하거나 Jira 이슈를 롤백하지 않는다.


## Step 8 — 결과 리포트

**성공 시:**
```
✅ Jira 이슈가 일괄 생성되었습니다. ({성공}/{전체} 성공)

| # | 키 | 타입 | 요약 | SP |
|---|-----|------|------|----|
| 1 | PROJ-101 | Epic | 소셜 로그인 통합 | - |
|   2 | PROJ-102 | Story | 로그인 페이지에 소셜 버튼 추가 | 3 |
|     5 | PROJ-105 | Sub-task | 소셜 버튼 컴포넌트 구현 | - |
| ...

스프린트: Sprint 24  |  총 SP: 8pt

📨 Slack DM으로 알림을 전송했습니다.        ← Slack 전송 성공 시
⚠️ Slack DM 전송 실패: {에러 요약}          ← Slack 활성이지만 전송 실패 시
🔕 Slack 알림이 비활성 상태입니다.            ← SLACK_ID=(none)일 때
                                              (위 세 줄 중 정확히 하나만 출력)
```

**부분 실패 시:**
```
⚠️ 일부 이슈에서 문제가 발생했습니다. ({성공}/{전체} 성공, {N}건 주의)

| # | 키 | 상태 | 비고 |
|---|-----|------|------|
| 1 | PROJ-101 | ✅ 완료 | - |
| 2 | PROJ-102 | ⚠️ 부분 완료 | description 미설정 |
| 3 | - | ❌ 생성 실패 | issue type 'Spike' not found |
| 4 | - | ⏸️ 보류 | 상위 이슈(#3) 생성 실패 |
```

AskUserQuestion: "실패 건을 재시도하시겠습니까? (예/아니오)"
- "예": 실패 건만 추출하여 Step 6의 해당 Phase부터 재실행
  - 생성 실패: `jira_create_issue` 단건으로 fallback
  - 보강 실패: 해당 `jira_update_issue`만 재실행

8pt PBI가 포함된 경우:
```
⚠️ 8pt PBI가 포함되어 있습니다. 스프린트 계획 시 더 작은 PBI로 분할을 검토해 주세요.
```


## 가이드라인

- SDD 컨텍스트를 최대한 활용하여 초안을 생성한다. 사용자가 수정할 필요를 최소화하는 것이 목표다.
- 배치 레벨 기본값을 먼저 수집하여 개별 질문 횟수를 줄인다.
- Epic 세트 생성 시 Epic을 반드시 먼저 생성하고 key 확정 후 하위 이슈를 처리한다.
- 생성된 이슈는 절대 삭제하지 않는다. 부분 실패 시 리포트 + 재시도로 대응한다.
- 3단계 호출 체인(빈 티켓 → 커스텀 필드+parent → description)의 순서를 반드시 준수한다.
- `validate_only`를 활용하여 생성 전 유효성을 사전 검증한다.
- `description`에는 목적과 범위만 작성한다. AC·증거는 커스텀 필드로 분리한다. description에 AC/증거를 넣으면 Jira가 잘못 파싱한다.
- AC는 "예/아니오"로 판정 가능한지 항상 검토한다. 판정 불가능한 추상적 표현은 구체화를 권고한다.
- Sub-task에는 스토리 포인트를 부여하지 않는다.
- Slack 알림은 SLACK_ID가 `(none)`이 아닌 경우에만 전송하며, 사용자에게 별도 확인을 요청하지 않는다.
- 이슈 URL은 MCP 서버에 설정된 Jira 도메인을 기준으로 구성한다. 절대 URL을 코드에 하드코딩하지 않는다.
- 이슈 타입명은 Jira 인스턴스 언어에 맞춘다 (영문/한국어 모두 지원).
- 티켓 내용은 간결하게 유지한다. 팀원이 5분 내에 파악할 수 있는 수준이 적절하다.
