# HANDOFF — jira-batch-create 후속 정비

**갱신**: 2026-04-27 · P 시리즈(P1 / P2+P3+P5 / P0) + C-3·S5 + jira-create-setup 폐기(hub 0-1 흡수) 머지 완료. 후속 1주기 종료.
**브랜치**: `main` (작업 깨끗). P 머지 산출물 브랜치 + C-3 브랜치 + setup 폐기 브랜치(`refactor/jira-create-setup-absorb-to-hub`)는 머지 완료 상태로 로컬 보존.
**main 동기화**: `origin/main`(`d49384c`)보다 **13커밋 앞섬** = P 시리즈 6 + C-3 2 + setup 폐기 2(머지 1 + refactor 1) + HANDOFF docs 3.
**배포 방침**: 사용자 방침 — **"한번에 배포"**. push/전역 배포는 다음 브랜치까지 누적 후 한 번에.

---

## 🎯 지금 이어갈 것

**P 시리즈 + C-3 종료 후 보류 / 후속 트랙**:

- **P4 (보류)** — `(C-1)~(C-5)` 매트릭스 축소. 만약 진행 시 `수정 N field=value`·`리스트/목록 다시`만 제거 (보기 N은 유지). 사용 빈도 월 1~2회 기준 재학습 비용 고려해 보수.
- **F1 (후속, 빈도 누적 2회)** — codex destructive_hint 안전 가드 인터럽트 완화. P1 회귀 + C-3 v2 회귀 S2에서 각 1회 관찰. → `followup_codex_safety_guard.md`
- **F2 (후속)** — codex 환경 quote 형식 메시지 미출력 패턴. P2+P3+P5 회귀 중 발견. F1과 묶어 검토. → `followup_codex_message_format.md`
- **F3 (후속, 신규)** — description 백틱이 Jira wiki 마크업으로 변환되는 현상 (`{{...}}` 표기). C-3 v2 회귀 S3에서 관찰. 본문에 description 작성 시 백틱 사용 주의 가드 추가 검토. → `followup_jira_description_backtick.md`

**기존 후보 (배치 중심)**:

1. **트리 들여쓰기 규칙 결정** — 절대/상대/소실 3가지 편차 중 하나로 본문 통일
2. **YAML 스키마 표기법 통일** — placeholder vs 정규식
3. **Fix 1 매칭 안내 중복 출력 해소** — 1-3 저장 경로
4. **`chore/build-cleanup-renamed`** — 개명 후 구 디렉토리 자동 청소
5. **C-2 #11 --yes 승인 재사용** (`feat/jira-batch-reuse-approval`) — 배치 재실행 UX

누적 push + 전역 배포는 다음 정비 일단락 후 검토.

---

## 📊 현재 상태

### 로컬 main 미push 커밋 (origin/main..main, 13건)

setup 폐기(2026-04-27, hub 0-1 흡수) — 2커밋:

```
b2dd630  Merge branch 'refactor/jira-create-setup-absorb-to-hub'   ← setup 폐기 머지
cfd9023  refactor(jira-create): jira-create-setup 스킬을 hub 0-1로 흡수해 폐기
```

C-3(2026-04-27, 단건 정합화 + S5 보류 회귀) — 2커밋:

```
04183d7  Merge branch 'fix/jira-create-align-with-batch'           ← C-3 머지
9b2e354  fix(jira-create): 단건에 ISSUE_TYPE_MAP 이식 + 호출 시점 가드/Sub-task parent 정합화 (C-3)
```

P 시리즈(2026-04-27, 외부 리뷰 기반 정비 1주기) — 6커밋:

```
c45afdc  Merge branch 'docs/readme-roadmap'                        ← P0 머지
ca6a553  Merge branch 'refactor/jira-batch-doc-compress'           ← P2+P3+P5 머지
008dd9e  Merge branch 'fix/jira-assignee-fallback'                 ← P1 머지
8266449  docs(jira-create): 고도화 로드맵 분리 + 우선순위 표 모순 수정 (P0)
99a6b57  refactor(jira-create): 본문 압축 — 진행률 규약 통합·origin 메타 정화 (P2/P3/P5)
2abbb6d  fix(jira-create,jira-batch-create): assignee 미식별 시 unassigned fallback (P1)
```

