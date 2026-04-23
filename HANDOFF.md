# 핸드오프: jira-batch-create 후속 정비

**갱신일**: 2026-04-23 (F 합의 반영)
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

## 남은 일 (후속 작업 체크리스트)

> 표기: `- [ ]` 미착수 / `- [x]` 완료. 항목 하위 들여쓰기는 세부 내용.

### A. hub.body 진입 흐름 개편 (F 합의 반영) ✅ 완료 (2026-04-23)

**브랜치**: `refactor/hub-body-entry-flow` (main 기준 7개 커밋) — main 머지 대기
**E2E 검증**: Codex 기반 S1~S7 (S5 스킵) 모두 통과. 절차는 `hub-body-e2e-codex.md` 참조.

#### A-1. 신규 절 — 완료

- [x] `0-0b` 현재 설정 확인 스텝 신설
  - config 로드 후 PROJECT_KEY / BOARD_ID / FIELD_SP·AC·EV / DEFAULT_PRIORITY / DEFAULT_EVIDENCE / SLACK_ID 요약 출력
  - AskUserQuestion: `[그대로 진행 / 항목 수정]`
- [x] `0-0c` 항목별 수정 스텝 신설
  - "수정" 선택 시 복수 선택 UI로 대상 슬롯 지정
  - 각 슬롯마다 0-1의 해당 블록을 재실행 → `{{CONFIG_PATH}}` 덮어쓰기(영속화)
  - 완료 후 0-0b로 복귀 (재확인 루프)
- [x] `0-0a` 자동 키 검증 + 슬롯별 재지정 분기 신설 (F-2 본질)
  - 0-0b에서 "진행" 선택 후 customfield probe 1회 실행
  - 실패 슬롯 감지 시 `[재지정 / 비활성화 / 중단]` 분기
  - "재지정" → 해당 슬롯만 0-1의 블록 재진입 → config 저장
  - "비활성화" → 세션 내 `(none)` 처리, config 미변경

#### A-2. 기존 지문 정비 — 완료

- [x] 라인 11 분기 명확화("config 없을 때만 자동 조회")
- [x] 키워드 매칭은 인라인 수집 경로 전용임을 명시
- [x] 0-1을 "슬롯별 재호출 가능한 서브루틴"으로 구조화 (0-1-PROJECT / 0-1-SP / 0-1-AC / 0-1-EV)
- [x] 라인 57 진술 강화("재조회 건너뛰되 customfield key는 1회 검증")

#### A-3. E2E 관찰 기반 추가 보강 (4개 fix 커밋) — 완료

- [x] Step 0 실행 순서 강제 + 0-2 오버라이드 조건에 "config와 다른 프로젝트 키" AND 조건 추가 (`c9941f1`)
- [x] customfield 후보 scope 필터로 다른 프로젝트 전용 필드 차단 (`59d56b8`)
- [x] 0-1 사용자 확인 강제 + 0-1-SAVE로 신규 config 저장 절차 추가 (`820b4c4`)
- [x] PROJECT_ID 확보 폴백 체인(jira_search → jira_get_all_projects → 휴리스틱) + unknown 시 보수 필터링 (`fbfc45d`)

#### 커밋 로그 (main..HEAD)

```
b9e3b26  refactor(jira-create): hub.body에 config 확인/수정/검증 흐름 추가
c9941f1  fix(jira-create): hub Step 0 실행 순서 강제 + 0-2 오버라이드 조건 보강
59d56b8  fix(jira-create): customfield 후보 scope 필터로 다른 프로젝트 전용 필드 차단
820b4c4  fix(jira-create): 0-1 사용자 확인 강제 + 0-1-SAVE로 신규 config 저장
fbfc45d  fix(jira-create): PROJECT_ID 확보 폴백 체인 + unknown 시 보수 필터링
6191b94  docs: F 합의 반영 및 A/C 체크리스트 재편
dfbdbfd  docs: hub.body 진입 흐름 개편 Codex E2E 테스트 가이드 추가
```

