# Jira 이슈 생성

팀 작성 지침에 따라 Jira 이슈를 생성한다. 사용자는 작업과 목적만 제공하고, 나머지 필드는 Claude가 질문을 통해 수집한다. 생성 완료 후 Slack DM으로 티켓 정보를 전송한다.


## Step 1 — 작업·목적 파악

인수(`$ARGUMENTS`)가 있으면 그 내용을 작업·목적으로 파악한다.
인수가 없으면 AskUserQuestion으로 다음을 수집한다:
- "어떤 작업을, 왜 하려고 하시나요? (무엇을 + 왜를 함께 설명해 주세요)"

파악된 내용을 바탕으로 이슈 타입을 추론한 뒤 AskUserQuestion으로 확인한다.
- 추론한 타입을 첫 번째 선택지에 `"(추천)"` 표시로 제시
- 선택지: Story (스토리) / Task (작업) / Bug (버그) / Spike (스파이크) / Sub-task (하위 작업)

**타입 판단 기준:**
- Story (스토리): 사용자 관점의 기능, 행동 변화
- Task (작업): 기술적 구현, 인프라, 내부 작업
- Bug (버그): 현재 동작이 의도와 다른 문제
- Spike (스파이크): 조사·탐색·의사결정이 목적
- Sub-task (하위 작업): 기존 PBI를 완료하기 위한 실행 단위


## Step 2 — 타입별 필드 수집

### PBI (Story / Task / Bug / Spike)

**요약 (Summary):**
- Step 1 내용을 바탕으로 결과 중심의 요약 초안을 생성한다.
- 형식: "~할 수 있다" 또는 "~가 완료된다" 형태의 1문장, 100자 이내
- AskUserQuestion으로 초안을 제시하고 수정 여부 확인

**상위항목 (Parent Epic):**
`jira_search`로 해당 프로젝트의 미완료 에픽 목록을 조회한다 (한국어/영문 Jira 인스턴스 모두 지원):
```
issuetype in (Epic, "에픽") AND project = {PROJECT_KEY} AND statusCategory != Done ORDER BY updated DESC
```
조회된 에픽 목록을 AskUserQuestion 선택지로 제시한다 (최대 4개).
- **"상위항목 없음" 선택지를 항상 포함한다** (에픽 후보 유무와 무관). Epic 연결을 강제하지 않기 위함.
- 선택된 에픽 key를 `additional_fields.parent` 에 설정한다. "상위항목 없음" 선택 시 parent 키 자체를 생략한다.

**목적:**
Step 1 내용을 바탕으로 "왜 이 작업을 하는지"를 1~2문장으로 요약한 목적 초안을 생성한다.
AskUserQuestion으로 초안을 제시하고 수정 여부를 확인한다. 확정된 목적 텍스트는 이후 description에 사용된다.

**범위:**
Step 1 내용을 바탕으로 포함/제외 항목 초안을 생성한다 (FIELD_AC 설정과 무관하게 항상 수집).
AskUserQuestion으로 초안을 제시하고 수정 여부를 확인한다:
- 포함할 것 (최대 3항목)
- 제외할 것 (최대 3항목, 없으면 생략 가능)

확정된 범위는 이후 description에 사용된다.

**인수 기준 (AC):**

> FIELD_AC가 `(none)`인 경우 **이 AC 단계만** 스킵한다. 범위·증거는 영향받지 않는다.

AskUserQuestion으로 수집 (최대 5개):
- 예/아니오로 판정 가능한 형태로 가이드
- 이슈 유형에 따라 AC 작성 기준이 다르다:
  - **기능 PBI (Story/Task/Bug)**: 사용자 관점의 행동과 결과를 명시한다. 예: "사용자가 X를 하면 Y가 된다" / "Z 조건에서 에러가 발생하지 않는다"
  - **Spike (조사/기획 PBI)**: 학습 완료 또는 의사결정 완료를 판정 기준으로 작성한다. 예: "X 방식의 기술적 적용 가능성 여부가 결론으로 도출된다" / "Y에 대한 팀 합의가 완료된다"
- 판정 불가능한 추상적 표현("잘 동작한다", "충분히 조사한다" 등)은 구체화를 권고
- → `{FIELD_AC}`에 번호 목록으로 저장

**증거 형태:**

> FIELD_EV가 `(none)`인 경우 **이 증거 단계만** 스킵한다.

