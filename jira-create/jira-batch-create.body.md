# Jira 이슈 일괄 생성

작업 계획 문서(Spec Kit 등)를 파싱하여 Epic / PBI(Story·Task) / Sub-task를 일괄 생성한다.

**설계 전제**:
- 입력 문서는 등록된 SDD 템플릿 규칙에 부합해야 한다. 매칭되는 템플릿이 없으면 같은 스킬 흐름 안에서 **샘플 기반 템플릿 생성**을 먼저 수행한다.
- 문서에서 추출 가능한 필드(요약·계층·파일 경로·목적)는 그대로 쓰고, 추출 불가한 필드(AC·우선순위·SP·증거·추정치)는 자동 추정·기본값으로 메운다.
- 사용자 개입은 **Step 4 최종 미리보기 1회**만. 문서가 권위 있는 단일 소스라는 원칙을 지킨다.
- 수정이 필요한 경우 미리보기에서 이슈 단위로만 재조정한다.


## Step 1 — 작업 계획 문서 입력 및 파싱

### 1-1. SDD 파일 경로 확보

> **선행 조건**: Step 0-0b 응답을 받은 뒤에만 이 단계를 시작한다. 파일 로드·재입력 프롬프트를 0-0b 확인 질문과 같은 턴에 묶지 않는다. 경로 재입력이 필요하면 **독립 턴의 AskUserQuestion 1회**로 묻고, 설정 수정 분기와 혼재하지 않도록 문구에 다른 선택지를 섞지 않는다.

1. `$ARGUMENTS`에 파일 경로(`.md` 확장자 또는 `/`로 시작)가 있으면 후보로 채택한다.

   > `$ARGUMENTS`는 Step 0-2에서 이미 PROJECT_KEY 감지로 소비됐을 수 있다. 나머지 토큰 중 `.md` 확장자 / `/`로 시작하는 경로만 문서 입력으로 해석한다.

2. 후보가 없으면 AskUserQuestion: "작업 계획 문서 파일 경로를 입력하세요." (자유 입력)
3. 후보 경로를 Read 도구로 로드 시도한다.
   - 성공: 본문 텍스트를 `{SDD_TEXT}`로 보관하고 1-2로 진행.
   - 실패(파일 없음 / 읽기 불가): "'{경로}'를 읽을 수 없습니다. 경로를 다시 입력하세요." 안내 후 2로 돌아가 재입력을 받는다. **경로 유효성이 확보될 때까지 이 단계에서 머문다.** 3회 연속 실패 시 "파일 접근이 계속 실패합니다. 환경을 확인 후 재실행하세요." 출력 후 중단.

### 1-2. 템플릿 매칭 판정

`{{CONFIG_DIR}}/jira-sdd-templates.yml`을 Read 도구로 로드한다.

1. `{SDD_TEXT}`의 첫 H1 헤딩을 추출하여 `{SDD_H1}`로 보관한다.
2. 아래 순서로 매칭 여부를 판정한다.

| 상태 | 조건 | 분기 |
|------|------|------|
| 매칭 있음 | 파일 로드 성공 + `templates:` 키 존재 + 등록된 템플릿 중 `match` 패턴이 `{SDD_H1}`에 포함되는 항목 1건 이상 | 아래 **매칭 안내 출력 강제** 규칙 수행 후 **1-4로 진행** |
| 매칭 없음 | 파일 로드 성공 + 등록 템플릿 중 일치 없음 | **1-3으로 진행** (`{SDD_TEXT}`를 샘플로 신규 템플릿 생성) |
| 파일 없음 | 템플릿 파일 자체 부재 / 비어 있음 / `templates:` 키 없음 | **1-3으로 진행** (신규 템플릿 생성부터 시작) |

**매칭 안내 출력 강제** (매칭 있음 상태일 때 **반드시 수행**):

- 아래 문구를 **그대로 1줄 출력한 뒤** 1-4로 진행한다. 내부 판정만 하고 이 안내를 생략한 채 1-4로 뛰어넘는 것은 **규약 위반**이다.
  ```
  템플릿 `{이름}`과 매칭되었습니다. 해당 규칙으로 파싱합니다.
  ```
- 이 출력이 없으면 사용자는 어느 템플릿이 적용됐는지 알 수 없고 회귀 판단이 불가능하다. 따라서 **1-4 진입 전에 이 한 줄을 반드시 렌더링**한다.

### 1-3. 샘플 기반 신규 템플릿 생성

> **진입 조건**: 1-2에서 매칭 실패. 이미 로드한 `{SDD_TEXT}`를 샘플로 재사용한다. 경로를 다시 묻지 않는다.

1. AskUserQuestion — 2지 선택:
   - **"생성"**: 이 SDD를 샘플로 신규 템플릿을 등록하고, 본 흐름(1-4)으로 이어서 진입한다.
   - **"중단"**: 스킬 즉시 종료. 이슈를 생성하지 않고 config도 변경하지 않는다.
     > Codex 등 AskUserQuestion 미지원 환경에서는 `생성` / `중단` 자연어 명령으로 대체.

