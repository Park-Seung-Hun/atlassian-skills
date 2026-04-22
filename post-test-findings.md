# jira-batch-create 재설계 1차 테스트 피드백

**테스트 일자**: 2026-04-22
**대상 브랜치**: `refactor/jira-batch-create-auto-first`
**테스트 환경**: JST 프로젝트, Jira Cloud (tmaxsoft.atlassian.net)
**결론**: 핵심 흐름(자동 보강 + 미리보기 + payload 정화)은 동작 확인. 단 **치명적 버그 3건**과 **설계 재검토 4건**, **안전장치 보강 4건**, **UX 개선 2건** 식별.

---

## 우선순위 요약

| 순위 | 이슈 | 카테고리 | 영향 |
|------|------|---------|------|
| 🔴 P0 | #5 ADF 검증으로 Sub-task 2단계 체인 실패 | 버그 | 재현 필수, 3단계 롤백 필요 |
| 🔴 P0 | #7 `currentUser()` MCP 미지원 | 버그 | Step 2-1 전제 깨짐 |
| 🔴 P0 | #8 이슈 타입명 한국어 의존 범위 | 버그 | Epic/Story/Task 전부 "에픽/스토리/작업" 등 한국어만 허용 |
| 🟡 P1 | #1 티켓 리스트 터미널 출력 짤림 | UX | 14개에서도 발생 |
| 🟡 P1 | #2 batch-setup 스킬 분리 타당성 | 설계 | 기능이 템플릿 등록뿐이라 과한 분리? |
| 🟡 P1 | #3 repo clone 기반 설치 불편 | 배포 | 원클릭 설치 경로 필요 |
| 🟡 P1 | #4 jira-create-setup 사전 필요성 | 설계 | 진입장벽 |
| 🟢 P2 | #6 `additional_fields.parent` 타입 명시 | 안전장치 | 본문 예시 보강 |
| 🟢 P2 | #9 customfield 프로젝트 스코프 검증 | 안전장치 | config 로드 단계 |
| 🟢 P2 | #10 `validate_only` 강제 | 안전장치 | 본문 지침 준수 |
| 🟢 P2 | #11 이전 승인 재사용 로직 | UX | 재실행 시 Step 4 반복 부담 |
| 🔵 P3 | #12 Markdown ↔ Wiki markup 표기 불일치 | 문서 | 오해 소지 |

---

## 🔴 P0 — 치명적 버그 (다음 브랜치에서 반드시 수정)

### #5 Sub-task 업데이트 시 description + customfield 조합 불가 (ADF 검증)

**증상**: Phase C 2단계 체인의 호출 2에서 `description` + `{FIELD_AC}` + `{FIELD_EV}`를 한 payload에 넣으면 **Jira ADF 검증 오류**로 거절됨.

**원인**: 자동화 룰이 아닌 ADF(Atlassian Document Format) 변환 실패. description은 ADF 문서 구조를 요구하는데, 같은 payload의 custom field가 plain text면 Jira가 혼합 처리에 실패.

**현재 본문**: "실환경에서 자동화 룰로 덮이면 3단계로 롤백"이라는 주석이 있음. 원인은 다르지만 조치는 동일.

**조치**:
- Phase C도 **3단계 체인으로 롤백** (create with parent → custom field + priority + timetracking → description 단독)
- 본문 주석을 "ADF 검증 실패 또는 자동화 룰 덮어씀 관측 시 3단계 적용"으로 일반화
- 또는 ADF 안전한 description만 먼저 분리하는 2.5단계(custom field 먼저 → description만) 방식 탐색

### #7 `jira_get_user_profile(user_identifier="currentUser()")` 지원 안 함

**증상**: "사용자를 찾을 수 없음" 반환. MCP 툴이 email/name/accountId만 허용하고 JQL 함수형 `currentUser()`를 받지 않음.

**fallback 결과**: `jira_search(jql="assignee = currentUser()")` 경로를 탔으나 응답에 email/name만 있고 accountId 부재 → 결국 email 문자열을 assignee로 직접 사용.

**조치**:
- Step 2-1을 **"accountId 획득"이 아니라 "assignee 식별자 획득"으로 일반화**
- 허용 식별자: email / display name / accountId 중 하나면 OK (MCP가 수용)
- 우선순위: `jira_search`로 email 추출 → 그대로 사용 (accountId 변환 시도하지 않음)
- `jira_get_user_profile` 호출은 assignee 식별용 폴백으로 강등

### #8 이슈 타입명 한국어 의존 — Epic/Story/Task 전부