이전 누적(2026-04-24, O-3 묶음) — 7커밋:

```
3030197  Merge branch 'refactor/jira-batch-probe-defer'            ← O-3 머지
967b0e8  fix(jira-create-hub,batch,single): 재지정 UI 강제 2차 + 재확인 게이트 추가 (O-12/O-13)
0a47f2b  fix(jira-create-hub): 0-0a probe 단일 호출 + 재지정 UI 강제 (O-11/O-12)
b95b636  docs: O-11 기록 추가 (O-3 E2E S2 회귀 중 발견)
1957d0b  refactor(jira-create): Step 6 진입 직전 probe 호출 추가 (O-3)
726354f  refactor(jira-batch-create): Step 4 (C-3) 확정 직후 probe 호출로 이연 (O-3)
d204bc8  refactor(jira-create-hub): 0-0a probe를 지연 실행 서브루틴으로 재정의 (O-3)
```

### 완료된 개선 (영역별)

| 영역 | 상태 | 비고 |
|------|------|------|
| C-1: UX 재구성 | ✅ 완료 | 머지 `900aca4`. E2E S1~S7 통과 |
| E+G: 미리보기 polish | ✅ 완료 | 머지 `f0f34ba`. S1 통과, G는 실사용 때 확인 예정 |
| O-7: 증거 placeholder | ✅ 완료 | `0a0cbcd`. 회귀 PASS |
| O-8: 번호 매김 DFS | ✅ 완료 | 머지 `224838a`. 실 생성 회귀 PASS |
| B: Codex 축약형 2건 | ✅ 검증 | 문제 없음 |
| C-2 #10: validate_only 강제 | ✅ 완료 | `91540e8`. 실 생성 회귀 PASS (2단계 호출 확인) |
| C-2 #6: parent 문자열 키 | ✅ 완료 | `5b8f59b`. 실 생성 회귀 PASS (모든 parent가 문자열) |
| C-2 #9: customfield scope | ✅ 기해소 | A 브랜치에서 처리 |
| C-2 #11: --yes 승인 재사용 | ⏸️ 유예 | 설계 규모, 별건 `feat/jira-batch-reuse-approval` |
| O-9: Phase 로그 생략 재-강제 | ✅ 완료 | 머지 `f432ce1`. 본문에 "출력 지시 (생략 금지)" 가드 추가. 실사용 때 효과 관찰 예정 |
| O-6: 트리 마커 기준 결정 | ✅ 완료 | 머지 `9afa4b2`. 옵션 C(트리 마커 폐기) 채택. 필드 출처는 (B-1)에서만 확인 |
| O-3: Step 0 probe 이연 | ✅ 완료 | 머지 `3030197`. 지연 실행 서브루틴 + 세션 플래그로 재호출 차단. E2E S1~S4 PASS. **S5 단건 회귀는 C-3 v2 회귀(2026-04-27)에 동봉되어 PASS** — 단건 0-0a 지연 호출 1회 보장 확인. |
| O-11: probe keyword 분할 호출 | ✅ 완료 | fix `0a47f2b`. `keyword` 없이 `limit: 200`으로 1회. S3 재테스트에서 1회 확인 |
| O-12: 재지정 UI 스킵·sed 치환 | ✅ 완료 | fix `0a47f2b` + `967b0e8`. Read+Write 외 저장 도구 금지, "재수집하시겠습니까?" 선행 질문을 0-0a 재지정에도 적용 |
| O-13: 재지정 후 자동 생성 | ✅ 완료 | fix `967b0e8`. 0-0a 반환값 3가지(통과/재지정/중단) + 호출 측 재확인 게이트("설정이 변경됐습니다 … 이어갈까요?") 신설 |
| **P1**: assignee 강제 차단 → unassigned fallback | ✅ 완료 | 머지 `008dd9e` (`2abbb6d`). 단건/배치 통일, jira_get_user_profile 추가 호출 제거. E2E 4/4 PASS. 기존 메모리 4번 항목 함께 해소. |
| **P2+P3+P5**: 본문 압축 / 진행률 규약 통합 / origin 메타 정화 / templates 톤 정리 | ✅ 완료 | 머지 `ca6a553` (`99a6b57`). jira-batch-create.body.md 842 → 823줄. E2E 4/4 (S4는 보조 PARTIAL). |
| **P0**: README 로드맵을 ROADMAP.md로 분리 + 우선순위 표 모순 수정 | ✅ 완료 | 머지 `c45afdc` (`8266449`). README 438 → 329줄. /jira-create-setup Mermaid 다이어그램 제거 + 본문 설명 참조 인용구로 대체. |
| **C-3 + S5**: 단건 ISSUE_TYPE_MAP 이식 + 호출 시점 가드 + Sub-task parent 정합화 | ✅ 완료 | 머지 `04183d7` (`9b2e354`). jira-create.body.md 313 → 369줄. v2 회귀 PASS (JST-132/133/134). C-3 두 번째 항목(assignee currentUser 패턴)은 P1에서 이미 이식됨. S5(O-3 단건 회귀) 동시 검증 — 0-0a 지연 호출 1회 보장. F1 safety guard 1회 추가 관찰. |
| **setup 폐기**: jira-create-setup 스킬을 hub 0-1로 흡수해 별도 진입점 제거 | ✅ 완료 | 머지 `b2dd630` (`cfd9023`). hub 0-1에 SLACK + DEFAULTS 신규(slack_get_users 자동 변환 포함). setup body 159줄 + yml 2개 + 빌드 등록 + 배포 산출물 4종 청소. v3 가드 보강(6단계 분리·역추정 채택 금지·키워드 분할 금지·Bash heredoc 금지). 1차 회귀 S2에서 0-1-SLACK 자동 변환 검증 후 (B) 옵션으로 머지. F4 신규 등록(0-1 모델 행동 가드 약점). |