2. "생성" 선택 시:

   **1-3-a. 템플릿 이름 지정**

   AskUserQuestion: "새 템플릿 이름을 입력하세요. (예: `spec-kit`, `team-sdd`)"

   검증 조건:
   - 영문 소문자 + 숫자 + 하이픈만 허용 (`[a-z][a-z0-9-]{1,29}`)
   - 2~30자
   - `{{CONFIG_DIR}}/jira-sdd-templates.yml`에 동일 이름 존재 시: "'{이름}'이(가) 이미 존재합니다. 덮어쓰시겠습니까?" — "예" / "아니오"
     - "아니오": 이름 재입력
     - "예": 해당 키 덮어쓰기로 진행

   **1-3-b. 파싱 규칙 자동 생성**

   `{SDD_TEXT}`를 분석하여 아래 구조의 YAML 템플릿 초안을 구성한다.

   ```yaml
   template_name:
     description: "한 줄 설명"
     match: "SDD 식별 문자열"    # SDD 첫 H1에 이 문자열이 포함되면 매칭
     headings:
       epic:
         level: 1
         pattern: "패턴"         # {title} = 캡처 그룹
       story:
         level: 2
         contains: "식별 문자열"
         pattern: "패턴"
       phase:
         level: 2
         issue: false
     tasks:
       subtask:
         marker: "- [ ]"
         tags:
           - pattern: "태그 패턴"  # 예: "[US*]" — Story 하위 Sub-task
             parent: "matched_story"
           - pattern: "태그 패턴"  # 예: "[T*]" — Task 하위 Sub-task
             parent: "matched_task"
       task:
         marker: "- [ ]"
         no_tag: true
         parent: "epic"
     metadata:
       purpose: "마커 문자열"
       goal: "마커 문자열"
       test_hint: "마커 문자열"
       file_path: "패턴"
   ```

   분석 시 주의사항:
   - 헤딩 레벨과 패턴을 정확히 감지 (H1, H2, H3 등)
   - 체크리스트 마커 (`- [ ]`, `- [x]` 등) 감지
   - 태그 패턴 감지 (예: `[US1]`, `[P]` 등 대괄호 내 텍스트)
   - 메타데이터 마커 감지 (Bold + 콜론 패턴: `**목적**:`, `**목표**:` 등)
   - 파일 경로 패턴 감지 (예: `→ \`path\``)
   - 샘플에 없는 메타데이터 필드는 `null`로 명시한다. 생략하지 않는다.

   **1-3-c. 초안 제시 & 확정**

   사용자에게 아래 형식으로 출력한다.

   ```
   ## 파싱 규칙 초안

   **식별 패턴**: `{match 값}`
   **Epic**: H{n} — `{pattern}`
   **Story**: H{n} — "{contains}" 포함 시
   **Phase (이슈 아님)**: H{n} — Story 조건 미충족
   **Sub-task**: 체크리스트 `{tag}` 태그 있음 → 해당 Story 하위
   **Task**: 체크리스트 태그 없음 → Epic 하위

   **메타데이터 추출**:
   - 목적: `{purpose 마커}` 뒤 텍스트 (없으면 "감지 안 됨")
   - 목표: `{goal 마커}` 뒤 텍스트 (없으면 "감지 안 됨")
   - AC 힌트: `{test_hint 마커}` 뒤 텍스트 (없으면 "감지 안 됨")
   - 파일 경로: `{file_path 패턴}` (없으면 "감지 안 됨")
   ```

   AskUserQuestion: "이 규칙으로 저장 / 수정" (2지).
   - "수정": 수정할 항목을 질문하고 반영 후 다시 초안을 재제시. "저장"이 선택될 때까지 반복.

   **1-3-d. 저장**

   `{{CONFIG_DIR}}/jira-sdd-templates.yml`에 해당 키를 추가/덮어쓴다.

   - 파일이 없으면 루트 키를 `templates:`로 하여 새로 생성.
   - 기존 파일이 있으면 **해당 템플릿 키만** 추가/덮어쓰기. 다른 템플릿은 건드리지 않는다.

   저장 후 사용자에게 1줄 안내:
   ```
   ✅ 템플릿 '{이름}'을 저장했습니다. 이 규칙으로 이어서 파싱합니다.
   ```

   그리고 **1-2를 재실행하지 않고 곧바로 1-4로 진행**한다. 방금 저장한 규칙이 매칭 대상이다.

3. "중단" 선택 시: 아무것도 저장하지 않고 스킬을 종료한다.

### 1-4. 파싱

매칭된 템플릿 규칙(1-2에서 확인되었거나 1-3에서 방금 저장된)을 적용하여 `{SDD_TEXT}`를 파싱한다:

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

**번호 매김 규칙 (`#{N}` 결정)**: 파싱한 이슈 트리를 **깊이 우선(depth-first) 순회**하며 1부터 순번을 부여한다. 순서는 `Epic → 첫째 자식 PBI → 그 PBI의 Sub-task들 → 둘째 자식 PBI → 그 PBI의 Sub-task들 → ...` 방식이다. 타입별 그룹화(모든 PBI 다음 모든 Sub-task)는 **금지**한다. 이 규칙은:

