# 핸드오프: jira-batch-create 재설계 E2E 테스트·머지

**생성일**: 2026-04-22
**이전 세션 종료 사유**: 컨텍스트 토큰 초과
**현재 브랜치**: `refactor/jira-batch-create-auto-first`

---

## 지금까지 완료된 것

### 커밋 (main → 현재 HEAD, 총 7개)

```
5e61696 docs(jira-batch-create): README 재설계 반영
d8c609b fix(jira-batch-create): Phase C 3단계 체인으로 롤백 (ADF 검증 회피)
18c9d33 fix(jira-batch-create): 이슈 타입 맵 1회 조회·캐싱 도입
fd5d13a fix(jira-batch-create): assignee 획득을 jira_search 기반으로 단순화
a6aa3e3 docs: jira-batch-create 재설계 테스트 워크플로우 추가
4615997 refactor(jira-batch-create): 자동 보강 기반으로 재설계
d3d81eb build(scripts): {{CONFIG_DIR}} 토큰 치환 추가
```

### 실전 검증 1회 수행 결과

1차 JST 테스트에서 **P0 치명 버그 3건**을 발견하고 전부 수정 완료.
- #5 ADF 검증 실패 → Phase C 3단계 롤백 (`d8c609b`)
- #7 `currentUser()` MCP 미지원 → `jira_search` 기반 식별자 확보 (`fd5d13a`)
- #8 이슈 타입 한국어 의존 → `ISSUE_TYPE_MAP` 1회 캐싱 (`18c9d33`)

상세: `post-test-findings.md`.

### Codex 실사용 검증 결과 (2026-04-22)

`test-sdd.md`로 실제 배치 생성을 끝까지 수행했고, `JST-72`~`JST-85` 총 14건이 정상 생성됐다.
- 활성 스프린트가 없어 전부 백로그에 생성됨
- Slack DM 전송 성공
- 생성 중 마커(🤖/👤) 누수, ADF 오류, parent 누락은 재발하지 않음

다만 **스킬 정의/런타임 불일치**가 추가로 드러났다.
- **빈 프로젝트 이슈 타입 탐지 실패**: Step 2-0은 `project = {PROJECT_KEY}` 결과에서 타입명을 수집하도록 가정하는데, JST처럼 이슈가 0건인 프로젝트에서는 바로 막힌다.
- **`jira_search` 응답 형식 불일치**: 스킬은 `issues[].fields.issuetype.name`, `issues[].fields.assignee.*`를 전제하지만 실제 MCP 응답은 `issue_type.name`, `assignee.email`, `assignee.display_name` 형태였다.
- **config 필드 검증 전략 미흡**: config에 field key가 있어도 이름 기반 fuzzy search로 다시 해석하게 되어 AC/증거 필드가 프로젝트별 중복일 때 애매해진다. config 모드에서는 key 존재 여부만 확인하는 편이 안전하다.
- **Codex 확인/수정 UX 부재**: AskUserQuestion/multi-select 전제라 Codex에서는 자연어로 우회해야 했다. `특정 이슈 보기 7`, `수정 7 priority=High` 같은 텍스트 명령 문법이 필요하다.
- **장시간 생성 진행률 없음**: Epic/PBI/Sub-task 3단계 체인 호출이 길어질 때 중간 진행률과 예상 소요 시간 안내가 없어 실패처럼 보일 수 있다.

### 배포·환경 상태

- project scope 빌드 완료, 12개 파일 배포됨 (P0 fix 반영된 최신)
- `{{CONFIG_DIR}}` 치환 누수 0건
- JST 프로젝트 티켓 전체 삭제 완료 (0건)
- `~/.claude/sprint-workflow-config.md` → **TCI** (원래 글로벌 상태)
- `~/.claude/jira-sdd-templates.yml` → 없음 (다음 테스트에서 setup이 재생성)

---

## 남은 일

### 1. P0 fix 검증용 E2E 재수행 (필수)

`batch-create-test-workflow.md` 따라 시나리오 0~C 재수행. 2차 검증이며 목표는 **세 P0가 실제로 해결됐는지 확인**.

필수 점검:
- 시나리오 0: `/jira-batch-create-setup`이 `~/.claude/jira-sdd-templates.yml`을 실제로 생성하는지 (이전엔 `{{CONFIG_DIR}}` 리터럴 경로로 실패했음)
- 시나리오 A Step 2-1: assignee 획득 에러 없이 통과 (P0-1 검증)
- 시나리오 A Step 2-0 로그: `ISSUE_TYPE_MAP`이 `{Epic: "에픽", ...}`로 로드 (P0-2 검증)
- 시나리오 C Phase C: Sub-task 3단계 호출 관찰, ADF 오류 0건 (P0-3 검증)
- 마커 누수: 생성된 이슈에 🤖/👤 문자 0건