### 실 생성 회귀 결과 (2026-04-24)

5건 fixture (JST-103~107)로 Phase A→B→C 전체 경로 확인. 검증 통과 후 JST 5건 삭제 완료.

| 항목 | 결과 |
|------|------|
| Phase B `validate_only: true` 호출 관찰 | ✅ 명시적으로 2단계 호출 발생 |
| Phase C parent 문자열 키 | ✅ `"JST-105"` 그대로 전달 |
| O-8 DFS 번호 매김 | ✅ `#1 Epic → #2 Task → #3 Story → #4/#5 Sub-task` |
| Phase 로그 메시지 (G) | ❌ Codex가 `🟢/✅` 진행률 메시지 **전부 생략** — **O-9 신규 관찰** |
| Slack DM (Step 6) | ✅ 정상 전송 |

### O-3 E2E 회귀 결과 (2026-04-24, batch 범위)

14건 fixture(test-sdd.md → JST-108~121)로 S2 풀 생성 검증 + 삭제 완료. 나머지는 probe/분기 관찰로 실 생성 최소화.

| 시나리오 | 결과 | 핵심 검증 |
|---|---|---|
| S1 중단 경로 | ✅ | `jira_search_fields` 0회 |
| S2 정상 생성 | ✅ | probe 1회 + Phase A/B/C 완주 (14건 생성/삭제) — O-11 부차 관찰로 연결 |
| S3 재지정 (2차) | ✅ | 1회 probe + UI 흐름 전체 + 재확인 게이트 — O-11/O-12/O-13 전부 해결 확인 |
| S4 멱등 | ✅ | 수정 루프 2회 + 보기 1회 후에도 probe 총 1회 (세션 플래그 동작) |
| S5 단건 | ⏭ 스킵 | batch 관점 범위 밖 (단건 본문 수정은 포함, 회귀는 미실시) |

---

## 🔍 발견 관찰 (후속 주제)

### 해결됨