- Step 4 (A) 트리 렌더링의 시각적 순서와 번호 순서가 일치하도록 한다.
- Step 4 (C-1) `보기 N`, (C-2) `수정 N` / `수정 N field=value`, (B-1) 전문 블록의 `상위: #M` 참조에 공통 적용된다.
- 세션·모델에 관계없이 동일 SDD에 대해 동일 번호를 부여한다. 사용자가 `수정 7`을 입력했을 때 세션마다 다른 이슈가 지목되는 일이 없도록 한다.


## Step 2 — 필드 자동 보강 (무대화)

문서에서 추출 불가한 필드를 config 기본값·모델 추정으로 **질문 없이** 채운다.

### 2-0. 이슈 타입 맵 확보

Jira 인스턴스 언어가 한국어이면 `Epic`이 아닌 `에픽`만 수용하는 식으로 이슈 타입 이름이 로컬라이즈된다. Phase A/B/C가 공통으로 쓸 **`ISSUE_TYPE_MAP`**을 배치당 1회 구축한다.

**알고리즘**:

1. `jira_search(jql="project = {PROJECT_KEY}", fields="issuetype", limit=50)` 실행.

   - **1단계 (이슈가 1건 이상)**: 응답의 `issues[].issue_type.name`을 고유 집합으로 수집 → 3번으로 진행.
   - **2단계 (issues가 비어 있을 때)**: 아래 후보 이름 리스트로 `jira_batch_create_issues`에 `validate_only=true`로 1회 호출하여 어떤 이름이 검증을 통과하는지 확인한다.

     후보 목록:
     ```
     ["Epic", "에픽", "Story", "스토리", "Task", "작업", "Sub-task", "하위 작업", "Subtask"]
     ```

     호출 형태:
     ```
     jira_batch_create_issues(
       issues=[
         {"project_key": "{PROJECT_KEY}", "issue_type": "Epic",       "summary": "type-probe"},
         {"project_key": "{PROJECT_KEY}", "issue_type": "에픽",       "summary": "type-probe"},
         {"project_key": "{PROJECT_KEY}", "issue_type": "Story",      "summary": "type-probe"},
         {"project_key": "{PROJECT_KEY}", "issue_type": "스토리",     "summary": "type-probe"},
         {"project_key": "{PROJECT_KEY}", "issue_type": "Task",       "summary": "type-probe"},
         {"project_key": "{PROJECT_KEY}", "issue_type": "작업",       "summary": "type-probe"},
         {"project_key": "{PROJECT_KEY}", "issue_type": "Sub-task",   "summary": "type-probe"},
         {"project_key": "{PROJECT_KEY}", "issue_type": "하위 작업",  "summary": "type-probe"},
         {"project_key": "{PROJECT_KEY}", "issue_type": "Subtask",    "summary": "type-probe"}
       ],
       validate_only=true
     )
     ```

     > `validate_only=true`이므로 실제 이슈는 생성되지 않는다. summary "type-probe"는 정리 불필요.

     응답에서 에러 없이 검증 통과한 후보 이름만 수집 → 이 집합을 고유 집합으로 사용해 3번으로 진행.

     probe 호출이 전체 거절되거나 집합이 비어 있으면 4번의 에러 메시지를 출력하고 중단한다.

2. (위 1단계 또는 2단계에서 확보한 집합으로) 표준 키 → 실제 인스턴스 이름 매핑:

   ```
   ISSUE_TYPE_MAP = {
     "Epic":     <수집 집합 중 "에픽" 우선, 없으면 "Epic">,
     "Story":    <"스토리" 우선, 없으면 "Story">,
     "Task":     <"작업" 우선, 없으면 "Task">,
     "Sub-task": <"하위 작업" 우선, 없으면 "Sub-task" 또는 "Subtask">,
     "Spike":    <"스파이크" | "Spike">  # 없으면 null
   }
   ```

   > 한국어 이름을 우선하는 이유: 사내 Jira 인스턴스 기본값이 한국어 로컬라이즈.

3. 필수 타입(Epic / Story / Task / Sub-task) 중 매핑 실패가 있으면:
   > "프로젝트 {PROJECT_KEY}에서 {표준 키} 이슈 타입을 찾을 수 없습니다. 프로젝트의 이슈 타입 설정을 확인하세요."
   출력 후 중단.

4. Spike는 옵셔널 — 없으면 `null`로 두고, SDD에 Spike가 있을 때만 중단한다.

**재사용**: Phase A/B/C의 `issue_type` 필드는 항상 `ISSUE_TYPE_MAP[<표준 키>]`를 참조한다. 본문에서 `"Epic"`, `"Story"`, `"Task"`, `"Subtask"` 같은 영문 리터럴을 직접 쓰지 않는다.

### 2-1. assignee 식별자 획득

1. `jira_search(jql="assignee = currentUser()", limit=1, fields="assignee")` 실행.
2. 응답의 `issues[0].assignee` 객체에서 아래 우선순위로 식별자 1개를 확보하여 `{ASSIGNEE}` 변수에 저장:
   - `id` (있으면 우선)
   - `email`
   - `display_name`