증거 형태는 hub 본문 "[필수] 증거 형태 추론 규칙" 절을 적용해 task 성격에서 자동 추론한다 (코드/테스트 → PR 링크, 문서 → Confluence 링크, UI/수동 시연 → 스크린샷·로그, 회귀·비교 → 비교표·로그, 모호 → `(none)`). 추론된 값을 사용자에게 한 줄 안내 후 확인 질문(`예/아니오`)으로 확정한다. "아니오"면 AskUserQuestion으로 다시 받기(Confluence / PR·커밋 / 데모 / 스크린샷·로그 / 기타). 확정 값을 `{FIELD_EV}`에 저장.

**우선순위:**
hub 본문 "[필수] 우선순위 추론 규칙" 절을 적용해 자동 추론한다 (spec-kit 라벨/Priority 표기 → High/Medium/Low → 부모 PBI/epic 상속 → Medium fallback). 추론된 값을 사용자에게 한 줄 안내 후 확인 질문(`예/아니오`)으로 확정한다. "아니오"면 AskUserQuestion으로 다시 받기(Highest / High / Medium / Low).

**최초 추정치:**
AskUserQuestion으로 수집 (선택 사항):
- 입력 형식: "2d", "4h" 등. 미입력 가능.
- → `additional_fields.timetracking.originalEstimate`에 설정

**스프린트 배정:**
Step 0에서 확정한 `{BOARD_ID}`를 사용하여 `jira_get_sprints_from_board`로 활성 스프린트를 조회한다.
- 활성 스프린트가 있으면: 해당 스프린트를 `"(추천)"` 표시로 AskUserQuestion 제시
- 활성 스프린트가 없으면: 백로그로 생성 (스프린트 배정 없음, 사용자에게 안내)


### Sub-task

**부모 이슈 키:**
AskUserQuestion으로 수집 (필수). {PROJECT_KEY}-NNN 형식 검증 (예: {PROJECT_KEY}-123). 형식이 맞지 않으면 재입력 요청.
→ `additional_fields.parent`에 설정

**요약:**
Step 1 내용을 바탕으로 실행 내용이 명확히 드러나는 초안 생성 후 확인. 100자 이내.

**완료 조건:**

> FIELD_AC가 `(none)`인 경우 이 항목 전체를 스킵한다. description에 포함하지 않는다 (description에 AC를 넣으면 Jira가 잘못 파싱한다).

AskUserQuestion으로 수집. "구현 완료", "테스트 통과" 같은 기술적 마침표 기준.
→ `{FIELD_AC}`에 저장

**증거 형태:**

> FIELD_EV가 `(none)`인 경우 이 항목 전체를 스킵한다.

증거는 hub 본문 "[필수] 증거 형태 추론 규칙"을 적용해 자동 추론한다. Sub-task의 경우 부모 PBI에서 증명 가능하면 `(none)`으로 둔다(DoD 5.4 — 부모 PBI 증거로 갈음). 추론값을 사용자에게 한 줄 안내 후 확인 질문(`예/아니오`)으로 확정한다. "아니오"면 AskUserQuestion으로 다시 받기. → `{FIELD_EV}`에 저장.

**설명 (선택):**
AskUserQuestion. 요약이 충분히 명확하면 생략 가능.

**최초 추정치 (선택):**
AskUserQuestion. 입력 형식: "1d", "4h" 등. 미입력 가능. 스토리 포인트는 부여하지 않는다.


## Step 3 — 스토리 포인트 추천 (PBI만)

> FIELD_SP가 `(none)`인 경우 이 Step 전체를 스킵한다.

모든 필드 수집이 완료된 후 다음 기준으로 점수를 판단한다:

| 점수 | 기준 |
|------|------|
| 1 | 매우 단순, AC 1~2개, 불확실성 없음 |
| 2 | 작은 기능/수정, AC 2~3개 |
| 3 | 일반 규모, AC 3~4개 |
| 5 | 범위가 넓거나 의존성/불확실성 존재 |
| 8 | 범위 크고 분할 검토 필요 |

- 범위, AC 항목 수, 의존성, 불확실성, 기술 복잡도를 종합 판단
- AskUserQuestion 선택지에 `"3pt (추천)"` 형태로 추천값 강조 표시
- 8pt 선택 시 "8pt는 분할을 먼저 검토해야 하는 크기입니다. 이대로 진행하시겠습니까?" 경고 포함


## Step 4 — 콘텐츠 길이 검증

생성 전 각 필드가 아래 기준을 초과하면 핵심만 남기도록 요약을 제안한다:

| 필드 | 제한 |
|------|------|
| 요약 | 100자 이내, 1문장 |
| 목적 | 2~3문장 이내 |
| 범위 포함/제외 | 각 3개 이내 |
| AC 항목 | 최대 5개, 항목당 1~2줄 |
| 증거 | 1~2줄 |


## Step 5 — 미리보기 & 확인

수집된 모든 필드를 아래 형태로 출력한다:

```
## 생성될 Jira 이슈 미리보기

**타입**: Task
**요약**: 인증 토큰 자동 갱신 기능을 사용할 수 있다.
**상위항목**: {PROJECT_KEY}-N 에픽 제목
**우선순위**: Medium
**스프린트**: {스프린트명} (추천)
**스토리 포인트**: 3
**최초 추정치**: 2d

**목적**: 현재 토큰 만료 시 사용자가 강제 로그아웃되는 문제를 해결한다.

**범위**
- 포함: 액세스 토큰 만료 감지, 리프레시 토큰으로 갱신 요청, 실패 시 로그아웃 처리
- 제외: 리프레시 토큰 만료 정책 변경, 소셜 로그인 연동

**인수 기준 (AC)**
1. 액세스 토큰 만료 1분 전에 자동으로 갱신 요청이 발생한다.
2. 갱신 성공 시 사용자 세션이 유지된다.
3. 리프레시 토큰도 만료된 경우 로그인 페이지로 리다이렉트된다.

**증거**: PR 링크
```

AskUserQuestion으로 "이대로 생성 / 수정" 확인.

"이대로 생성"이 선택되면 **hub `0-0a` 지연 실행 서브루틴을 반드시 호출**한다 (customfield probe 이연 규약). config 로드 경로(0-0 성공)이고 `customfield_probe_passed` 플래그가 false(또는 미설정)인 경우에만 실제 `jira_search_fields` probe를 수행한다. `0-1` fallback / `0-2` 오버라이드 경로는 호출을 스킵한다.

- **통과** → 플래그 `customfield_probe_passed = true` 세팅 후 Step 6로 진행.
- **재지정** (config 또는 세션 필드 맵이 변경됨) → `customfield_probe_passed = true` 세팅 후 **먼저 재확인 질문을 출력**하고, "이어서 생성" 응답을 받은 뒤에만 Step 6로 진행한다. Step 2 수집값은 그대로 유지한다.
  - AskUserQuestion(단일 선택): "설정이 변경됐습니다 ({변경 슬롯 요약}). 이 설정으로 생성을 이어갈까요?"
    - **이어서 생성** → Step 6 진입.
    - **취소** → 아무것도 생성하지 않고 스킬 종료.
  - 직전 Step 5 "이대로 생성" 응답을 근거로 재확인을 생략하고 바로 Step 6 호출로 진입하는 것을 금지.
- **중단** → 아무것도 생성하지 않고 스킬 종료.


## Step 6 — Jira 이슈 생성

다음 순서로 실행한다:

1. **이슈 타입 맵 확보** — Jira 인스턴스 언어가 한국어이면 `Story`가 아닌 `스토리`만 수용하는 식으로 이슈 타입 이름이 로컬라이즈된다. 호출 1이 사용할 **`ISSUE_TYPE_MAP`**을 **Step 6 진입 직후·호출 1 직전**에 정확히 1회 구축한다.

   > **호출 시점 가드**: Step 5 미리보기 단계나 그 이전(Step 1 타입 추론, Step 2 에픽 조회 등)에서 `jira_search(..., fields="issuetype", ...)`를 미리 호출하지 않는다. Step 6 진입 후의 1회 호출만이 ISSUE_TYPE_MAP의 정식 출처다. 사전 조회로 얻은 타입 정보가 있더라도 Step 6에서 재호출해 매핑을 갱신한다(인스턴스 설정 변경 가능성 차단).

   **알고리즘**:

   1. `jira_search(jql="project = {PROJECT_KEY}", fields="issuetype", limit=50)` 실행.

      - **1단계 (이슈가 1건 이상)**: 응답의 `issues[].issue_type.name`을 고유 집합으로 수집 → 2번으로 진행.
      - **2단계 (issues가 비어 있을 때)**: 아래 후보 이름 리스트로 `jira_batch_create_issues`에 `validate_only=true`로 1회 호출하여 어떤 이름이 검증을 통과하는지 확인한다.

        후보 목록:
        ```
        ["Story", "스토리", "Task", "작업", "Bug", "버그", "Spike", "스파이크", "Sub-task", "하위 작업", "Subtask"]
        ```

        호출 형태:
        ```
        jira_batch_create_issues(
          issues=[
            {"project_key": "{PROJECT_KEY}", "issue_type": "Story",     "summary": "type-probe"},
            {"project_key": "{PROJECT_KEY}", "issue_type": "스토리",    "summary": "type-probe"},
            {"project_key": "{PROJECT_KEY}", "issue_type": "Task",      "summary": "type-probe"},
            {"project_key": "{PROJECT_KEY}", "issue_type": "작업",      "summary": "type-probe"},
            {"project_key": "{PROJECT_KEY}", "issue_type": "Bug",       "summary": "type-probe"},
            {"project_key": "{PROJECT_KEY}", "issue_type": "버그",      "summary": "type-probe"},
            {"project_key": "{PROJECT_KEY}", "issue_type": "Spike",     "summary": "type-probe"},
            {"project_key": "{PROJECT_KEY}", "issue_type": "스파이크",  "summary": "type-probe"},
            {"project_key": "{PROJECT_KEY}", "issue_type": "Sub-task",  "summary": "type-probe"},
            {"project_key": "{PROJECT_KEY}", "issue_type": "하위 작업", "summary": "type-probe"},
            {"project_key": "{PROJECT_KEY}", "issue_type": "Subtask",   "summary": "type-probe"}
          ],
          validate_only=true
        )
        ```

        > `validate_only=true`이므로 실제 이슈는 생성되지 않는다. summary "type-probe"는 정리 불필요.

        응답에서 에러 없이 검증 통과한 후보 이름만 수집 → 이 집합을 고유 집합으로 사용해 2번으로 진행. probe 호출이 전체 거절되거나 집합이 비어 있으면 3번의 에러 메시지를 출력하고 중단한다.

   2. 표준 키 → 실제 인스턴스 이름 매핑:

      ```
      ISSUE_TYPE_MAP = {
        "Story":    <수집 집합 중 "스토리" 우선, 없으면 "Story">,
        "Task":     <"작업" 우선, 없으면 "Task">,
        "Bug":      <"버그" 우선, 없으면 "Bug">,
        "Spike":    <"스파이크" 우선, 없으면 "Spike">,
        "Sub-task": <"하위 작업" 우선, 없으면 "Sub-task" 또는 "Subtask">
      }
      ```

      > 한국어 이름을 우선하는 이유: 사내 Jira 인스턴스 기본값이 한국어 로컬라이즈.

   3. Step 1에서 선택된 타입(Story/Task/Bug/Spike/Sub-task 중 1개)의 매핑이 비거나 null이면:
      > "프로젝트 {PROJECT_KEY}에서 {표준 키} 이슈 타입을 찾을 수 없습니다. 프로젝트의 이슈 타입 설정을 확인하세요."
      출력 후 중단.

   4. Step 1에서 선택되지 않은 표준 키는 매핑 실패해도 무시한다(예: Story만 선택된 흐름에서 Spike 부재).

   **재사용**: 호출 1의 `issue_type` 필드는 `ISSUE_TYPE_MAP[<Step 1 선택>]`을 참조한다. 영문 리터럴(`Story`, `Task` 등)을 직접 쓰지 않는다.

2. **assignee 식별자 획득** — Step 6 진입 후 ISSUE_TYPE_MAP 확보 직후에 `jira_search(jql="assignee = currentUser()", limit=1, fields="assignee")`로 현재 사용자의 식별자를 1회 조회한다(이전 Step에서 미리 호출하지 않는다). 응답의 `issues[0].assignee` 객체에서 `id` → `email` → `display_name` 우선순위로 1개를 확보하여 `{ASSIGNEE}`에 저장한다. 응답이 비거나 세 필드가 모두 부재하면 **`{ASSIGNEE} = null`로 설정**하고 아래 안내를 1줄 출력한 뒤 진행한다(중단하지 않는다):
   ```
   ⚠️ 현재 사용자 assignee를 자동 식별할 수 없습니다. unassigned로 생성합니다.
   ```
   > `jira_get_user_profile`의 `user_identifier`는 JQL 함수형 `currentUser()`를 지원하지 않으므로 `jira_search` 단일 시도만 수행한다. `{ASSIGNEE} = null`이면 호출 1 payload의 `assignee` 키 자체를 생략한다(아래 호출 1 참조). MCP의 `jira_create_issue`는 assignee 필드에 `id` / `email` / `display_name` 중 어느 것이든 수용한다. Jira 프로젝트가 "Assignee 필수" 정책이면 호출 1에서 거절될 수 있음에 주의.
