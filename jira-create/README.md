# jira-create 스킬

Jira 이슈를 AI 에이전트 대화 형식으로 생성하는 스킬이다. Claude Code와 Codex 양 환경을 지원한다.
Story (스토리) / Task (작업) / Bug (버그) / Spike (스파이크) / Sub-task (하위 작업)를 지원하며, 생성 후 Slack DM으로 알림을 전송한다.

---

## 목차

- [포함 파일](#포함-파일)
- [플로우](#플로우)
- [사전 준비](#사전-준비)
- [설치](#설치)
- [워크플로우](#워크플로우)
  - [프로젝트 설정](#프로젝트-설정)
  - [이슈 생성](#이슈-생성)
- [특정 이슈만 다른 프로젝트로 생성할 때](#특정-이슈만-다른-프로젝트로-생성할-때)
- [고도화 로드맵](#고도화-로드맵)

---

## 포함 파일

| 파일 | 커맨드 | 용도 |
|------|--------|------|
| `jira-create-setup.md` | `/jira-create-setup` | 프로젝트 설정 (초기 및 재설정) |
| `jira-create.md` | `/jira-create` | 이슈 생성 |

---

## 플로우

### /jira-create-setup

```mermaid
flowchart TD
    A(["/jira-create-setup"]) --> B{config.md 존재?}
    B -- 없음·YOUR_ 포함 --> C[프로젝트 키 수집]
    B -- 유효한 설정 --> D{재설정?}
    D -- 아니오 --> Z([종료])
    D -- 예 --> C
    C --> E[보드 목록 조회]
    E --> F{보드 수}
    F -- 0개 --> ZE([오류 종료])
    F -- 1개 --> G[자동 확정]
    F -- 2~4개 --> H[목록에서 선택]
    F -- 5개 이상 --> I[이름 필터 후 재선택]
    G & H & I --> J["커스텀 필드 매핑 (SP / AC / EV)
    슬롯별: 1개 → 자동 확정
    0개·복수 → 후보 선택 또는 직접 입력"]
    J --> K{Slack 사용?}
    K -- 예 --> L[표시 이름으로 Slack ID 조회]
    K -- 아니오 --> M["Slack ID = (none)"]
    L & M --> N[/config.md 저장\]
```

### /jira-create

```mermaid
flowchart TD
    A(["/jira-create"]) --> B{config.md?}
    B -- 없음·YOUR_ --> C["인라인 수집
    프로젝트 키·보드·필드
    Slack ID=(none) 고정"]
    B -- 유효 --> D{"$ARGUMENTS에
    프로젝트 키?"}
    D -- 예: 오버라이드 --> E[보드·필드 재탐색\nSlack ID 유지]
    D -- 아니오 --> F[설정 로드]
    C & E & F --> G["작업·목적 파악
    ($ARGUMENTS 또는 질문)"]
    G --> H[이슈 유형 추론 → 확인]
    H --> I{PBI / Sub-task}
    I -- PBI --> J["요약 / 에픽 연결
    범위(포함·제외)
    우선순위 / 추정치 / 스프린트"]
    I -- Sub-task --> K["부모 키 / 요약
    범위 / 추정치"]
    J & K --> L{AC 필드 설정됨?}
    L -- 예 --> M[AC 수집]
    L -- 아니오 --> N{증거 필드 설정됨?}
    M --> N
    N -- 예 --> O[증거 수집]
    N -- 아니오 --> P{"SP 필드 설정됨?
    PBI만"}
    O --> P
    P -- 예 --> Q["SP 추천·확정
    8pt → 분할 경고"]
    P -- 아니오·Sub-task --> R[콘텐츠 길이 검증]
    Q --> R
    R --> S[미리보기 확인]
    S --> T["이슈 생성
    기본 필드 → 커스텀 필드 순으로 2회 호출"]
    T --> U{Slack ID 설정됨?}
    U -- 아니오 --> V([결과 출력])
    U -- 예 --> W[Slack DM 전송]
    W -- 성공 --> V
    W -- 실패 --> X["경고 메시지 포함"]
    X --> V
```

---

## 사전 준비

### MCP 서버

아래 2개 MCP 서버가 각 환경에 등록되어 있어야 한다.

- `mcp-atlassian` (`uvx mcp-atlassian`) -- `JIRA_URL`, `JIRA_USERNAME`, `JIRA_API_TOKEN`
- `slack` (`npx @anthropic-ai/mcp-server-slack`) -- `SLACK_BOT_TOKEN`, `SLACK_TEAM_ID`

Slack Bot 필요 권한: `users:read`, `im:write`, `chat:write`

| 환경 | MCP 설정 위치 |
|------|-------------|
| Claude Code | `~/.claude/settings.json` |
| Codex | `~/.codex/config.toml` |

---

## 설치

`atlassian-skills` 저장소 루트에서 빌드 스크립트를 실행하면 각 환경에 자동 배포된다.

```bash
# 양 환경 동시 배포
bash scripts/build-skills.sh

# 특정 환경만
bash scripts/build-skills.sh --target claude
bash scripts/build-skills.sh --target codex

# 프로젝트 scope 배포 (테스트용)
bash scripts/build-skills.sh --scope project --project-dir <path>
```

| 환경 | 배포 경로 |
|------|---------|
| Claude Code | `~/.claude/commands/jira-create.md`, `jira-create-setup.md` |
| Codex | `~/.agents/skills/jira-create/`, `~/.agents/skills/jira-create-setup/` |

스킬은 환경별 설정 파일을 읽으므로 Jira 프로젝트가 다른 경우 각 프로젝트 디렉토리에서 `/jira-create-setup`으로 각각 설정한다.

> 같은 config 파일은 `sprint/` 스킬 묶음(`/sprint-bootstrap`, `/sprint-sync`, `/sprint-close`)도 공유한다. Notion 동기화를 함께 쓰려면 `/jira-create-setup` 다음에 `/sprint-setup`을 실행해 `## Notion` 섹션을 채워라.

---

## 워크플로우

### 프로젝트 설정

```
/jira-create-setup [선택: 프로젝트 키]
예) /jira-create-setup TCI
```

에이전트가 순서대로 진행한다:

1. **기존 설정 확인** -- 환경에 맞는 설정 파일이 있으면 재설정 여부 확인
2. **프로젝트 키** -- `$ARGUMENTS`에 없으면 직접 입력 요청
3. **보드 탐색** -- `jira_get_agile_boards`로 보드 목록 조회 후 선택
4. **커스텀 필드 탐색** -- `jira_search_fields`로 스토리 포인트 / AC / 증거 필드 자동 매핑
5. **Slack 알림 설정** -- 사용 여부 확인 후 사용 시 표시 이름으로 ID 자동 조회
6. **설정 파일 저장** -- Claude: `~/.claude/sprint-workflow-config.md`, Codex: `~/.agents/sprint-workflow-config.md`

설정 결과 예시:
```
## Jira
프로젝트 키: TCI
보드 ID: 1092
스토리 포인트 필드: customfield_10016
AC 필드: customfield_11576
증거 필드: (none)

## 알림
Slack 사용자 ID: U12345678   # (none)이면 Slack 알림 비활성
```

> 설정 파일(`sprint-workflow-config.md`)은 개인 정보를 포함한다. **절대 git에 커밋하지 말 것.**
> `.gitignore`에 해당 파일 경로를 추가하라.

기존 설정이 있으면 재설정 여부를 확인한 뒤 덮어쓴다. 프로젝트가 바뀌거나 필드 ID가 변경된 경우에도 동일하게 실행하면 된다.

---

### 이슈 생성

```
/jira-create [선택: 자유 형식 작업 설명]
예) /jira-create 인증 토큰 갱신 API 만들기, 만료 후 재로그인 불편 해소를 위해
```

에이전트가 단계별로 필드를 수집한다:

| Step | 수집 항목 |
|------|----------|
| 0 | config.md 로드 (프로젝트 키, 보드 ID, 커스텀 필드) |
| 1 | 이슈 유형 (Story / Task / Bug / Spike / Sub-task 이중 언어 선택) |
| 2 | 요약 / Epic 연결 / 스프린트 배정 / 부모 키(Sub-task) |
| 3 | 스토리 포인트 추천 및 확정 |
| 4 | Description 작성 |
| 5 | 미리보기 확인 |
| 6 | 이슈 생성 (`jira_create_issue` + `jira_update_issue`) |
| 7 | Slack DM 알림 |
| 8 | 결과 출력 |

#### config 미설정 시 동작

설정 파일(`sprint-workflow-config.md`)이 없거나 값이 `YOUR_`로 시작하면, `/jira-create-setup` 없이도 Step 0에서 인라인으로 설정을 수집한다. 단, 수집한 값은 config.md에 저장되지 않으므로 매번 수집된다. 지속 사용 시 `/jira-create-setup`을 먼저 실행하는 것을 권장한다.

---

## 특정 이슈만 다른 프로젝트로 생성할 때

config를 바꾸지 않고 한 번만 다른 프로젝트 키를 사용하려면:

```
/jira-create MYPROJ
```

`$ARGUMENTS`의 프로젝트 키가 config의 PROJECT_KEY보다 우선 적용된다.

---

## 고도화 로드맵

현재 스킬의 확장 방향을 정리한다. 각 기능은 독립적으로 구현 가능하되, 조합 시 시너지가 발생한다.

### 1. 일괄 생성 (Batch Creation)

**무엇을**: 여러 이슈를 한 플로우에서 정의하고 일괄 생성한다.

**왜**: 스프린트 계획 시 5~10개 이슈를 연속 생성하는 케이스가 빈번하다. 현재는 이슈당 8+ 턴의 대화가 필요해 비효율적이다.

**핵심 설계**:
- 마크다운 리스트/테이블로 여러 이슈를 한 번에 정의 (예: `- [Story] 로그인 페이지에 소셜 로그인 버튼 추가`)
- 일괄 파싱 후 전체 미리보기 테이블을 출력하고, 개별 수정을 거쳐 한 번에 생성
- Epic 세트 생성: Epic 1개 + 하위 PBI N개를 한 플로우로 처리 (Epic 생성 후 자동 parent 연결)
- `jira_batch_create_issues` MCP 도구 활용으로 API 호출 최소화
- 부분 실패 처리: 성공 건 유지 + 실패 건만 원인 리포트 + 재시도 옵션

**활용할 MCP 도구**: `jira_batch_create_issues`, `jira_update_issue`, `jira_link_to_epic`

### 2. 이슈 연결 (Issue Linking)

**무엇을**: 이슈 생성 시 다른 이슈와의 관계(blocks, relates to, duplicates 등)를 설정한다.

**왜**: 현재는 parent-child(Epic -> PBI, PBI -> Sub-task)만 지원한다. 실무에서는 "A가 B를 block한다", "C는 D와 관련있다" 같은 수평적 관계 설정이 자주 필요하다.

**핵심 설계**:
- 생성 플로우 마지막에 선택적 "연결할 이슈가 있나요?" 단계 추가
- `jira_get_link_types`로 프로젝트에서 사용 가능한 링크 타입 조회 후 선택지 제공
- `jira_create_issue_link`로 생성 직후 링크 설정
- 요약(summary) 기반 `jira_search`로 유사 이슈 자동 제안 -- 중복 생성 방지 + 자연스러운 링크 유도
- 배치 생성과 연동: 이슈 간 관계를 사전 선언 (예: "A blocks B") 후 생성 완료 시 자동 링크

**활용할 MCP 도구**: `jira_get_link_types`, `jira_create_issue_link`, `jira_search`

### 3. 템플릿 (Templates)

**무엇을**: 자주 생성하는 이슈 유형에 대한 프리셋을 정의하고, 퀵 모드로 빠르게 생성한다.

**왜**: Bug 리포트, Spike, 특정 도메인의 Task 등 반복적 이슈 패턴이 있다. 매번 동일한 AC/범위/증거 형태를 수집하는 건 비효율적이다.

**핵심 설계**:
- config 파일 또는 별도 YAML에 이슈 유형별 프리셋 정의:
  ```yaml
  templates:
    bug-report:
      type: Bug
      priority: High
      ac_template:
        - "재현 경로를 따라갔을 때 에러가 발생하지 않는다"
        - "기존 기능에 회귀가 없다"
      scope_exclude:
        - "근본 원인이 외부 서비스인 경우 워크어라운드만 적용"
    spike:
      type: Spike
      story_points: 3
      ac_template:
        - "기술적 적용 가능성 여부가 결론으로 도출된다"
        - "팀에 공유할 조사 문서가 작성된다"
  ```
- 퀵 모드: `/jira-create --template bug-report`로 호출 시 프리셋 필드 자동 채움, 빈 필드만 질문
- AC 패턴 라이브러리: 자주 쓰는 AC 문구를 재사용 가능한 블록으로 관리
- setup 스킬에 템플릿 CRUD 추가 (생성/수정/삭제/목록)
- 기존 Jira 이슈를 역으로 템플릿화하는 기능도 고려

**저장 위치**: `{{CONFIG_PATH}}`와 같은 디렉토리에 `jira-templates.yml` 또는 config 파일 내 `## Templates` 섹션

### 4. 에러 복구 (Error Recovery)

**무엇을**: 이슈 생성 3단계 호출 체인의 실패를 감지하고 자동 복구한다.

**왜**: 현재 3단계(빈 티켓 생성 -> 커스텀 필드 설정 -> description 설정) 중 2~3단계 실패 시 불완전한 이슈가 남는다. Slack 실패만 graceful 처리되고 나머지는 미처리 상태이다.

**핵심 설계**:
- 단계별 복구 전략:
  - 호출 1 실패 (생성 자체): 재시도 1회 후 실패 시 에러 원인 리포트 후 중단
  - 호출 2 실패 (커스텀 필드): 이슈 존재 상태. 에러 분석 후 필드별 분리 재시도 (예: parent만 문제면 parent 빼고 나머지 먼저)
  - 호출 3 실패 (description): 단순 재시도 (독립적 필드)
- 불완전 이슈 감지: 생성 후 `jira_get_issue`로 실제 저장 필드 검증. 누락 필드 있으면 사용자에게 재시도 제안
- 중복 생성 방지: 생성 직전 동일 요약으로 최근 5분 내 생성된 이슈 `jira_search` 체크 (네트워크 타임아웃 대비)
- 복구 리포트: 최종 결과에 모든 실패/재시도 이력 포함

**활용할 MCP 도구**: `jira_get_issue` (검증용), `jira_search` (중복 체크용), 기존 생성/업데이트 도구

### 기능 간 시너지

| 조합 | 효과 |
|------|------|
| 배치 + 링크 | 여러 이슈를 만들면서 서로 간 의존 관계까지 한 번에 설정 |
| 템플릿 + 배치 | 템플릿 기반으로 여러 이슈를 빠르게 정의. 스프린트 계획 시 반복 입력 최소화 |
| 에러 복구 + 배치 | 배치에서 부분 실패가 더 빈번하므로 복구 전략이 필수 |

### 우선순위 제안

| 순위 | 기능 | 근거 |
|------|------|------|
| 1 | 에러 복구 | 기존 스킬의 안정성을 강화한다. 다른 기능의 기반이 되는 인프라 성격 |
| 2 | 이슈 연결 | 단건 생성 플로우에 자연스럽게 추가 가능하며 변경 범위가 작다 |
| 3 | 템플릿 | 사용 경험 개선. 에러 복구와 이슈 연결이 안정된 후 적용하는 것이 적절 |
| 4 | 일괄 생성 | 가장 큰 변경. 나머지 3개가 안정되면 조합하여 완성 |