3. `issues`가 비어있거나 세 필드가 모두 부재하면 **`{ASSIGNEE} = null`로 설정**하고 아래 안내를 1줄 출력한 뒤 진행한다(중단하지 않는다):
   ```
   ⚠️ 현재 사용자 assignee를 자동 식별할 수 없습니다. 모든 이슈를 unassigned로 생성합니다.
   ```

`{ASSIGNEE}`는 Phase A/B/C 전체에서 재사용한다 (1회만 조회). MCP의 `jira_create_issue` / `jira_batch_create_issues`는 assignee 필드에 `id`, `email`, `display_name` 중 어느 것이든 수용하므로 식별자 종류는 무관하다.

> **`{ASSIGNEE} = null`인 경우**: Phase A/B/C의 모든 payload에서 **`assignee` 키 자체를 생략**한다. `null` 값을 그대로 전달하지 않는다. 본인이 담당자인 이슈가 1건도 없는 환경(신규 프로젝트 등)에서도 차단 없이 unassigned fallback으로 진행하기 위함이다. Step 7 결과 리포트에서 fallback 발동 여부를 1줄로 보고한다.
>
> **주의**: Jira 프로젝트가 "Assignee 필수" 정책으로 설정돼 있으면 unassigned 생성이 Jira 검증 단계에서 거절될 수 있다. Phase B 호출 1(`validate_only`)에서 해당 오류가 잡히면 사용자에게 표로 리포트되며, 사용자가 "전체 중단" 후 프로젝트 정책을 조정하거나 본인을 담당 이슈가 있는 사용자로 만들고 재실행한다.

> `jira_get_user_profile`의 `user_identifier`가 JQL 함수형 `currentUser()`를 지원하지 않고, search fallback의 assignee 객체에도 `id`가 없을 수 있어 `id` 강제 획득 경로는 사용하지 않는다.

### 2-2. 우선순위

이슈별 자동 추론. hub 본문 "[필수] 우선순위 추론 규칙" 절을 그대로 적용한다. 폴백 체인:
1. 문서의 우선순위 힌트 — task 내 `[US?]` 라벨 + 부모 Phase 헤더의 `(Priority: P1/P2/P3)` 또는 동등 표기를 매핑(P1=High / P2=Medium / P3=Low). 본문 내 `(Priority: P?)` 직접 표기도 동일 매핑.
2. (1) 미명시 → 부모 PBI 또는 epic의 우선순위를 상속.
3. (2) 미명시 → `Medium` fallback.

사용자가 Step 4 "수정 N field=value"에서 명시 지정한 값은 위 추론 결과를 덮어쓴다.

### 2-3. 스프린트

`jira_get_sprints_from_board({BOARD_ID})` 호출.
- 활성 스프린트 1개 이상: 가장 최근 활성 스프린트 자동 선택.
- 활성 스프린트 없음: 백로그로 생성 (스프린트 배정 스킵).

### 2-4. 증거 형태

이슈별 자동 추론. hub 본문 "[필수] 증거 형태 추론 규칙" 절을 그대로 적용한다.

- **Epic**: `배포 URL` / `릴리즈 노트` / `완료 보고서` 등 비즈니스 산출물 (Jira 작성 규칙 3.4). 미상이면 `배포 URL` fallback.
- **PBI / Sub-task**: hub 본문의 신호 매칭 표(`*Test.java`/`*IT.java` → PR 링크, `*.md` → Confluence 링크, `*.html` → 스크린샷·로그, 회귀·비교 → 비교표·로그, 모호 → `(none)`)를 적용. Sub-task는 부모 PBI에서 증명 가능하면 `(none)`으로 둘 수 있다(DoD 5.4).

사용자가 Step 4 "수정 N field=value"에서 명시 지정한 값은 위 추론 결과를 덮어쓴다.

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

각 필드를 `{ value, origin }` 구조로 내부 보관한다 (예: `summary: { value: "...", origin: "doc" }`, `ac: [{ value: "...", origin: "auto" }, ...]`). 이 메타는 **Step 4 터미널 렌더링 전용**이며, Step 5 Jira payload에는 포함하지 않는다 (Step 5-0에서 strip).

origin 값:
- `doc`: 문서에서 그대로 추출 (요약·파일 경로·목적 원문 등)
- `auto`: 자동 생성·보강 (AC 전체·"제외" 섹션·SP·우선순위 fallback 등)
- `user`: Step 4 수정 플로우에서 사용자가 확정 (수정 시에만 부여)

Step 3~4는 `value`로 렌더·검증하고, origin은 (B) 블록 마커 매핑에 사용된다.


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

구조: (A) 계층 요약 트리 → (B) 이슈별 전문 블록 또는 자동 생성 전략 요약 → (C) 확인 질문.

### (A) 계층 요약 트리

> 계층 구조와 핵심 속성을 훑어보기 위한 요약. 전체 요약문과 본문은 (B-1) 전문 블록에서 확인한다.
> **번호**: `#{N}`은 Step 1-4의 **깊이 우선 순회 번호**. 트리의 시각적 순서와 번호 순서가 일치하며 세션·모델에 무관하게 고정된다.

들여쓰기 기반 트리로 출력한다. 타입에 따른 들여쓰기 레벨:

| 타입 | 들여쓰기 |
|------|---------|
| Epic | 0 (좌측 정렬) |
| Story / Task (PBI) | 2 스페이스 |
| Sub-task | 4 스페이스 |

라인 형식:

```
{indent}[{타입한국어}] #{N} {요약_축약} ({priority}{, SP=x}{, 증거={증거값}})
```

- 타입 이름은 **Step 2-0의 `ISSUE_TYPE_MAP[<표준 키>]`** 한국어 값(에픽/스토리/작업/하위 작업)을 그대로 쓴다. 영문 리터럴(`Epic`, `Story` 등) 금지.
- **요약 축약**: 이슈 요약이 40자를 초과하면 **앞 20자 + `…` + 뒤 17자** 형태로 축약한다. 전체 요약은 (B-1)에서 확인 가능.
- **트리에는 origin 마커(🤖/👤)를 출력하지 않는다**: 트리는 구조·규모를 한눈에 훑어보기 위한 요약이며, 필드 단위의 출처(자동/사용자/문서)는 (B-1) 전문 블록과 (B-2) 자동 생성 전략 요약에서만 확인한다. 트리에 마커를 붙이면 이슈마다 auto 필드가 매우 흔한 특성상 대부분 이슈가 🤖로 덮여 구조 요약 기능이 희석되고, 모델별 해석 편차(summary 기준 vs any-field-user 기준)로 UX 일관성도 깨진다. **트리 라인에 `🤖` 또는 `👤` 이모지를 넣는 것은 규약 위반**이다.
- **괄호 속성**: 우선순위는 항상 표기. SP는 값이 있을 때만 `, SP=x`. 증거는 값이 있을 때만 `, 증거={실제값}` (placeholder 기호 `…` 등으로 대체하지 말고 반드시 실제 값을 그대로 넣는다). 세 항목 모두 `(none)`이면 괄호 전체 생략.
- `FIELD_SP` / `FIELD_EV` 슬롯이 **인스턴스 전체 수준에서** `(none)`이면 해당 항목은 트리 전체에서 일관되게 숨긴다.

예시:

```
[에픽] #1 소셜 로그인 통합 (Medium)
  [작업] #2 OAuth2 프로바이더 타입 정의 (Medium, SP=2)
  [스토리] #5 Google 로그인 (High, SP=5, 증거=PR 링크)
    [하위 작업] #8 Google OAuth 콜백 API 구현 (High)
  [스토리] #6 Apple 로그인 (High, SP=5, 증거=PR 링크)
```

- 8pt PBI가 있으면 트리 아래 경고 1줄("⚠️ 8pt PBI가 포함되어 있습니다. 분할을 검토하세요.").

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

> 마커는 터미널 렌더링 전용 (Jira payload에는 포함 X — Step 5-0에서 strip 검증).

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

> **환경 분기**: AskUserQuestion이 가용한 환경(Claude Code)은 아래 선택지를 그대로 표시한다. AskUserQuestion 미지원 환경(Codex 등)은 동일 의미를 갖는 자연어 명령을 사용자에게서 입력받아 분기한다.
>
> | 명령 | 분기 |
> |------|------|
> | `생성` 또는 `이대로 생성` | (C-3) |
> | `취소` | (C-4) |
> | `보기 N` 또는 `이슈 N 보기` | (C-1), 예: `보기 7` |
> | `수정 N` | (C-2), 이후 필드 선택은 동일 흐름 |
> | `수정 N field=value [field=value ...]` | (C-2) 축약형 — 필드 선택·재질문 생략, 곧바로 origin=user로 갱신 |
> | `리스트` 또는 `목록 다시` | (C-5) — (A) 계층 요약 트리만 재출력 후 (C) 재질문 |
>
> 축약형 허용 field 키: `priority`, `sp`, `summary`, `evidence`, `purpose`, `ac`, `scope`. 예: `수정 7 priority=High sp=5`. 수정 불가 필드(parent / 타입 / 파일 경로)는 축약형에서도 거절한다.

AskUserQuestion 선택지는 이슈 수에 따라 달라진다:

- 이슈 **≤ 5개**: "이대로 생성" / "수정" / "취소" (3지)
- 이슈 **> 5개**: "이대로 생성" / "특정 이슈 보기" / "리스트 다시 보기" / "수정" / "취소" (5지)

> `리스트 다시 보기`는 이슈 > 5개에서 (B-2) 전략 요약만 출력되어 개별 이슈가 보이지 않을 때 (A) 계층 요약 트리를 다시 훑어보기 위한 경로다. 이슈 ≤ 5개 구간에선 (A)+(B-1)가 이미 한 화면에 있어 추가 선택지를 노출하지 않는다.

#### (C-1) "특정 이슈 보기" 선택 시

> 진입: AskUserQuestion에서 "특정 이슈 보기" 선택 / Codex에서 `보기 N` 입력.

1. "전문을 볼 이슈 번호를 입력하세요 (예: 7)." 자유 입력 질문.
2. 해당 이슈의 (B-1) 블록만 출력.
3. (C) 재질문. 반복 가능, 아무것도 변경하지 않는다.

#### (C-2) "수정" 선택 시

