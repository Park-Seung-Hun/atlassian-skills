## Step 0 — 공통 설정

> **실행 환경 전제**
> - `mcp-atlassian`, `notion`, `slack` MCP 서버가 등록돼 있어야 한다(스킬에 따라 사용하는 서버는 일부만 해당).
> - 본문에서 `mcp__<server>__<tool>` 풀네임으로 표기된 도구는 Claude Code/Codex 양 환경에서 동일하게 모델에 노출된다.
> - 본문에 "AskUserQuestion"이라고 적힌 부분은 구조화 질문 도구를 의미한다. 해당 도구가 없는 환경(예: Codex)에서는 동일 의미의 자연어 질문으로 대체하되, 선택지/검증 조건은 본문에 명시된 그대로 유지한다.
> - 설정 파일 경로 `{{CONFIG_PATH}}`는 두 환경이 워크스페이스 루트 기준으로 공유한다.

### 커스텀 필드 설정

커스텀 필드 ID는 Step 0에서 `{{CONFIG_PATH}}`를 로드하거나 `jira_search_fields`로 자동 조회하여 결정한다.
이하 지시에서 `{FIELD_SP}` / `{FIELD_AC}` / `{FIELD_EV}`는 Step 0에서 확정된 필드 키를 의미한다.
`(none)`으로 설정된 슬롯은 해당 수집 Step 전체를 스킵한다.

> **중요**: `description` 필드에 AC/증거를 포함하면 Jira가 자동으로 파싱하여 섹션이 잘리거나 커스텀 필드에 잘못 매핑된다.
> description = 목적 + 범위만 작성하고, AC와 증거는 반드시 커스텀 필드로 분리하여 전달한다.

### 0-0. config 로드

`{{CONFIG_PATH}}` 파일을 읽어 아래 값을 로드한다.

- **PROJECT_KEY**: `프로젝트 키` 항목
- **BOARD_ID**: `보드 ID` 항목
- **FIELD_SP**: `스토리 포인트 필드` 항목 (`(none)`이면 스토리 포인트 수집 Step 스킵)
- **FIELD_AC**: `AC 필드` 항목 (`(none)`이면 AC 수집 Step 스킵)
- **FIELD_EV**: `증거 필드` 항목 (`(none)`이면 증거 수집 Step 스킵)
- **SLACK_ID**: `Slack 사용자 ID` 항목 (`(none)`이면 Slack 알림 Step 스킵)

### 0-1. config 미설정 시 인라인 수집

config 파일이 없거나 PROJECT_KEY가 `YOUR_`로 시작하는 경우:

1. AskUserQuestion: "Jira 프로젝트 키를 입력하세요. (예: TCI, MYPROJ)"
2. `jira_get_agile_boards`를 호출하여 해당 프로젝트의 보드 목록을 조회한다:
   - **결과 1개**: 자동 확정. "보드 `{보드명}`을 사용합니다." 안내 후 BOARD_ID 저장.
   - **결과 2~4개**: AskUserQuestion으로 보드 선택. 선택된 보드의 ID를 BOARD_ID로 저장.
   - **결과 5개 이상**: AskUserQuestion으로 "보드 이름 일부를 입력하세요."를 수집하고, 포함하는 보드만 필터 후 위 분기를 재적용.
   - **결과 0개**: "해당 프로젝트의 보드를 찾을 수 없습니다. 프로젝트 키를 확인하세요." 출력 후 중단.
3. `jira_search_fields`를 호출하여 `customfield_`로 시작하는 필드 목록을 조회하고, 3개 슬롯(FIELD_SP / FIELD_AC / FIELD_EV)을 순차 매핑한다.

**슬롯별 키워드 매칭 기준 (대소문자 무시)**

| 슬롯 | 키워드 |
|------|--------|
| FIELD_SP (스토리 포인트) | story point, storypoint, 스토리 포인트, 스토리포인트, SP |
| FIELD_AC (AC/완료조건) | acceptance, acceptance criteria, AC, 완료 조건, 완료조건, 인수 기준, 인수기준 |
| FIELD_EV (증거) | evidence, proof, 증거, 근거 |

각 슬롯마다:
- **매칭 1개**: "스토리 포인트 필드로 `{필드명} ({필드 키})`을 사용하시겠습니까?" 확인 후 사용.
- **매칭 0개 / 2개 이상**: AskUserQuestion 선택 UI 제시 (상위 3개 후보 + `사용 안 함` + `직접 입력`).
  - `사용 안 함` 선택: 해당 슬롯을 `(none)`으로 설정 → 관련 수집 Step 스킵.
  - `직접 입력` 선택: AskUserQuestion으로 필드 키 직접 입력.

config 로드 모드에서는 보드·필드 재조회 없이 로드된 값을 그대로 사용한다.

> **인라인 모드 SLACK_ID 처리**: config 미설정 인라인 fallback에서는 `SLACK_ID = (none)`으로 고정한다. Slack 알림은 `/jira-create-setup`을 통해서만 활성화된다.

### 0-2. $ARGUMENTS 우선 적용

`$ARGUMENTS`에 알파벳 2~10자로 이루어진 단어가 포함되어 있고 작업 설명이 아닌 프로젝트 키로 판단되는 경우, config의 PROJECT_KEY보다 우선 적용한다.

**오버라이드 시 보드/필드 재탐색 (필수)**: PROJECT_KEY를 오버라이드하는 경우, 기존 config의 BOARD_ID·FIELD_SP·FIELD_AC·FIELD_EV는 더 이상 유효하지 않다. 다음과 같이 처리한다:

1. "프로젝트 키 `{X}`로 1회성 생성합니다. 보드/필드를 재탐색합니다." 안내를 출력.
2. BOARD_ID·FIELD_SP·FIELD_AC·FIELD_EV를 무효화하고, Step 0-1의 인라인 수집 경로(`jira_get_agile_boards` + `jira_search_fields`)를 강제 실행한다.
3. SLACK_ID는 개인 알림이므로 그대로 유지한다.
4. 재탐색된 값은 `{{CONFIG_PATH}}`에 저장하지 않는다 (1회성).