### B. ⑤ Codex 미검증 케이스 — 별건

- [ ] `수정 7 priority=High sp=5` → 필드 선택 대화 없이 priority/sp가 👤로 즉시 갱신되는지 Codex CLI에서 재현
- [ ] `수정 7 parent=#1` → 수정 불가 필드 거절되는지 Codex CLI에서 재현
- [ ] 문제 발견 시 별도 fix 브랜치로 본문 보정

### C. 다음 후속 브랜치 (우선순위 순)

#### C-1. `refactor/jira-batch-create-ux` (F-3 포함)

`jira-create/jira-batch-create.body.md`에 SDD 경로 확보 + 템플릿 매칭 흐름을 신설한다.
기존 `jira-batch-create-setup` 스킬의 등록 로직(Step 2~5)을 본문에 인라인 흡수.

- [ ] **Step A-1**: SDD 파일 경로 확보
  - `$ARGUMENTS`에 경로 있으면 그대로 사용
  - 없으면 AskUserQuestion으로 경로 수집
  - 파일 존재/읽기 가능 검증 (실패 시 재입력)
- [ ] **Step A-2**: 템플릿 매칭 판정
  - `{{CONFIG_DIR}}/jira-sdd-templates.yml` 로드
  - 각 템플릿의 `match` 문자열과 SDD 첫 H1 비교 (기존 로직 재사용)
  - 매칭 있음 → "'{템플릿명}' 템플릿으로 파싱합니다" 안내 후 본 흐름 진입
  - 매칭 없음 (파일 자체 없음 포함) → A-3 진입
- [ ] **Step A-3**: 이 파일을 샘플로 신규 템플릿 생성
  - AskUserQuestion: `[생성 / 중단]`
  - "중단" 선택 시 **스킬 즉시 종료**
  - "생성" 선택 시 기존 `jira-batch-create-setup` Step 2~5 로직 흡수:
    - 템플릿 이름 입력(이름 충돌 시 덮어쓰기 확인)
    - 파싱 규칙 자동 생성 및 초안 제시
    - 저장
  - 저장된 템플릿으로 본 흐름 바로 진입 (A-2 재진입 없음)
- [ ] **스킬 개명**: `jira-batch-create-setup` → `jira-batch-templates`
  - 포지션: 명시적 템플릿 CRUD 진입점(목록/수정/삭제)
  - 파일 rename: `jira-batch-create-setup.{body.md,claude.yml,codex.yml}` → `jira-batch-templates.{body.md,claude.yml,codex.yml}`
  - `scripts/build-skills.sh`의 `SKILLS` 배열 갱신
  - description 문구도 "등록" → "관리" 뉘앙스로 조정
- [ ] **(기존 P1 UX)**: #1 테이블 짤림 해결(post-test-findings 추천 C+D), #3 원클릭 설치 설계

#### C-2. `chore/jira-batch-create-safety`

- [ ] #6 parent 타입 주석
- [ ] #10 validate_only 강제
- [ ] #11 이전 승인 재사용 (`--yes` 등)
- [ ] #9는 A와 겹치므로 A 머지 후 잔여만 보완

#### C-3. `fix/jira-create-align-with-batch`

- [ ] 단건 `jira-create.body.md`에도 동일 P0 패턴 적용 (currentUser 의존, 한국어 타입 맵)
- [ ] hub 정비(A)를 공유하므로 A 머지 후 착수 권장

상세는 `post-test-findings.md` 참조.

### D. 로컬 stale 브랜치 정리 (선택)

- [ ] `feat/project-scoped-config` 삭제
- [ ] `fix/jira-batch-create-critical` 삭제
- [ ] `refactor/jira-batch-create-auto-first` 삭제

원격에는 동일 브랜치들이 남아 있으니 함께 정리하려면 `git push origin --delete <name>`.