**테스트 프로젝트 결정**:
현재 홈 config는 TCI. JST로 바꾸려면 사용자가 한 가지 선택:
- Claude에게 "홈 config를 JST로 바꿔줘" (프로젝트 키 JST, 보드 2155, 필드 `customfield_12881`/`customfield_12880`)
- `/jira-create-setup` 재실행
- 직접 편집

### 1-1. 참고: main 머지 후 별도 브랜치로 처리할 Codex 런타임 보정

아래 항목은 **현재 `refactor/jira-batch-create-auto-first`에 포함할 필수 범위가 아니다**.
`main` 머지 후 `fix/jira-batch-create-runtime-compat` 브랜치에서 별도로 처리한다.
- Step 2-0 이슈 타입 탐지에 **빈 프로젝트 fallback** 추가
  - 후보: 최근 1년 전역 검색, `validate_only` probe, 또는 setup 시 타입명 저장
- Step 2-1 `jira_search` 응답 파서를 실제 MCP 형식으로 수정
  - `issue_type.name`, `assignee.email`, `assignee.display_name` 대응
- config 로드 시 customfield는 fuzzy search 대신 **설정된 key 우선 + 존재 여부 검증**으로 변경
- Codex용 확인/수정 문법 추가
  - 예: `이대로 생성`, `특정 이슈 보기 7`, `수정 7 priority=High sp=5`
- 장시간 생성용 진행률 로그 문구 추가
  - 예: `Epic 생성 완료 (1/14)`, `Sub-task 3/8 처리 중`

### 2. main 머지 (E2E 통과 후)

```bash
git checkout main
git merge --no-ff refactor/jira-batch-create-auto-first
```

`--no-ff`로 PR 범위를 하나의 머지 커밋에 묶는다. GitHub PR UI의 "Create a merge commit"과 같다.

### 3. 후속 브랜치 (main 머지 후, 우선순위순)

`post-test-findings.md`와 Codex 실사용 검증에서 남은 P1/P2/P3 성격 작업은 별도 브랜치로 처리:

| 브랜치 | 범위 | 비고 |
|--------|------|------|
| `refactor/jira-batch-create-ux` | P1 (#1 테이블 짤림, #2 setup 분리, #3 clone 설치, #4 pre-setup 전제) | 설계 결정 먼저 필요 |
| `chore/jira-batch-create-safety` | P2 (#6 parent 타입 주석, #9 customfield 스코프 검증, #10 validate_only 강제, #11 이전 승인 재사용) | 작은 변경 모음 |
| `fix/jira-batch-create-runtime-compat` | 빈 프로젝트 타입 fallback, `jira_search` 응답 파서 정합, config field key 우선 검증 | Codex/Claude 공통 런타임 보정 |
| `docs/jira-batch-create-clarify` | P3 (#12 Markdown↔Wiki 표기) | 주석 한 줄 |

### 4. 단건 `jira-create` 동기화 (별건)

`jira-create.body.md`에도 동일 패턴이 남아 있음:
- `jira_get_user_profile("currentUser()")` 의존 (line 191 근처)
- 이슈 타입 한국어 이슈 (동일 제약이 단건에도 적용)

이번 PR 범위 밖으로 두었으니, 별도 `fix/jira-create-align-with-batch` 브랜치에서 P0-1·P0-2를 동일하게 적용.

---

## 다음 세션 시작 가이드

다음 세션을 시작하면 아래 순서로 진행:

1. `git status`로 현재 브랜치·상태 확인
2. `batch-create-test-workflow.md` 열어 시나리오 0부터 수행
3. 홈 config가 TCI면 사용자에게 "JST로 바꿀까요?" 확인 후 조정
4. 시나리오 C에서 실제 티켓 14건 생성 → 마커 누수·ADF 오류·이슈 타입 맵 검증
5. 통과 시 `--no-ff` 머지 제안
6. 실패 시 로그 공유 → 추가 fix 커밋 (`fix/jira-batch-create-critical` 재사용 또는 신규 분기)

---

## 주요 문서 인덱스

- `jira-create/jira-batch-create.body.md` — 재설계된 본문
- `jira-create/README.md` — 재설계 반영된 스킬 설명서
- `post-test-findings.md` — 1차 테스트 피드백 12건, P0~P3 분류
- `batch-create-test-workflow.md` — E2E 테스트 절차 (간략화판)
- `scripts/build-skills.sh` — `{{CONFIG_DIR}}` 치환 로직 포함
- `test-sdd.md` / `test-sdd-blog-migration.md` / `test-sdd-file-upload.md` — Spec Kit 포맷 테스트 샘플

---

## 머지 전략 요약

- `fix/*` → `refactor/*` 머지: `git merge --ff-only`
- `refactor/*` → `main` 머지: `git merge --no-ff`
- 커밋 규약: Conventional Commits + 한국어 subject + `Co-Authored-By` 푸터 (CLAUDE.md 참조)