**증상**:
- `issue_type: "Epic"` → "유효한 이슈 유형을 지정하세요" 거절
- `issue_type: "에픽"` → 통과
- 동일 제약이 Story/Task/Sub-task **전체**에 적용됨

**현재 본문**: Step 5-4에서 **Sub-task만** 언어 분기를 언급. Epic/Story/Task는 영문명으로 하드코딩 가정.

**조치**:
- **Step 0(hub)에서 프로젝트의 이슈 타입 맵을 1회 조회·캐싱**
  - `jira_get_issue`로 임의 기존 이슈 1건 조회 후 `issuetype.name` 확보
  - 또는 Jira REST `project/{key}`의 `issueTypes` 엔드포인트 사용
- 매핑 테이블로 관리: `{Epic, Story, Task, Sub-task, Spike} → {언어별 로컬 이름}`
- Phase A/B/C가 이 맵을 참조하도록 수정

---

## 🟡 P1 — 설계 재검토·UX 개선

### #1 티켓 리스트 터미널 출력 짤림

**증상**: 14개 이슈의 계층 요약 테이블이 터미널 폭을 넘어 일부 컬럼이 줄바꿈·누락됨.

**원인**: 현재 컬럼 수가 7개(`# / 타입 / 요약 / 상위 / 우선순위 / SP / 증거`). 요약이 길면 단일 행 폭이 120자를 쉽게 넘김.

**대안 후보**:
- **A. 2행 구조**: 각 이슈를 2줄로 출력 (1줄: 계층/타입/요약/상위, 2줄: 우선순위/SP/증거). 읽기는 편하지만 세로가 길어짐
- **B. 중요 컬럼만 기본**: 기본은 `# / 타입 / 요약 / 상위`만, 나머지는 `--verbose` 또는 "상세 보기"에서. 간결하지만 한 눈에 전부 안 보임
- **C. 트리 문자형 출력**: 테이블이 아닌 들여쓰기 기반 트리 형태. 계층이 직관적이고 컬럼 제약에서 자유로움
  ```
  [Epic] #1 소셜 로그인 통합 (Medium, -)
    [Task] #2 OAuth2 프로바이더 타입 정의 (Medium, 2)
    [Story] #5 Google 로그인 (High, 5)
      [Sub-task] #8 Google OAuth 콜백 API 구현 (High, -)
  ```
- **D. 요약 컬럼 자동 축약**: 요약 40자 초과 시 중간 ellipsis. 나머지 유지

**추천**: **C(트리형) + D(요약 축약)** 조합. 테이블에 집착하지 않으면 계층 표현이 자연스러움.

### #2 batch-setup 스킬 분리의 타당성

**현재**: `/jira-batch-create-setup`은 단일 기능(spec-kit 템플릿 등록)만 수행.

**대안**:
- **A. `/jira-batch-create` 안에 등록 흐름 내장**: 템플릿이 없으면 첫 실행 시 자동으로 setup 서브플로우 진입. 사용자 질문 답하고 바로 본 흐름으로 이어짐
- **B. setup 기능은 스킬 내부의 `--manage-templates` 플래그로 수행**
- **C. 현재대로 분리 유지**: 설정 변경이 드물고 명시적 호출이 안전

**추천**: **A**. "처음 실행하면 알아서 등록까지 처리"가 사용자 목표(자동화)와 일치. 템플릿 관리가 필요하면 `/jira-batch-create --reset-templates` 같은 플래그로 충분.

### #3 저장소 clone 기반 설치 불편

**현재 흐름**: clone → build → project scope 배포. 팀원이 이걸 전부 수행해야 함.

**대안**:
- **A. `curl | bash` 원클릭 설치 스크립트**: 저장소에서 빌드 산출물을 바로 가져와 `~/.claude/commands/`에 배포
- **B. GitHub Release에 pre-built 산출물 업로드**: 브랜치 tag당 released skills 폴더 제공
- **C. npm/pip 패키지화**: `npx @internal/atlassian-skills install` 같은 CLI 제공

**추천**: **B → A 확장**. GitHub Release가 가장 저비용. 원클릭 설치 스크립트는 릴리즈 파일을 내려받기만 하면 되니 구현 간단.

### #4 jira-create-setup 사전 필요성

**현재**: batch-create가 동작하려면 `~/.claude/sprint-workflow-config.md`에 프로젝트 키·보드 ID·custom field ID가 미리 입력돼 있어야 함. 없으면 hub의 inline fallback이 동작하지만 질문이 여러 개 늘어남.

**문제**: 처음 쓰는 사용자가 "왜 미리 설정부터 해야 하나"로 진입장벽 느낌.

