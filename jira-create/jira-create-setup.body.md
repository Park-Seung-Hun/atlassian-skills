
> **실행 환경 전제**
> - `mcp-atlassian`, `notion`, `slack` MCP 서버가 등록돼 있어야 한다(스킬에 따라 사용하는 서버는 일부만 해당).
> - 본문에서 `mcp__<server>__<tool>` 풀네임으로 표기된 도구는 Claude Code/Codex 양 환경에서 동일하게 모델에 노출된다.
> - 본문에 "AskUserQuestion"이라고 적힌 부분은 구조화 질문 도구를 의미한다. 해당 도구가 없는 환경(예: Codex)에서는 동일 의미의 자연어 질문으로 대체하되, 선택지/검증 조건은 본문에 명시된 그대로 유지한다.
> - 설정 파일 경로 `{{CONFIG_PATH}}`는 두 환경이 워크스페이스 루트 기준으로 공유한다.


# Jira Create 초기 설정

jira-create 스킬이 사용하는 `{{CONFIG_PATH}}` 파일을 생성한다.


## Step 1 — 기존 설정 확인

`{{CONFIG_PATH}}` 파일을 Read 도구로 읽는다.

- 파일이 존재하고 `YOUR_`로 시작하는 값이 없으면:
  > "설정이 이미 존재합니다. 재설정하시겠습니까? (예/아니오)"
  - "아니오": 중단하고 현재 설정 내용을 출력
  - "예": 이하 Step 계속 진행
- 파일이 없거나 `YOUR_`로 시작하는 값이 있으면: 이하 Step 계속 진행


## Step 2 — Jira 프로젝트 키 수집

`$ARGUMENTS`에 알파벳 2~10자 형식이 포함되어 있으면 그것을 PROJECT_KEY로 사용한다.
없으면:

> "Jira 프로젝트 키를 입력하세요. (예: TCI, MYPROJ)"


## Step 3 — 보드 탐색

`jira_get_agile_boards`를 PROJECT_KEY로 호출하여 보드 목록을 조회한다.

- **1개**: 자동 확정. 보드명과 ID를 출력하고 사용자에게 확인
- **2~4개**: AskUserQuestion으로 보드 선택
- **5개 이상**: AskUserQuestion으로 보드 이름 일부 입력 → 필터 후 재분기
- **0개**: "보드를 찾을 수 없습니다. 프로젝트 키를 확인하세요." 출력 후 중단

확정된 보드 ID를 BOARD_ID로 저장한다.


## Step 4 — 커스텀 필드 탐색

`jira_search_fields`를 호출하여 `customfield_`로 시작하는 필드 목록을 필터링한다.

아래 3개 슬롯에 대해 순차적으로 키워드 매칭을 수행한다.

| 슬롯 | 키워드 (대소문자 무시) |
|------|----------------------|
| FIELD_SP | story point, storypoint, 스토리 포인트, 스토리포인트, SP |
| FIELD_AC | acceptance, acceptance criteria, AC, 완료 조건, 완료조건, 인수 기준, 인수기준 |
| FIELD_EV | evidence, proof, 증거, 근거 |

각 슬롯마다:
- **매칭 1개**: 필드명과 키를 출력하고 사용자에게 확인 후 사용
- **매칭 0개 / 2개 이상**: AskUserQuestion (상위 3개 후보 + `사용 안 함` + `직접 입력`)
  - `사용 안 함`: 해당 슬롯을 `(none)`으로 설정
  - `직접 입력`: AskUserQuestion으로 필드 키 직접 입력


## Step 5 — Batch 기본값 수집 (선택)

`jira-batch-create` 스킬이 자동 보강 시 사용할 기본값을 수집한다. 미설정 항목은 배치 스킬이 내부 fallback(Medium / PR 링크 / 배포 URL)을 사용한다.

### 5-1. 기본 우선순위

AskUserQuestion:
> "Jira 이슈 생성 시 기본 우선순위를 선택하세요."

- Highest / High / **Medium (추천)** / Low / 설정 안 함

"설정 안 함" 선택 시 DEFAULT_PRIORITY = `(none)`.

### 5-2. 기본 증거 형태 (PBI)

AskUserQuestion:
> "PBI/Sub-task의 기본 증거 형태를 선택하세요."

- **PR 링크 (추천)** / Confluence 문서 링크 / 스크린샷·로그 / 설정 안 함

"설정 안 함" 선택 시 DEFAULT_EVIDENCE = `(none)`.


## Step 6 — Slack 설정

### 6-1. 사용 여부 확인

> "Slack 알림을 사용하시겠습니까? (예/아니오)"

- **아니오**: SLACK_ID = `(none)` 으로 설정하고 6-2를 스킵한다.
- **예**: 이하 6-2 진행.

### 6-2. Slack 사용자 ID 수집

> "Slack 표시 이름(display name)을 입력하세요."

`slack_get_users`로 전체 사용자 목록을 조회한 뒤 일치하는 `id`를 찾는다.

찾지 못하면:
> "Slack 앱 → 본인 프로필 클릭 → '더보기' → '멤버 ID 복사'로 확인할 수 있습니다."

직접 입력 받아 SLACK_ID로 저장한다.


## Step 7 — config.md 저장

`{{CONFIG_PATH}}` 파일을 아래 형식으로 작성한다.
(파일이 이미 존재하면 덮어쓴다)

```
# 개인 설정 (Personal Config)
# ⚠️ 이 파일은 개인 정보를 포함합니다. 절대 git에 커밋하지 마세요.

## Jira
프로젝트 키: {PROJECT_KEY}
보드 ID: {BOARD_ID}
스토리 포인트 필드: {FIELD_SP}
AC 필드: {FIELD_AC}
증거 필드: {FIELD_EV}
기본 우선순위: {DEFAULT_PRIORITY}
기본 증거 형태: {DEFAULT_EVIDENCE}

## 알림
Slack 사용자 ID: {SLACK_ID}   # (none)이면 Slack 알림 비활성

## Notion
스프린트 DB Data Source: YOUR_SPRINT_DB_DATASOURCE_ID
스프린트 플래너 DB Data Source: YOUR_PLANNER_DB_DATASOURCE_ID
동기화 로그 DB Data Source: YOUR_SYNC_LOG_DB_DATASOURCE_ID
업무 템플릿 ID: YOUR_TEMPLATE_PAGE_ID
```

`(none)`으로 설정된 슬롯은 해당 값 그대로 기록한다. Notion 섹션은 이 setup이 채우지 않으며, 추후 `/sprint-setup` 실행 시 채워진다(jira-create 스킬은 Notion 값을 사용하지 않는다).


## Step 8 — 완료 안내

```
✅ 설정 완료!

저장 위치: {{CONFIG_PATH}}

설정 내용:
- 프로젝트 키: {PROJECT_KEY}
- 보드 ID: {BOARD_ID}
- 스토리 포인트 필드: {FIELD_SP}
- AC 필드: {FIELD_AC}
- 증거 필드: {FIELD_EV}
- 기본 우선순위: {DEFAULT_PRIORITY}
- 기본 증거 형태: {DEFAULT_EVIDENCE}
- Slack 알림: {SLACK_ID가 (none)이면 "비활성", 아니면 SLACK_ID 값}

이제 /jira-create 커맨드를 사용할 수 있습니다.

⚠️ {{CONFIG_PATH}} 파일은 git에 커밋하지 마세요.
```
