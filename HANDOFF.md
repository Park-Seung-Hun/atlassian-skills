# HANDOFF — jira-batch-create 후속 정비

**갱신**: 2026-04-24 · O-3 머지 완료 (+O-11/O-12/O-13 동반 해결). 배치 잔여 정비 진행 중.
**브랜치**: `main` (작업 깨끗)
**main 동기화**: `origin/main`보다 **7커밋 앞섬** (미push; origin/main이 그간 `64e2f68`까지 동기화된 상태 기준)
**배포 방침**: 사용자 방침 — **"한번에 배포"**. push/전역 배포는 다음 브랜치까지 누적 후 한 번에.

---

## 🎯 지금 이어갈 것

**방침**: 배치(`jira-batch-create`) 관련 수정사항을 전부 최상 우선. 단건(`jira-create`) 관련(C-3)은 배치 잔여 정리 후로 유예.

다음 브랜치 후보 (배치 중심, O-3 완료 후):

1. **트리 들여쓰기 규칙 결정** — 절대/상대/소실 3가지 편차 중 하나로 본문 통일 ← 다음
2. **YAML 스키마 표기법 통일** — placeholder vs 정규식
3. **Fix 1 매칭 안내 중복 출력 해소** — 1-3 저장 경로
4. **`chore/build-cleanup-renamed`** — 개명 후 구 디렉토리 자동 청소
5. **C-2 #11 --yes 승인 재사용** (`feat/jira-batch-reuse-approval`) — 배치 재실행 UX

**이후**:
6. **C-3 단건 정합화** — 배치 잔여 전부 정리 후 착수

누적 push + 전역 배포는 배치 정비 일단락 후 검토.

---

## 📊 현재 상태

### 로컬 main 미push 커밋 (origin/main..main, 7건)

```
3030197  Merge branch 'refactor/jira-batch-probe-defer'            ← O-3 머지
967b0e8  fix(jira-create-hub,batch,single): 재지정 UI 강제 2차 + 재확인 게이트 추가 (O-12/O-13)
0a47f2b  fix(jira-create-hub): 0-0a probe 단일 호출 + 재지정 UI 강제 (O-11/O-12)
b95b636  docs: O-11 기록 추가 (O-3 E2E S2 회귀 중 발견)
1957d0b  refactor(jira-create): Step 6 진입 직전 probe 호출 추가 (O-3)
726354f  refactor(jira-batch-create): Step 4 (C-3) 확정 직후 probe 호출로 이연 (O-3)
d204bc8  refactor(jira-create-hub): 0-0a probe를 지연 실행 서브루틴으로 재정의 (O-3)
```

> origin/main 이전 기준(O-6 머지 시점)까지의 누적은 `git log origin/main~17..main` 등으로 조회. 여기에는 최근 O-3 브랜치 작업분만 표기.

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
| O-3: Step 0 probe 이연 | ✅ 완료 | 머지 `3030197`. 지연 실행 서브루틴 + 세션 플래그로 재호출 차단. E2E S1~S4 PASS (S5 단건은 batch 범위 밖으로 스킵) |
| O-11: probe keyword 분할 호출 | ✅ 완료 | fix `0a47f2b`. `keyword` 없이 `limit: 200`으로 1회. S3 재테스트에서 1회 확인 |
| O-12: 재지정 UI 스킵·sed 치환 | ✅ 완료 | fix `0a47f2b` + `967b0e8`. Read+Write 외 저장 도구 금지, "재수집하시겠습니까?" 선행 질문을 0-0a 재지정에도 적용 |
| O-13: 재지정 후 자동 생성 | ✅ 완료 | fix `967b0e8`. 0-0a 반환값 3가지(통과/재지정/중단) + 호출 측 재확인 게이트("설정이 변경됐습니다 … 이어갈까요?") 신설 |

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

- **트리 들여쓰기 규칙 모호**: 본문은 절대(Epic 0 / PBI 2 / Sub-task 4), Codex는 세션에 따라 상대(부모+2) 또는 **0 들여쓰기(완전 소실)** — 3가지 편차 ← 다음
- **YAML 스키마 표기법 모호**: placeholder(`{title}`) vs 정규식
- **1-3 저장 후 매칭 안내 중복 출력**
- **`build-skills.sh` 개명 청소 누락**
- **Phase A↔B 호출 경계 섞임 (신규 부차 관찰)**: 실 생성 중 Epic 호출 3(description)이 Phase B validate_only보다 **이후** 실행됨. 기능 문제 없으나 본문 Phase 경계 순서 규약과 불일치. 참고 기록
- **O-14 (기록만)** Codex `Edited`/`apply_patch` 내장 편집 도구 허용 여부 명시 필요. 2차 fix에서 `Read + Write`만 허용했는데 Codex가 `Edited` diff 도구로 저장 (Bash 치환 우회 없음). 본질 정신은 준수하나 문구 엄격 해석 시 위반. 필요하면 본문에 "Codex 내장 구조적 편집(`Edited`/`apply_patch`)은 Read+Write의 축약으로 간주해 허용"을 명시.

---

## 📋 후속 작업 체크리스트

### 📌 추천 우선순위 (다음 브랜치, 배치 최상)

**배치 관련 — 최상 (전부 `jira-batch-create.body.md` 또는 hub 영향)**:

1. **트리 들여쓰기 규칙 결정** — 🟠 절대 / 상대 / 소실 중 하나로 본문 통일 ← 다음
2. **YAML 스키마 표기법 통일** — 🟠 placeholder vs 정규식
3. **Fix 1 매칭 안내 중복 출력 해소** — 🟠 1-3 저장 경로
4. **`chore/build-cleanup-renamed`** — 🟠 `scripts/build-skills.sh`에 개명 후 구 디렉토리 자동 청소
5. **`feat/jira-batch-reuse-approval`** (C-2 #11) — 🟡 실사용 검증 필요 (플래그 전달 방식)

**단건 관련 — 배치 잔여 후**:

6. **`fix/jira-create-align-with-batch`** (C-3) — 🟡 단건 한국어 Jira 실패 방지. 배치 정비 일단락 후 착수
7. **`fix/jira-create-probe-defer-regression`** (S5 보류 회귀) — 🟡 O-3에서 단건 본문도 수정했으나 회귀 테스트 미실시. 배치 정비 일단락 후 함께 검증.

### C-3. `fix/jira-create-align-with-batch`

- [ ] 단건 `jira-create.body.md`에 batch의 `ISSUE_TYPE_MAP` (Step 2-0 패턴) 이식
- [ ] `assignee = currentUser()` 확보 패턴 이식 (Step 2-1)
- [ ] A(hub)가 공통으로 들어가 있음 — 단건 본문에만 없는 Step 2-X 블록이 대상
- [ ] 실 회귀: JST 단건 1건 생성 후 삭제

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