- **O-1**: hub 0-0b와 1-1 프롬프트 병합 → `4d91b1b`
- **O-7**: 트리 증거 placeholder literal 누수 → `0a0cbcd`
- **O-8**: 트리 번호 매김 규칙 미명시 → `c3c13b3`
- **O-9**: Phase A/B/C 진행률 메시지 생략 → `f9ef9b4` (본문 강화, 실사용 관찰 예정)
- **O-6**: 트리 마커 기준 모델별 편차 → `2ec7859` (옵션 C 채택, 트리 마커 폐기)
- **O-3**: Step 0 customfield probe 낭비 → 머지 `3030197` (지연 실행 서브루틴 + 세션 플래그)
- **O-11**: 0-0a probe keyword 분할 호출 → fix `0a47f2b` (`keyword` 없이 `limit: 200` 1회 강제)
- **O-12**: 재지정 UI 스킵·`sed`/`perl` 직접 치환 → fix `0a47f2b` + `967b0e8` (Read+Write 외 저장 도구 금지, 재수집 선행 질문 확장)
- **O-13**: 재지정 후 사용자 재확인 없이 자동 생성 → fix `967b0e8` (반환값 3가지 + 호출 측 재확인 게이트)

### 기록만 (수정 불필요)

- **O-2**: 3회 상한 종료 문구 자연어 변형 (기능 동등)
- **O-4**: Codex `gpt-5.5` "Model Set Context" 덤프 (OpenAI quirk, 본문 무관)

### 미해결 (후속 브랜치 대상)

- **트리 들여쓰기 규칙 모호**: 본문은 절대(Epic 0 / PBI 2 / Sub-task 4), Codex는 세션에 따라 상대(부모+2) 또는 **0 들여쓰기(완전 소실)** — 3가지 편차
- **YAML 스키마 표기법 모호**: placeholder(`{title}`) vs 정규식
- **1-3 저장 후 매칭 안내 중복 출력**
- **`build-skills.sh` 개명 청소 누락**
- **Phase A↔B 호출 경계 섞임 (신규 부차 관찰)**: 실 생성 중 Epic 호출 3(description)이 Phase B validate_only보다 **이후** 실행됨. 기능 문제 없으나 본문 Phase 경계 순서 규약과 불일치. 참고 기록
- **O-14 (기록만)** Codex `Edited`/`apply_patch` 내장 편집 도구 허용 여부 명시 필요. 2차 fix에서 `Read + Write`만 허용했는데 Codex가 `Edited` diff 도구로 저장 (Bash 치환 우회 없음). 본질 정신은 준수하나 문구 엄격 해석 시 위반. 필요하면 본문에 "Codex 내장 구조적 편집(`Edited`/`apply_patch`)은 Read+Write의 축약으로 간주해 허용"을 명시.
- **F1 (빈도 누적 2회)**: codex destructive_hint 안전 가드 인터럽트. P1 회귀(S1-배치) + C-3 v2 회귀(S2-Sub-task)에서 각 1회 차단 발생. 누적 빈도가 분기 누적 2회로 늘어남 — 우선순위 재평가 후보. → 메모리 `followup_codex_safety_guard.md`
- **F2**: codex 환경 quote 형식 메시지 미출력. P2+P3+P5 회귀(S1) 중 본문의 `> 🟢 …` 양식이 자체 진행 안내로 대체됨. F1과 묶어 codex 환경 작업 1주기로 검토 가치. → 메모리 `followup_codex_message_format.md`
- **F3 (신규)**: description 백틱이 Jira wiki 마크업으로 변환 (`` `jira-create` `` → `{{jira-create}}`). C-3 v2 회귀 S3에서 관찰. 본문에 description 작성 시 백틱 사용 주의 가드 추가 검토. → 메모리 `followup_jira_description_backtick.md`
- **F4 (신규)**: hub 0-1 모델 행동 가드 약점. setup 폐기 1차 회귀에서 4건 발견(키워드 분할 호출, JST-XXX 역추정 자동 채택, Bash heredoc 사용, 0-1-DEFAULTS 자동 추정). v3 가드 보강(6단계 분리·역추정 채택 금지·키워드 분할 금지·Bash heredoc 금지)으로 차단 시도. 다음 실 사용에서 자연 검증 + 가드가 실효하는지 관찰 필요. → 메모리 `followup_hub_inline_fallback_guards.md`
- **P4**: `(C-1)~(C-5)` 매트릭스 축소 보류. 사용 빈도 월 1~2회 기준 재학습 비용 고려. 진행 시 `수정 N field=value`/`리스트/목록 다시`만 제거 후보, `보기 N`은 유지.

---

## 📋 후속 작업 체크리스트

### 📌 추천 우선순위 (다음 브랜치, 배치 최상)