**대안**:
- **A. 첫 실행 시 hub의 inline fallback을 자동 수행 + 그 값을 config에 저장**: "이번 호출에 썼던 값을 다음을 위해 저장하시겠습니까?" 질문 1개만
- **B. `.claude/sprint-workflow-config.md` 없으면 현재 저장소의 `.claude/settings.local.json`이나 환경변수(`JIRA_PROJECT_KEY` 등)에서 읽기**
- **C. config 필수 필드를 최소화** — 프로젝트 키만 있으면 custom field는 자동 탐색 + 캐시

**추천**: **A + C**. 최초 1회만 inline 수집 → 결과 저장 → 이후 자동 사용. "별도 setup 단계"라는 개념 자체를 제거.

---

## 🟢 P2 — 안전장치 보강

### #6 `additional_fields.parent`는 문자열 키만 허용

**증상**: 본문 예시는 `{"parent": "{PBI_KEY}"}`(문자열). 내가 객체형 `{"parent": {"key": "PROJ-X"}}`을 시도하면 MCP가 거절.

**조치**: 본문 Phase C 호출 1 예시 옆에 **"반드시 문자열 값, 객체형 `{key: ...}` 금지"** 주석 추가.

### #9 customfield 프로젝트 스코프 검증

**증상**: `customfield_XXXXX`가 특정 프로젝트 범위에만 바인딩된 경우 다른 프로젝트에서 update 호출이 조용히 무시되거나 실패. config에 저장된 값이 현재 PROJECT_KEY에 유효한지 모름.

**조치**:
- Step 0 config 로드 후 `jira_search_fields` 또는 `jira_get_issue`로 해당 field ID가 현재 프로젝트에서 사용 가능한지 검증
- 유효하지 않으면 경고 1회 + 해당 필드 비활성화(`(none)` 취급)

### #10 `validate_only: true` 사전 검증 강제

**증상**: 14건 규모라 생략해도 문제없었지만, 본문 지침상 Phase B는 반드시 `validate_only: true`를 먼저 돌려야 함. 규모가 커지면 생략 리스크 증가.

**조치**: 본문 지침 그대로 유지하되, **스킬 본문에 "생략 금지" 문구를 강조**하고 auto 모드여도 이 단계는 건너뛰지 않도록 명시.

### #11 이전 승인 재사용 로직

**증상**: auto 모드 + 이전 세션에서 이미 승인한 맥락 때문에 Step 4 게이트를 건너뛰었음. 엄밀히는 재실행 시에도 미리보기를 봐야 함.

**조치 후보**:
- **A. 재실행 감지 안 함 — 항상 Step 4 노출**: 엄격하지만 반복 실행 시 부담
- **B. `--yes` 또는 `--reuse-last-approval` 플래그 도입**: 명시적 옵트인
- **C. config에 "마지막 승인 이슈 해시"를 저장, 동일 입력이면 Step 4 스킵**: 자동이지만 예측 가능

**추천**: **B**. 사용자가 "이번엔 확인 안 해도 돼"를 명시적으로 선택.

---

## 🔵 P3 — 문서 명확성

### #12 Markdown ↔ Wiki markup 변환

**관찰**: 내가 `## 목적`, `**포함**`을 보냈는데 Jira가 `h2. 목적`, `*포함*`으로 저장. 렌더링 결과는 같지만 저장 포맷은 wiki markup.

**조치**: 본문 Step 2-5 description 예시 옆에 주석 — **"보낸 형식은 Markdown, Jira Server가 wiki markup으로 자동 변환해 저장. 렌더링 동일."** 추가.

---

## 다음 작업 제안

| 브랜치 | 범위 | 예상 소요 |
|--------|------|----------|
| `fix/jira-batch-create-critical` | P0 3건(#5, #7, #8) | 작음 (본문 수정 + 이슈 타입 맵 캐싱 추가) |
| `refactor/jira-batch-create-ux` | P1 4건(#1~#4) 중 선택 | 중간~큼 (#2, #3, #4는 설계 결정 필요) |
| `chore/jira-batch-create-safety` | P2 4건(#6, #9, #10, #11) | 작음 (본문·config 로드 보강) |
| `docs/jira-batch-create-clarify` | P3 1건(#12) | 매우 작음 |

P0 먼저 처리 후 현재 브랜치 main 머지 승인 가능. P1의 #2, #3, #4는 별도 설계 논의 필요 — 각각 방향 정해지면 별건 이슈로 분리 추천.

**회귀 보호**:
- P0 수정 후 JST 또는 샌드박스에서 **시나리오 C(실제 생성) 재수행** 필수.
- 특히 이슈 타입 맵 캐싱은 영문/한국어 인스턴스 양쪽에서 동작 확인.
