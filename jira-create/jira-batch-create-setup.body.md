
> **실행 환경 전제**
> - 본문에 "AskUserQuestion"이라고 적힌 부분은 구조화 질문 도구를 의미한다. 해당 도구가 없는 환경(예: Codex)에서는 동일 의미의 자연어 질문으로 대체하되, 선택지/검증 조건은 본문에 명시된 그대로 유지한다.


# SDD 템플릿 등록

jira-batch-create 스킬이 사용하는 SDD 파싱 템플릿을 등록하고 관리한다. 템플릿은 `{{CONFIG_DIR}}/jira-sdd-templates.yml`에 저장된다.


## Step 1 — 기존 템플릿 확인

`{{CONFIG_DIR}}/jira-sdd-templates.yml` 파일을 Read 도구로 읽는다.

- 파일이 있고 `templates:` 키가 존재하면:
  - 등록된 템플릿 이름 목록을 출력
  - AskUserQuestion: "새 템플릿 추가 / 기존 수정 / 삭제" (3개 선택지)
  - "기존 수정": 수정할 템플릿 이름을 선택 → Step 3으로 (기존 샘플 없이 규칙만 수정)
  - "삭제": 삭제할 템플릿을 선택 → 해당 항목 삭제 후 저장 → Step 6으로
- 파일이 없으면: "새 템플릿 추가" 경로로 진행


## Step 2 — 템플릿 이름 지정

AskUserQuestion:
> "템플릿 이름을 입력하세요. (예: spec-kit, team-sdd)"

검증 조건:
- 영문 소문자 + 하이픈만 허용 (`[a-z][a-z0-9-]{1,29}`)
- 2~30자
- 기존 이름과 중복 시: "이미 존재합니다. 덮어쓰시겠습니까? (예/아니오)"
  - "아니오": 다시 입력 요청
  - "예": 기존 항목 덮어쓰기로 진행


## Step 3 — 샘플 SDD 입력

AskUserQuestion:
> "샘플 SDD 파일 경로를 입력하거나, SDD 내용을 붙여넣어 주세요."

- 파일 경로(`.md`, `.txt` 등 확장자 또는 `/`로 시작)면 Read 도구로 로드
- 그 외 텍스트면 직접 입력으로 간주하여 그대로 사용


## Step 4 — 파싱 규칙 자동 생성

Claude가 샘플 SDD를 분석하여 아래 구조의 YAML 템플릿을 자동 생성한다.

### 템플릿 YAML 구조

```yaml
template_name:
  description: "한 줄 설명"
  match: "SDD 식별 문자열"    # SDD 첫 H1에 이 문자열이 포함되면 매칭
  headings:
    epic:
      level: 1                # 헤딩 레벨 (H1=1, H2=2, ...)
      pattern: "패턴"         # {title} = 캡처 그룹
    story:
      level: 2
      contains: "식별 문자열"  # 헤딩에 이 문자열 포함 시 Story
      pattern: "패턴"
    phase:
      level: 2               # story 조건에 해당하지 않는 H2
      issue: false           # Jira 이슈 생성 안 함 (하위 Task의 컨텍스트용)
  tasks:
    subtask:
      marker: "- [ ]"
      tag: "태그 패턴"        # 이 태그가 있으면 Sub-task
      parent: "matched_story" # 태그 번호에 해당하는 Story가 parent
    task:
      marker: "- [ ]"
      no_tag: true           # 태그 없는 태스크 → Task (PBI)
      parent: "epic"
  metadata:
    purpose: "마커 문자열"     # 이 마커 뒤의 텍스트 → 이슈 목적
    goal: "마커 문자열"        # Story의 목표
    test_hint: "마커 문자열"   # AC 힌트
    file_path: "패턴"         # 범위 추출 (예: "→ `{path}`")
```

### 분석 시 주의사항

- 헤딩 레벨과 패턴을 정확히 감지 (H1, H2, H3 등)
- 체크리스트 마커 (`- [ ]`, `- [x]` 등) 감지
- 태그 패턴 감지 (예: `[US1]`, `[P]` 등 대괄호 내 텍스트)
- 메타데이터 마커 감지 (Bold 텍스트 + 콜론 패턴: `**목적**:`, `**목표**:` 등)
- 파일 경로 패턴 감지 (예: `→ \`path\``)
- 메타데이터 마커가 샘플에 없으면 해당 필드를 `null`로 설정하고, 사용자에게 "이 SDD에는 해당 메타데이터 마커가 없습니다. batch create 시 수동 입력이 필요합니다."라고 안내한다.

### 초안 제시 형식

분석이 끝나면 아래 형식으로 사용자에게 제시한다:

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

AskUserQuestion: "이 규칙으로 저장 / 수정" (2개 선택지)
- "수정" 선택 시: 수정할 항목을 질문하고 반영 후 다시 초안 형식으로 제시. 사용자가 "저장"을 선택할 때까지 반복.


## Step 5 — 저장

`{{CONFIG_DIR}}/jira-sdd-templates.yml`에 템플릿을 추가/갱신한다.

- 파일이 없으면 새로 생성한다. 루트 키는 `templates:`로 한다.
- 기존 파일이 있으면 해당 템플릿 이름의 항목만 추가/덮어쓰기한다 (다른 템플릿은 유지).
- 기존 수정(Step 1에서 "기존 수정" 선택) 경로인 경우에도 동일하게 해당 키만 갱신한다.


## Step 6 — 완료 안내

```
✅ SDD 템플릿이 등록되었습니다.

저장 위치: {{CONFIG_DIR}}/jira-sdd-templates.yml

등록된 템플릿:
- {template_name}: {description}

이제 /jira-batch-create 커맨드로 SDD 기반 일괄 이슈 생성을 사용할 수 있습니다.
SDD 파일의 첫 H1 헤딩이 등록된 템플릿의 식별 패턴과 일치해야 합니다.

⚠️ {{CONFIG_DIR}}/jira-sdd-templates.yml 파일은 git에 커밋하지 마세요.
```

등록된 템플릿 목록은 파일에 저장된 전체 템플릿을 나열한다.


## 가이드라인

- 샘플 SDD를 분석할 때 구조를 정확히 파악하는 것이 핵심이다. 불확실한 부분은 사용자에게 확인한다.
- 메타데이터 마커가 샘플에 없으면 해당 필드를 `null`로 설정하고, 사용자에게 "이 SDD에는 목적/목표 마커가 없습니다. batch create 시 수동 입력이 필요합니다."라고 안내한다.
- 템플릿 이름은 파일 내에서 유일해야 한다.
- `headings`, `tasks`, `metadata` 각 섹션에서 샘플에 해당하는 패턴이 없으면 해당 키를 생략하지 말고 `null`로 명시하여, batch create 시 누락 필드를 인지할 수 있게 한다.