### E. 미리보기에서 리스트 다시 조회 명령 추가 (신규 피드백)

- [ ] AskUserQuestion 환경: (C) 선택지에 "리스트 다시 보기" 추가 또는 (C-1) 변형으로 흡수
- [ ] Codex 환경: `리스트` 또는 `목록 다시` 자연어 명령을 (C) 도입부 명령 매핑 표에 추가
- [ ] 본문 수정 위치: `jira-batch-create.body.md` Step 4 (C) 도입부 + (C-?) 신설
- [ ] 대상 브랜치 후보: `refactor/jira-batch-create-ux`(설계 결정 동반) 또는 별도 small fix

배경: 현재 (C-1) "특정 이슈 보기"는 단건만 지원. 미리보기 단계에서 (A) 계층 요약 테이블 전체를
다시 보고 싶다는 요구가 들어옴.

### G. 진행률 로그에 티켓번호+타입 표기 (신규 피드백)

- [ ] Phase A 메시지 템플릿 수정: `✅ Epic {KEY} ({타입한국어}) 생성 완료 (1/1)` (Phase 이름과 타입이 중복되므로 메시지 형식 정리 필요)
- [ ] Phase B 메시지 템플릿 수정: `✅ {KEY} ({타입한국어}) 후처리 완료 ({n}/{N})`
- [ ] Phase C 메시지 템플릿 수정: `✅ {KEY} ({타입한국어}) 생성 완료 ({n}/{N})`
- [ ] 본문 수정 위치: `jira-batch-create.body.md` Step 5-2/5-3/5-4 메시지 템플릿
- [ ] 대상 브랜치 후보: `chore/jira-batch-create-safety`에 묶거나 단독 fix

배경: 현재 `✅ JST-86 후처리 완료 (1/14)` → 어떤 이슈 타입인지 한 눈에 안 보임.

---

## 합의 완료

### F. config/템플릿 진입 개선 (2026-04-23 합의)

원래 "A의 0-0a에서 잘못된 key를 `(none)`으로 강등할지"로 시작된 논의가
**config 진입 UX + setup 스킬 통합 범위**까지 확장되어 아래와 같이 결론됨.

#### 최종 결정

| 영역 | 결정 | 근거 |
|------|------|------|
| config 키 오류 복구 | **F-2 채택** — 슬롯별 재지정, `{{CONFIG_PATH}}` 영속화 | 세션 중 복구 가능. 0-1 슬롯 블록 재사용으로 분량 증가 최소 |
| config 확인 UX | **사용자 주도 확인 스텝(0-0b) 신설** | config 값 가시성 확보. "진행 vs 수정" 명시 선택권 |
| 항목별 수정 | **0-0c 신설 — 복수 선택 UI** | 수정 시 전체 재입력 없이 필요한 슬롯만 |
| batch 템플릿 진입 | **F-3 채택 + 템플릿 스킬 유지 개명** | 첫 실행 진입장벽 제거하되 편집 진입점은 별도 유지 |
| `jira-create-setup` | **변경 없음** | config 편집 진입점으로 유지 |
| `jira-batch-create-setup` | **`jira-batch-templates`로 개명** | CRUD 관리 진입점 포지션을 이름에 반영 |

#### F-2/F-3 구체 흐름

**hub.body (F-2)**:
```
0-0 config 로드
 ├─ 없음/미설정 → 0-1 전체 지정(기존) → 저장 → 본문
 └─ 있음 → 0-0b 현재 설정 확인
          ├─ "수정" → 0-0c 항목별 선택 → 슬롯별 0-1 재실행 → 저장 → 0-0b 복귀
          └─ "진행" → 0-0a 자동 키 검증
                    ├─ 유효 → 본문
                    └─ 오류 → [재지정 / 비활성화 / 중단]
                             "재지정" 시 해당 슬롯만 0-1 → 저장 → 본문
```