3. 스프린트 배정을 선택한 경우 Step 2에서 조회한 스프린트 ID 사용
4. 다음 세 단계로 호출한다: ① `jira_create_issue`로 빈 티켓 생성 → ② `jira_update_issue`로 커스텀 필드·parent·timetracking 설정 → ③ `jira_update_issue`로 description만 덮어쓰기.

   > **이 순서가 필요한 이유**: Jira 자동화 룰이 `parent` 설정 시 description을 빈 템플릿으로 덮어쓴다. description을 마지막(③)에 단독으로 설정하면 자동화 룰 이후에 적용되어 올바른 내용이 유지된다.

   **호출 1 — `jira_create_issue` (빈 티켓 생성)**:
   - `project_key`: Step 0에서 로드한 `{PROJECT_KEY}`
   - `issue_type`: 1번에서 확보한 `ISSUE_TYPE_MAP[<Step 1 선택>]`을 그대로 사용한다. 영문 리터럴(`Story`, `Task` 등)을 직접 쓰지 않는다.
   - `summary`: 확정된 요약
   - `description`: **설정하지 않는다** (빈 티켓으로 생성)
   - `priority`: 선택된 우선순위. MCP의 `jira_create_issue`는 `priority`를 직접 인자로 받지 않을 수 있으므로 `additional_fields`에 `{"priority": {"name": "{우선순위}"}}` 형태로 포함한다.
   - `assignee`: 2번에서 확보한 `{ASSIGNEE}` — **`{ASSIGNEE} = null`이면 이 키 자체를 payload에서 생략한다.**
   - `parent` (**Sub-task 한정**): `additional_fields.parent`에 부모 이슈 키(`{PROJECT_KEY}-NNN` 문자열)를 포함한다. PBI 흐름(Story/Task/Bug/Spike)에서는 호출 1에 parent를 넣지 않는다.

   > **Sub-task 주의**: MCP의 `jira_create_issue`는 Sub-task 생성 시 `parent`를 **필수**로 요구한다. 따라서 Sub-task는 호출 1 payload의 `additional_fields`에 parent를 포함해야 한다(이전 가이드는 호출 2 단독 설정을 강제했으나, 회귀에서 호출 1 parent 필수 + 호출 2 customfield 정상 업데이트가 검증돼 정정). 호출 1에서 parent를 설정해 자동화 룰이 발동하더라도, 호출 2에서 AC·증거·SP를 다시 채우면 정상 반영된다. **호출 2에서는 Sub-task의 parent를 다시 설정하지 않는다.** PBI 흐름은 이전과 동일하게 호출 2에서만 parent를 설정한다.

   **호출 2 — `jira_update_issue` (커스텀 필드 및 추가 필드 설정)**:
   - `additional_fields`:
     ```json
     {
       "{FIELD_SP}": 3,
       "{FIELD_AC}": "1. AC 항목 1\n2. AC 항목 2\n3. AC 항목 3",
       "{FIELD_EV}": "Confluence 문서 링크",
       "parent": "{PROJECT_KEY}-NNN",
       "timetracking": {"originalEstimate": "2d"}
     }
     ```
   - `{FIELD_SP}`: 스토리 포인트 (PBI만, Sub-task는 생략. FIELD_SP가 (none)이면 이 키 자체를 생략)
   - `{FIELD_AC}`: AC/완료조건 항목을 `\n` 구분 번호 목록으로 작성 (FIELD_AC가 (none)이면 생략)
   - `{FIELD_EV}`: 증거 텍스트 (없으면 생략. FIELD_EV가 (none)이면 이 키 자체를 생략)
   - `parent`: **PBI 흐름에서 선택된 상위항목 key.** Sub-task는 호출 1에서 이미 설정됐으므로 이 키를 생략한다. PBI에서 "상위항목 없음"이면 키 자체 생략.
   - `timetracking.originalEstimate`: 입력한 경우만 포함

   **호출 3 — `jira_update_issue` (description 단독 설정)** (자동화 룰 덮어쓰기용):
   - `fields`:
     ```json
     {
       "description": "## 목적\n{확정된 목적 텍스트}\n\n## 범위\n**포함**\n- ...\n\n**제외**\n- ..."
     }
     ```
   - **PBI 흐름**: Step 2에서 확정된 목적 텍스트 + 범위(포함/제외)를 Markdown으로 작성한다. AC와 증거는 절대 포함하지 않는다. Step 2 확정 내용을 그대로 사용하며 임의로 생략하거나 재작성하지 않는다.
   - **Sub-task 흐름**: Step 2의 "설명" 항목이 입력된 경우에만 호출 3을 실행하며, description은 입력된 설명 텍스트만 포함한다(PBI의 목적/범위 Markdown 구조를 강제하지 않으며, 부모 이슈의 description을 옮기지 않는다). "설명"이 비어 있으면 호출 3을 스킵한다.

   > **참고**: `duedate: null` 설정은 Jira 프로젝트 자동화 룰이 API 호출 이후에 재설정하므로 효과 없음. 기한 자동 설정을 막으려면 Jira 프로젝트 설정 > 자동화에서 룰을 직접 비활성화해야 한다.

