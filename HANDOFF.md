# 핸드오프: jira-batch-create 후속 정비

**갱신일**: 2026-04-23
**현재 브랜치**: `main` (작업 깨끗)
**원격 동기화**: `origin/main`까지 push 완료

---

## 이번 세션에서 완료된 것

### 1. 저장소 작성자 정정

전 커밋 30개의 author/committer를 `seunghun_park2 <seunghun_park2@tmaxsoft.com>` →
`Phodol2 <psh19930326@gmail.com>`로 일괄 재작성하고 force push.
로컬 git config(`user.name`/`user.email`)도 이 저장소에서만 동일 값으로 변경.

### 2. `refactor/jira-batch-create-auto-first` → main 머지

이전 핸드오프에서 미완이던 P0 fix 검증이 끝나 main에 머지됨(`9b84595`).

### 3. `fix/jira-batch-create-runtime-compat` 작업 + main 머지

런타임 정합성 4건을 본문(`jira-create/jira-batch-create.body.md`)에서 보정하고
main에 `--no-ff` 머지(`77bf8ca`, 본문 커밋 `32219cc`).

| # | 변경 | 위치 |
|---|------|------|
| 1 | Step 2-0 빈 프로젝트 fallback — `jira_search` 결과 0건일 때 후보 9개로 `jira_batch_create_issues(validate_only=true)` probe 1회 호출하여 ISSUE_TYPE_MAP 구축 | Step 2-0 |
| 2 | Step 2-1 응답 필드명 정합 — 실제 MCP 스키마(`issue_type.name`, `assignee.{id|email|display_name}`)에 맞춰 파싱 표현 수정 | Step 2-0/2-1 |
| 3 | Step 4 (C) Codex 자연어 명령 문법 — `생성`/`취소`/`보기 N`/`수정 N`/`수정 N field=value` 명령 매핑 표 추가, (C-1)/(C-2) 진입 트리거 양환경 매핑 | Step 4 (C) |
| 4 | Phase A/B/C 진행률 로그 — `🟢 ... 중...` / `✅ ... 완료 (n/N)` 메시지 박고 "이슈 단위 1~2줄" 가이드라인 추가 | Step 5-2/5-3/5-4 |

검증 결과(JST 빈 프로젝트, 14건 생성):
- ① 빈 프로젝트 fallback: probe 통과 → 한국어 타입(에픽/스토리/작업/하위 작업) 매핑 확인
- ② assignee 필드 정합: `issues[0].assignee.email` 추출 성공
- ③ 진행률 로그: Phase 단위 출력 정상 (호출 단위 누수 없음)
- 회귀: JST-86~99 14건 생성, ADF·마커 누수 0건

미검증 항목(별건으로 분리):
- ⑤ Codex 축약형 `수정 7 priority=High sp=5` 즉시 반영
- ⑤ 수정 불가 필드 거절(`수정 7 parent=#1`)

### 4. hub.body 변경(0-0a 신설)은 본 브랜치에서 제외

config 모드에서 customfield key 존재만 검증하는 절(`### 0-0a. config 모드 키 검증`)은
사용자가 다른 브랜치에서 동일 류 수정을 함께 진행할 예정이라 이번 브랜치에선 빠짐.
세션 중 작업해뒀던 hub.body 변경은 머지 전 `git restore`로 되돌림.

---

## 남은 일

### A. hub.body 정비 (사용자 별도 진행 예정)

- `jira-create/jira-create-hub.body.md`에 `0-0a. config 모드 키 검증` 절 신설
- 라인 11 분기 명확화("config 없을 때만 자동 조회")
- 키워드 매칭은 인라인 수집 경로 전용임을 명시
- 라인 57 진술 강화("재조회 건너뛰되 customfield key는 1회 검증")

설계는 `/Users/psh/.claude/plans/fix-jira-batch-create-runtime-compat-keen-zephyr.md`의
**Step 3** 항목에 그대로 남아 있음. 사용자가 직접 또는 다른 세션에서 적용.

### B. ⑤ Codex 미검증 케이스 — 별건

다음 두 가지를 Codex CLI에서 짧게 재현하여 마지막 구멍 닫기:
- `수정 7 priority=High sp=5` → 필드 선택 대화 없이 priority/sp가 👤로 즉시 갱신되는지
- `수정 7 parent=#1` → 수정 불가 필드 거절되는지

문제 발견 시 별도 fix 브랜치로 본문 보정.

### C. 다음 후속 브랜치 (우선순위 순)

| 브랜치 | 범위 | 비고 |
|--------|------|------|
| `refactor/jira-batch-create-ux` | P1 (#1 테이블 짤림, #2 setup 통합, #3 원클릭 설치, #4 pre-setup 제거) | 설계 결정 필요 |
| `chore/jira-batch-create-safety` | P2 (#6 parent 타입 주석, #10 validate_only 강제, #11 이전 승인 재사용) | 작은 변경 모음. #9는 hub.body 정비와 겹침 |
| `fix/jira-create-align-with-batch` | 단건 jira-create.body.md에도 동일 P0 패턴 적용 (currentUser 의존, 한국어 타입) | batch와 패턴 동기화 |

상세는 `post-test-findings.md` 참조.

### D. 로컬 stale 브랜치 정리 (선택)

main에 이미 머지된 로컬 브랜치 3개가 남아 있음. 필요 시 `git branch -d`로 삭제:
- `feat/project-scoped-config`
- `fix/jira-batch-create-critical`
- `refactor/jira-batch-create-auto-first`

원격에는 동일 브랜치들이 남아 있으니 정리하려면 `git push origin --delete <name>`.

---

## 다음 세션 시작 가이드

1. `git status` / `git log --oneline -10`으로 main 위치 확인
2. 위 A~D 중 사용자가 어느 항목부터 진행할지 정하기
3. 작업 시작 전 자동 메모리(`~/.claude/projects/-Users-psh-develop-atlassian-skills/memory/`)에서
   `jira_batch_create_review_issues.md` 참고. 15개 리뷰 이슈 중 P0 3건은 해결됨, 나머지는 위 C에 매핑.

---

## 주요 문서 인덱스

- `jira-create/jira-batch-create.body.md` — 본문 (4건 보정 반영됨)
- `jira-create/jira-create-hub.body.md` — 공유 hub 본문 (이번 세션에선 변경 없음)
- `post-test-findings.md` — 1차 테스트 피드백 12건, P0~P3 분류
- `batch-create-test-workflow.md` — E2E 테스트 절차
- `/Users/psh/.claude/plans/fix-jira-batch-create-runtime-compat-keen-zephyr.md` — 이번 작업 plan, Step 3에 hub.body 설계 남아 있음

---

## 머지 전략

- 후속 fix/refactor → main 머지: `git merge --no-ff`
- main push 시 권한 프롬프트가 뜨므로 사용자 승인 필요(이번 세션에서 1회 발생)
- 커밋 규약: Conventional Commits + 한국어 subject. `Co-Authored-By` 푸터 없음(작성자 일괄 정정 후 단독 author)