**jira-batch-create.body.md (F-3)**:
```
Step A-1 SDD 파일 경로 확보 ($ARGUMENTS or 질문 + 유효성 검증)
Step A-2 템플릿 매칭 판정 (templates.yml의 match 문자열)
          ├─ 매칭 있음 → 본문 진입
          └─ 매칭 없음 → A-3
Step A-3 이 파일을 샘플로 신규 템플릿 생성
          [생성] → 이름 입력 → 파싱 규칙 자동 생성 → 저장 → 본문 진입
          [중단] → 스킬 종료
```

#### 왜 F-4가 아닌가

`jira-create-setup` / `jira-batch-templates`를 완전히 없애는 F-4는 기각.
생성 스킬 본문 안에 인라인 흡수해도 **"지금 내 설정/템플릿이 뭔지 확인·편집하고 싶다"**는
요구는 별도 진입점이 필요함. 본문 비대화 + 관리 창구 소실 비용이 크다.

#### 합의된 작업 할당

- A 브랜치 → 0-0a/0-0b/0-0c 신설 (위 **A 섹션** 체크리스트)
- `refactor/jira-batch-create-ux` → A-1/A-2/A-3 + 스킬 개명 (위 **C-1** 체크리스트)
- post-test-findings #2, #4는 이 합의로 해소됨

관련 논의 맥락: post-test-findings #2(batch-setup 분리 타당성), #4(pre-setup 사전 필요성).

---

## 다음 세션 시작 가이드

1. `git status` / `git log --oneline -10`으로 main 위치 확인.
   - `refactor/hub-body-entry-flow` 브랜치가 main에 머지된 상태여야 함. 미머지면 먼저 `git merge --no-ff`로 머지(사용자 명시 승인 후).
2. **A 완료** (2026-04-23). E2E S1~S7 Codex 검증 통과. `hub-body-e2e-codex.md`는 재검증 시 그대로 재사용 가능.
3. 우선순위 추천: **C-1 (`refactor/jira-batch-create-ux`) → C-3 (`fix/jira-create-align-with-batch`) → C-2 (`chore/jira-batch-create-safety`) → B (Codex 미검증 케이스)**
   - C-1에서 `jira-batch-create-setup` → `jira-batch-templates` 개명도 함께 진행.
   - C-3는 hub 변화를 공유하므로 A 머지 이후에만 안전하게 착수.
4. 작업 시작 전 자동 메모리(`~/.claude/projects/-Users-psh-develop-atlassian-skills/memory/`)에서
   `jira_batch_create_review_issues.md` 참고. 15개 리뷰 이슈 중 P0 3건 + A 관련 이슈들은 해결됨, 나머지는 C에 매핑.

---

## 주요 문서 인덱스

- `jira-create/jira-batch-create.body.md` — batch 본문 (4건 보정 반영됨)
- `jira-create/jira-create-hub.body.md` — 공유 hub 본문 (A 작업으로 0-0a/0-0b/0-0c + 0-1 서브루틴 + PROJECT_ID 폴백 체인 반영됨)
- `post-test-findings.md` — 1차 테스트 피드백 12건, P0~P3 분류
- `batch-create-test-workflow.md` — batch 초기 E2E 테스트 절차
- `hub-body-e2e-codex.md` — A 작업 Codex E2E 가이드 (S1~S7 시나리오)
- `/Users/psh/.claude/plans/a-hub-body-flickering-duckling.md` — A 작업 plan
- `/Users/psh/.claude/plans/fix-jira-batch-create-runtime-compat-keen-zephyr.md` — 이전 fix 브랜치 plan

---

## 머지 전략

- 후속 fix/refactor → main 머지: `git merge --no-ff`
- main push 시 권한 프롬프트가 뜨므로 사용자 승인 필요(이번 세션에서 1회 발생)
- 커밋 규약: Conventional Commits + 한국어 subject. `Co-Authored-By` 푸터 없음(작성자 일괄 정정 후 단독 author)