> 진입: AskUserQuestion에서 "수정" 선택 / Codex에서 `수정 N` 또는 `수정 N field=value ...` 입력.

1. "수정할 이슈 번호를 입력하세요 (예: 2)." 자유 입력 질문.
2. 해당 이슈의 (B-1) 블록을 출력.
3. AskUserQuestion(multiSelect): "수정할 필드를 선택하세요." — 목적 / 범위 / AC / 증거 / 우선순위 / SP / 요약. **축약형으로 진입한 경우 3·4번을 건너뛰고 5번부터 수행.**
4. 선택된 필드마다:
   - **목적·범위·AC·증거**: AskUserQuestion "어떻게 변경할까요?" — 더 구체적으로 / 더 간결하게 / 다른 관점으로 (힌트 입력) / 직접 작성. "다른 관점"은 자유 입력 힌트를 받아 재생성, "직접 작성"은 자유 입력으로 새 값을 받는다.
   - **요약·우선순위·SP**: 직접 입력만.
5. **수정된 필드의 origin을 `user`로 갱신**. (B-1) 전문 블록에서 해당 필드 앞 마커가 🤖 → 👤로 바뀐다. 트리 (A)에는 마커를 노출하지 않는다.
6. (A) 요약 트리 + (이슈 ≤ 5개인 경우에만) 해당 이슈의 (B-1) 블록 재출력 → (C) 재질문. 전체 이슈의 (B) 블록을 다시 출력하지 않는다.
7. 사용자가 "이대로 생성"을 선택할 때까지 반복. **수정 반복이 5회를 초과**하면 "수정이 자주 반복되고 있습니다. 문서를 보강 후 재실행하는 것이 효율적일 수 있습니다." 안내를 1회 출력.

**수정 불가 필드**: 계층 구조(parent), 타입(Epic/Story/Task/Sub-task), 파일 경로. 이건 문서에서 추출한 값이며, 바꾸려면 문서를 수정해 재실행해야 한다. (C-2) 필드 선택지에 노출하지 않는다.

#### (C-3) "이대로 생성" 선택 시

> 사용자가 생성을 확정한 시점에 **hub `0-0a` 지연 실행 서브루틴을 반드시 호출**한다. config 로드 경로(0-0 성공)이고 `customfield_probe_passed` 플래그가 false(또는 미설정)인 경우에만 실제 `jira_search_fields` probe를 수행한다. `0-1` fallback / `0-2` 오버라이드 경로는 호출을 스킵한다 (hub 0-0a 호출 규약 참조).

1. 호출 전 확인: 세션 플래그 `customfield_probe_passed`가 `true`면 즉시 2번으로 진행(재호출 스킵).
2. hub 0-0a 서브루틴 실행.
   - **통과** → 플래그 `customfield_probe_passed = true` 세팅 후 Step 5로 진행.
   - **재지정** (config 또는 세션 필드 맵이 변경됨) → `customfield_probe_passed = true` 세팅 후 **먼저 재확인 질문을 출력**하고, "이어서 생성" 응답을 받은 뒤에만 Step 5로 진행한다. Step 2 산출물(필드 맵)은 그대로 유지하며, 재지정된 슬롯이 `(none)`이 된 경우 해당 슬롯의 payload 키는 5-0 정화 로직에서 자연스럽게 빠진다.
     - AskUserQuestion(단일 선택): "설정이 변경됐습니다 ({변경 슬롯 요약}). 이 설정으로 생성을 이어갈까요?"
       - **이어서 생성** → Step 5 진입.
       - **취소** → 아무것도 생성하지 않고 스킬 종료.
     - 직전 (C-3) "이대로 생성" 응답을 근거로 재확인을 생략하고 바로 Phase A/B/C 호출로 진입하는 것을 금지.
   - **중단** → 아무것도 생성하지 않고 스킬 종료.
3. Step 5 진입.

> **(C-2) 수정 반복 / (C-5) 리스트 다시 보기 이후 (C-3) 재선택**: 동일 세션 내 반복이므로 `customfield_probe_passed`가 이미 `true`면 재 probe하지 않는다. 재지정으로 config가 갱신된 경우에만 플래그가 그대로 유지되어 추가 probe 없이 Step 5로 진입한다.

#### (C-4) "취소" 선택 시: 아무것도 생성하지 않고 종료.

#### (C-5) "리스트 다시 보기" 선택 시

> 진입: AskUserQuestion에서 "리스트 다시 보기" 선택 / Codex에서 `리스트` 또는 `목록 다시` 입력. 이슈 > 5개 구간에서만 활성.

1. (A) 계층 요약 트리를 **그대로 재출력**한다. (B) 블록과 전략 요약은 재출력하지 않는다.
2. 수정된 필드 값(priority / SP / summary 등)이 반영된 **현 시점 상태**를 기준으로 렌더링한다. 트리에 origin 마커는 출력하지 않는다(마커 확인은 (B-1)에서).
3. (C) 재질문. 아무것도 변경하지 않으며 반복 가능.


## Step 5 — Jira 이슈 생성

### 5-0. payload 정화 (필수 선행)

Phase A/B/C payload 조립 전 적용:

1. Step 2-9의 `{ value, origin }`에서 `value`만 추출 (origin 버림).
2. 문자열 필드(description / AC / 증거 / 요약)에서 `🤖` / `👤` 누수 검증. 발견 시 strip 처리하고 내부 카운터에 누적 → Step 7 결과 리포트가 누수 건수를 합산해 1줄로 보고(양식은 Step 7 본문 참조).
3. 정화된 텍스트만 MCP 도구로 전달.

### 5-1. 생성 순서

3단계 계층의 의존 관계를 보장한다:
1. **Phase A**: Epic 생성 (key 확보 필수)
2. **Phase B**: PBI(Story/Task) 생성 — `jira_batch_create_issues` + 후처리 체인
3. **Phase C**: Sub-task 생성 — `jira_create_issue` 단건 호출 (parent 필수라 batch 불가)

> **Phase B와 C의 경로가 다른 이유**
> - `jira_batch_create_issues`는 `additional_fields`를 지원하지 않는다(허용 필드: project_key / summary / issue_type / description / assignee / components). parent·priority·커스텀 필드는 후처리로 붙여야 한다.
> - Sub-task는 Jira 제약상 create 시점에 parent가 필수다. parent 없이는 생성 자체가 거절된다.
> - Phase B(Story/Task)는 제약 1만 있고, Phase C(Sub-task)는 1·2 둘 다 있어 batch 불가.

**진행률 메시지 출력 규약 (5-2 / 5-3 / 5-4 공통)**:

이하 각 Phase의 진행률 메시지는 예시가 아닌 **출력 지시**다. MCP 호출 전후에 한 줄로 렌더링하며, 생략·축약·요약 테이블로 대체하지 않는다 (실시간 진행 파악·실패 구간 식별을 위함).

- 배경 메시지 `> 🟢 …`: Phase 또는 루프 단계 진입 시점에 1회
- 완료 메시지 `✅ {KEY} ({타입한국어}) 완료 …`: 이슈의 호출 체인 종료 시 1회 (Phase B/C는 루프 → `(n/N)` 카운트 증가)
- 부분 실패 메시지 `⚠️ {KEY} ({타입한국어}) 부분 실패 — 호출 {x}/3`: Phase C에서 호출 1/2/3 중 단계 실패 시 즉시 1회

`{타입한국어}`는 Step 2-0의 `ISSUE_TYPE_MAP[<표준 키>]` 한국어 값(에픽/스토리/작업/하위 작업)을 그대로 쓴다. Phase B는 Story·Task가 혼재하므로 각 이슈의 실제 타입을 병기한다. 영문 접두는 붙이지 않는다.

각 Phase 본문에서는 메시지 양식만 인라인으로 명시하고, 위 규약을 다시 반복하지 않는다.

### 5-2. Phase A — Epic 생성

> 🟢 에픽 생성 중...

`jira_create_issue`로 단건 생성한다:
- `project_key`: Step 0의 `{PROJECT_KEY}`
- `issue_type`: `ISSUE_TYPE_MAP["Epic"]`
- `summary`: 확정된 요약
- `assignee`: 2-1에서 확보한 `{ASSIGNEE}` — **`{ASSIGNEE} = null`이면 이 키 자체를 payload에서 생략한다.**
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

호출 3 완료: `✅ {KEY} (에픽) 생성 완료 (1/1)` (5-1 규약 적용).

생성된 Epic의 issue_key를 내부 참조(`#1` 등)에 매핑한다. Epic 생성 실패 시 전체 중단(하위 이슈의 parent 지정 불가).

### 5-3. Phase B — PBI 일괄 생성

> 🟢 PBI {N}건 검증 중... (N = PBI 총 건수)

**2단계 호출 체인 (필수 순서, 생략 금지)**:

**호출 1 — 사전 검증 (`validate_only: true`)**:

```
jira_batch_create_issues({
  issues: [
    { project_key: "PROJ", summary: "...", issue_type: ISSUE_TYPE_MAP["Story"], assignee: "{ASSIGNEE}" },
    { project_key: "PROJ", summary: "...", issue_type: ISSUE_TYPE_MAP["Task"],  assignee: "{ASSIGNEE}" },
    ...
  ],
  validate_only: true
})
```

> **`{ASSIGNEE} = null`이면 위 issues 배열의 각 항목에서 `assignee` 키 자체를 생략한다.** `null` 값을 그대로 전달하지 않는다. (호출 2 실 생성에도 동일 규칙 적용)

응답의 에러 필드를 건별로 수집한다. **호출 1을 건너뛰고 곧바로 `validate_only: false`로 실 생성하는 것은 규약 위반**이다. Jira Cloud의 필드 제약·권한·issue type 매핑 오류를 payload 수준에서 먼저 걸러내 반쪽 생성을 방지한다.

**검증 결과 처리**:

- **실패 0건**: 곧바로 호출 2로 진행.
- **실패 1건 이상**: 실패 건의 에러 원인을 사용자에게 **표로 리포트**하고 AskUserQuestion: `[실패 건 제외하고 나머지 생성 / 전체 중단]` 2지 질문.
  - Codex 등 AskUserQuestion 미지원 환경에서는 `나머지 생성` / `중단` 자연어 명령으로 대체.
  - 사용자 확인 없이 자동으로 `validate_only: false`를 호출해 생성하는 것은 **금지**.
  - "전체 중단" 선택 시 이슈를 하나도 생성하지 않고 Step 7 리포트로 넘어간다(Phase A에서 생성된 Epic은 그대로 유지되며, 후처리 없이 남는다 — Step 7에서 경고).