**배치 관련 — 최상 (전부 `jira-batch-create.body.md` 또는 hub 영향)**:

1. **트리 들여쓰기 규칙 결정** — 🟠 절대 / 상대 / 소실 중 하나로 본문 통일 ← 다음
2. **YAML 스키마 표기법 통일** — 🟠 placeholder vs 정규식
3. **Fix 1 매칭 안내 중복 출력 해소** — 🟠 1-3 저장 경로
4. **`chore/build-cleanup-renamed`** — 🟠 `scripts/build-skills.sh`에 개명 후 구 디렉토리 자동 청소
5. **`feat/jira-batch-reuse-approval`** (C-2 #11) — 🟡 실사용 검증 필요 (플래그 전달 방식)

**단건 관련**:

- (C-3 + S5 회귀 완료 — 잔여 단건 후속 없음)

### C-3 + S5. `fix/jira-create-align-with-batch` (✅ 머지 완료 `04183d7`)

- [x] 단건 `jira-create.body.md`에 batch의 `ISSUE_TYPE_MAP` (Step 2-0 패턴) 이식
- [x] `assignee = currentUser()` 확보 패턴 이식 (Step 2-1) — P1 머지에서 이미 처리, C-3 회귀로 회귀 없음 확인
- [x] 호출 시점 가드 추가 — Step 5 이전 사전 호출 금지, Step 6 진입 후 1회만 (회귀 비결정성 해소)
- [x] Sub-task 호출 1 parent 처리 정정 — MCP 현실 반영, 호출 2 재설정 차단
- [x] 호출 3 Sub-task 분기 — "설명" 입력 시에만 호출, 부모 description 옮김 차단
- [x] 실 회귀: JST 단건 3건 생성 후 삭제 (S1/S2/S3 PASS) + S5 동시 검증 (0-0a 1회 보장)

### O-3. `refactor/jira-batch-probe-defer` (✅ 머지 완료 `3030197`)

옵션 A(세션 내 이연) 채택. Step 4 (C-3) 확정 직후 / 단건 Step 5 확인 직후에서 hub 0-0a 지연 실행 서브루틴 호출. 세션 플래그 `customfield_probe_passed`로 재호출 차단. 회귀 중 발견한 O-11/O-12/O-13도 본 브랜치에서 동시 해결.

### C-2 #11. `feat/jira-batch-reuse-approval`

- [ ] `$ARGUMENTS`에 `--yes` / `--reuse-last-approval` 파싱
- [ ] Step 4 게이트 조건부 스킵 로직
- [ ] Claude Code/Codex 각각에서 플래그 전달 방식 검증

### 기타 UX 체크리스트

- [ ] **`chore/build-cleanup-renamed`** — `scripts/build-skills.sh`에 개명 후 구 디렉토리 자동 청소
- [ ] **트리 들여쓰기 규칙 결정** — 절대 / 상대 / 명시 안 함 (Codex 자유) 중 택1 + 본문 정합화
- [ ] **YAML 스키마 표기법 통일** — placeholder vs 정규식
- [ ] **Fix 1 매칭 안내 중복 출력 해소** — 1-3 저장 경로

---

## 📚 참조

### 문서

- `jira-create/jira-batch-create.body.md` — batch 본문 (C-1 + E+G + C-2 + O-8 반영)
- `jira-create/jira-batch-templates.body.md` — 개명 후 템플릿 편집 스킬 본문
- `jira-create/jira-create-hub.body.md` — 공유 hub
- `batch-ux-e2e-codex.md` — C-1 E2E 가이드 (untracked 로컬 유지)
- `polish-e2e-codex.md` — E+G E2E 가이드 (untracked 로컬 유지)
- `hub-body-e2e-codex.md` — A 작업 E2E 가이드
- `probe-defer-e2e-codex.md` — O-3 E2E 가이드 (untracked 로컬 유지)
- `post-test-findings.md` — 1차 테스트 피드백 12건

### 자동 메모리

- `~/.claude/projects/-Users-psh-develop-atlassian-skills/memory/MEMORY.md` — 인덱스
- `e2e_test_pattern.md` — Codex 자연어 입력 관례
- `jira_batch_create_review_issues.md`

### Plan 파일

- `/Users/psh/.claude/plans/structured-zooming-glacier.md` — C-1
- `/Users/psh/.claude/plans/a-hub-body-flickering-duckling.md` — A
- `/Users/psh/.claude/plans/refactor-jira-batch-probe-defer-wise-conway.md` — O-3

---

## 🗓 완료된 작업 로그 (요약)

- **2026-04-27** setup 폐기 머지 (`b2dd630` ← `cfd9023`) — `jira-create-setup` 스킬을 hub 0-1로 흡수해 별도 진입점 제거. hub 0-1에 0-1-SLACK(slack_get_users 자동 변환) + 0-1-DEFAULTS(우선순위·증거) 신규, 0-1 호출 순서를 PROJECT→SP→AC→EV→SLACK→DEFAULTS→SAVE로 갱신. 0-0c는 0-1-SLACK / 0-1-DEFAULTS로 위임. setup body 159줄 + yml 2개 삭제, SKILLS 배열 정리, 배포 산출물(global+project, claude+codex) 청소. README/CLAUDE.md/scripts/README 정리. 1차 회귀에서 0-1-SLACK 자동 변환 핵심 가치 검증 + 4건 본문 위반 발견 → v3 가드 보강(6단계 분리·역추정 채택 금지·키워드 분할 금지·Bash heredoc 금지·0-1-DEFAULTS 자동 추정 금지) 후 (B) 옵션으로 재회귀 없이 머지. F4 신규 등록.
- **2026-04-27** C-3 + S5 머지 (`04183d7` ← `9b2e354`) — 단건 정합화. Step 6에 ISSUE_TYPE_MAP 단계 신설(batch Step 2-0 이식) + 호출 시점 가드(Step 5 이전 사전 호출 금지) + Sub-task 호출 1 parent 정합화(MCP 필수) + 호출 3 Sub-task 분기. v1 회귀 → 본문 정정 → v2 회귀 PASS(JST-132/133/134, S1/S2/S3). S5(O-3 단건 0-0a 지연 호출) 동시 검증 1회 보장. F1 safety guard 1회 추가 관찰(누적 2회). F3 신규 후속 등록(description 백틱 wiki 변환).
- **2026-04-27** P 시리즈 (외부 리뷰 기반 정비 1주기) 종료
    - **P1** (`008dd9e` ← `2abbb6d`) — assignee 강제 차단 제거 + unassigned fallback. 단건/배치 통일. `jira_get_user_profile` 추가 호출 제거. 결과 리포트에 fallback 경고 1줄. README line 326 표기 정합. 회귀 4/4 PASS (S1-단건/S1-배치 실측 + S2-단건/S2-배치 시뮬). 메모리 `jira_batch_create_review_issues.md` 4번 항목 함께 해소.
    - **P2+P3+P5** (`ca6a553` ← `99a6b57`) — Step 5-1에 진행률 메시지 출력 규약 통합 정의. 5-2/5-3/5-4의 "반드시 출력 / 규약 위반" 강조 반복을 인라인 + "5-1 규약 적용" 참조로 축소. `{타입한국어}` 표기 일관화. Step 2-9 origin 메타 예시 JSON 9줄 블록 → 인라인 예시. Step 5-0 표현 정돈 + Step 7 합산 보고 명확화. jira-batch-templates 헤더에 "(편집 진입점)" 명시. jira-batch-create.body.md 842 → 823줄. 회귀 S1/S2/S3 PASS, S4 PARTIAL (보조 판정).
    - **P0** (`c45afdc` ← `8266449`) — README "고도화 로드맵" 섹션을 별도 `jira-create/ROADMAP.md`로 분리. 완료된 항목/계획된 기능/시너지/우선순위 4개 섹션 구성. 우선순위 표 모순(line 438 "4 \| 일괄 생성") 제거. /jira-create-setup Mermaid 다이어그램 제거 + 본문 설명 참조 인용구로 대체. README 438 → 329줄 (-109줄, 약 25%).
    - **부수 등록**: F1 (codex 안전 가드) / F2 (codex 메시지 양식) 후속 주제 메모리 등록 — P 시리즈 종료 후 별도 트랙. C-3 회귀로 F1 빈도 누적 2회 + F3(description 백틱 wiki 변환) 신규 추가.
    - **회귀 가이드 (모두 정리됨)**: `p1-assignee-fallback-e2e-codex.md`, `jira-batch-doc-compress-e2e-codex.md`, `c3-jira-create-align-with-batch-e2e-codex.md` — 회귀 종료 후 삭제 관습.
- **2026-04-24** O-3 머지 (`3030197`) — 0-0a customfield probe를 지연 실행 서브루틴으로 전환. E2E 회귀 중 O-11(probe keyword 분할)·O-12(재지정 UI 스킵)·O-13(재지정 후 자동 생성) 부차 발견분도 본 브랜치에서 함께 해결. batch 범위 S1~S4 PASS, S5 단건은 스킵.
- **2026-04-24** O-6 머지 (`9afa4b2`) — 트리 origin 마커 폐기 (옵션 C). 모델별 해석 편차 제거, 구조 요약 기능 선명화. 필드 출처는 (B-1)에서만.
- **2026-04-24** O-9 머지 (`f432ce1`) — Phase A/B/C 진행률 메시지 출력 강제. 본문에 "출력 지시 (생략 금지)" 가드 추가. 실사용 때 효과 관찰 예정.
- **2026-04-24** C-2 부분 머지 (`479b430`) — #10 validate_only 강제, #6 parent 문자열 키. 실 JST 5건 회귀 PASS 후 정리.
- **2026-04-24** O-8 머지 (`224838a`) — 트리 번호 매김 DFS 규칙 본문 명시.
- **2026-04-24** E+G 머지 (`f0f34ba`) — 리스트 다시 보기 / Phase 로그 타입 병기 / 증거 placeholder fix.
- **2026-04-24** C-1 머지 (`900aca4`) — E2E S1~S7 통과 + O-1 fix 회귀 통과. 6커밋.
- **2026-04-23** A 완료 — `refactor/hub-body-entry-flow` 7커밋, E2E S1~S7 통과.
- **2026-04-23** `fix/jira-batch-create-runtime-compat` 머지 (`77bf8ca`) — 런타임 정합성 4건.
- **2026-04-23** `refactor/jira-batch-create-auto-first` 머지 (`9b84595`) — P0 fix 3건.
- **2026-04-23** 저장소 작성자 일괄 정정(30커밋) + force push.
- **2026-04-23** 로컬 stale 브랜치 정리.
- **~2026-04-22 초기 구축**
    - Confluence/Jira 스킬 신설: `confluence-fetch` / `confluence-write` / `jira-create` / `jira-batch-create`
    - 빌드 스크립트·프로젝트 규약·CLAUDE.md 정립
    - 아키텍처 기반 결정 (재구성 시 참조):
        - `shared_body` hub 구조 (`31c6285`)
        - jira-batch-create 자동 보강 재설계 (`9fcced3`)
        - Phase C 3단계 체인 확정 (`88d0f92 → af0ab51` — 2단계 최적화 시도 후 ADF 검증 문제로 롤백)
    - 이 구간 이후부터는 브랜치-머지 단위 이력이 `git log --merges --first-parent main`으로 완전 추적됨

---

## 🤝 합의 기록 (F, 2026-04-23)

| 영역 | 결정 |
|------|------|
| config 키 오류 복구 | 슬롯별 재지정, `{{CONFIG_PATH}}` 영속화 (F-2) |
| config 확인 UX | 사용자 주도 확인 스텝 `0-0b` 신설 |
| 항목별 수정 | `0-0c` 신설 — 복수 선택 UI |
| batch 템플릿 진입 | F-3 채택 + 템플릿 스킬 유지·개명 |
| `jira-create-setup` | 변경 없음 (config 편집 진입점 유지) |
| `jira-batch-create-setup` | `jira-batch-templates`로 개명 (CRUD 편집 진입점) |

---

## 🔧 커밋·머지 규약

- 커밋: Conventional Commits + 한국어 subject. `Co-Authored-By` 푸터 없음.
- 머지: `--no-ff`. push는 사용자 명시 승인 후.
- 1커밋 = 1논리변경. 여러 스킬 동시 수정 시 스킬별로 분리.