4. 스프린트 배정 선택 시 `mcp__mcp-atlassian__jira_add_issues_to_sprint` 추가 호출
5. 생성된 이슈의 URL은 Jira API 응답의 `self` 또는 `key` 필드를 이용해 구성한다. (예: MCP 서버 설정의 `JIRA_URL` + `/browse/` + `key`)


## Step 7 — Slack DM 알림 전송

> SLACK_ID가 `(none)`인 경우 이 Step 전체를 스킵한다.

Jira 이슈 생성 성공 후 Step 0에서 로드한 `SLACK_ID`를 DM 채널로 사용하여 알림을 전송한다.

> **실패 처리**: Slack 전송이 실패해도 Jira 이슈 생성은 이미 완료된 상태다. `slack_post_message` 호출이 실패하면 Step 8 결과 출력에 `⚠️ Slack DM 전송 실패: {에러 요약}` 한 줄을 추가하고 워크플로우를 정상 종료한다. 재시도하거나 Jira 이슈를 롤백하지 않는다.

`slack_post_message`로 DM 채널(`SLACK_ID`)에 전송:

```
새 Jira 티켓이 생성되었습니다 🎟️

*[{이슈키}] {요약}*
• 타입: {타입}  |  우선순위: {우선순위}  |  스토리 포인트: {점수}
• 스프린트: {스프린트명}
• 링크: [Jira API 응답에서 구성한 URL]
```

> **참고**: 새 알림 채널 추가 시 config의 "알림" 섹션에 항목 추가 + 이 Step에 분기를 추가한다.


## Step 8 — 결과 출력

```
✅ Jira 이슈가 생성되었습니다.
이슈 키: {이슈키}
요약: {요약}
URL: [Jira API 응답에서 구성한 URL]

📨 Slack DM으로 알림을 전송했습니다.        ← Slack 전송 성공 시
⚠️ Slack DM 전송 실패: {에러 요약}          ← Slack 활성이지만 전송 실패 시
🔕 Slack 알림이 비활성 상태입니다.            ← SLACK_ID=(none)일 때
                                              (위 세 줄 중 정확히 하나만 출력)

👤 Assignee 자동 식별 실패 — unassigned로 생성됐습니다.   ← Step 6 2번에서 `{ASSIGNEE} = null`이었던 경우만 출력
```

8pt PBI 생성 시:
```
⚠️ 8pt PBI가 생성되었습니다. 스프린트 계획 시 더 작은 PBI로 분할을 검토해 주세요.
```


## 가이드라인

- 사용자가 제공한 작업·목적을 최대한 반영하여 필드를 초안 생성한다. 사용자가 수정할 필요를 최소화하는 것이 목표다.
- AC는 "예/아니오"로 판정 가능한지 항상 검토한다. 애매한 표현은 구체화를 권고한다.
- 스토리 포인트는 반드시 모든 필드 수집 후 마지막에 판단한다.
- 티켓 내용은 간결하게 유지한다. 팀원이 5분 내에 파악할 수 있는 수준이 적절하다.
- Slack 알림은 SLACK_ID가 `(none)`이 아닌 경우 생성 성공 후 자동으로 전송하며, 사용자에게 별도 확인을 요청하지 않는다.
- `description`에는 목적과 범위만 작성한다. AC·증거를 description에 넣으면 Jira가 잘못 파싱한다. 목적과 범위는 Step 2에서 사용자가 확인한 내용을 반드시 사용한다. 누락하거나 빈 값으로 호출하지 않는다.
- 이슈 URL은 MCP 서버에 설정된 Jira 도메인을 기준으로 구성한다. 절대 URL을 코드에 하드코딩하지 않는다.