**호출 2 — 실제 생성 (`validate_only: false`)**:

호출 1을 통과한 이슈(또는 사용자가 "실패 건 제외하고 나머지 생성"에 동의한 경우 통과분)만 포함하여 호출한다:

```
jira_batch_create_issues({
  issues: [ ...호출 1 통과분... ],
  validate_only: false
})
```

> 🟢 PBI {N}건 일괄 생성 중...

각 PBI 후처리 (순차 루프):

> 🟢 PBI 후처리 중... (호출 2/3)
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
  - **`parent` 타입**: 값은 반드시 문자열 이슈 키(예: `"JST-86"`). 객체형 `{"key": "..."}`·`{"id": "..."}`은 거절된다. Phase C 호출 1의 parent와 동일 규칙.
- **호출 3** — `jira_update_issue`: description 단독 설정
  ```json
  { "description": "## 목적\n...\n\n## 범위\n..." }
  ```

> **자동화 룰 우회**: parent 설정이 description을 빈 템플릿으로 덮어쓰는 Jira 자동화 룰이 존재하므로, description은 반드시 마지막 호출에서 단독 설정한다. 이 순서는 변경하지 않는다.

각 PBI 호출 3 완료: `✅ {KEY} ({타입한국어}) 후처리 완료 ({n}/{N})` (5-1 규약 적용. n = 현재 인덱스, N = 총 건수).

각 PBI의 issue_key를 내부 참조에 매핑한다. 부분 실패 시 성공 건만 후속 처리하고, 실패 PBI의 하위 Sub-task는 보류한다. Phase B는 batch 단위 처리이므로 즉시 부분 실패 메시지를 출력하지 않으며, Step 7 결과 리포트에서 통합 보고한다 (5-1 규약의 부분 실패 메시지는 Phase C에만 적용).

### 5-4. Phase C — Sub-task 개별 생성

> 🟢 하위 작업 {N}건 생성 중...

Sub-task는 batch 경로 대신 각 항목마다 아래 **3단계 호출 체인**을 **순차 실행**한다. Phase B와 동일한 3단계 구조를 쓰되 호출 1에서 parent를 함께 설정하는 점만 다르다.

> **Sub-task 타입명**: `issue_type`에는 Step 2-0에서 확보한 `ISSUE_TYPE_MAP["Sub-task"]`를 사용한다. 프로젝트에 Sub-task 타입이 없으면 Step 2-0이 이미 중단시키므로 이 시점에는 반드시 유효한 값이 있다.

**호출 1 — `jira_create_issue` (parent 포함 생성)**:
- `project_key`: `{PROJECT_KEY}`
- `issue_type`: `ISSUE_TYPE_MAP["Sub-task"]`
- `summary`: 확정된 요약
- `assignee`: 2-1에서 확보한 `{ASSIGNEE}` — **`{ASSIGNEE} = null`이면 이 키 자체를 payload에서 생략한다.**
- `description`: **설정하지 않는다**
- `additional_fields`:
  ```json
  { "parent": "{PBI_KEY}" }
  ```
  > **parent 타입**: 값은 **반드시 문자열 이슈 키**(예: `"JST-86"`)여야 한다. 객체형 `{"parent": {"key": "JST-86"}}` 또는 `{"parent": {"id": "..."}}`는 MCP 서버가 거절한다. Jira REST API 원형과 달리 `mcp-atlassian`은 `additional_fields.parent`에 대해 문자열 키만 수용한다.
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

각 Sub-task 호출 3 완료: `✅ {KEY} ({타입한국어}) 생성 완료 ({n}/{N})` (5-1 규약 적용. n = 현재 인덱스, N = 총 건수). Phase C는 Sub-task만 다루므로 `{타입한국어}` = `ISSUE_TYPE_MAP["Sub-task"]` 값(인스턴스 설정에 따라 `하위 작업` 또는 `Sub-task`).

**부분 실패 처리**: 특정 Sub-task의 호출 1/2/3 중 어느 단계라도 실패하면 해당 Sub-task만 실패·부분 완료로 집계하고, 나머지 Sub-task 생성은 중단 없이 계속한다. 부분 실패 즉시 출력: `⚠️ {KEY} ({타입한국어}) 부분 실패 — 호출 {x}/3` (5-1 규약 적용). Step 7 리포트에 `⚠️ 부분 완료` 또는 `❌ 생성 실패`로 반영.

> **출력 빈도**: 진행률은 **이슈 단위로 1~2줄**만 출력한다. 호출 단위(`호출 2 시작`, `호출 3 시작` 등)로 매번 출력하지 않는다.

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

👤 Assignee 자동 식별 실패 — 모든 이슈를 unassigned로 생성했습니다.   ← Step 2-1에서 `{ASSIGNEE} = null`이었던 경우만 출력
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
