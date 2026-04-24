# HANDOFF — jira-batch-create 후속 정비

**갱신**: 2026-04-24 · C-1 E2E 전체 통과, main 머지 대기
**브랜치**: `refactor/jira-batch-create-ux` (main 기준 5커밋 + 본 HANDOFF 커밋 예정)
**main 동기화**: `origin/main` = 로컬 `main`

---

## 🎯 지금 이어갈 것

C-1 전 시나리오 통과. 다음 액션:

1. **main 머지** (사용자 승인 후 실행):
   ```bash
   git checkout main
   git merge --no-ff refactor/jira-batch-create-ux
   ```
2. **전역 배포** (Codex + Claude):
   ```bash
   bash scripts/build-skills.sh
   ```
3. **origin push** (사용자 명시 승인 후):
   ```bash
   git push origin main
   ```
4. **로컬 정리**:
   - `~/.agents/jira-sdd-templates.yml` 복구 여부 결정 (현재 `test2` + `sample-other`. `.bak` 존재: `/Users/psh/.agents/jira-sdd-templates.yml.bak`)
   - 배포본 정리(선택): `rm -rf .agents/skills/jira-batch-{create,templates}`
   - `/tmp/sdd-other.md`, `/tmp/sdd-yet-other.md` 삭제(선택)

머지 완료 후 다음 브랜치 선택지는 **📋 후속 작업 체크리스트** 참조. 추천 순서: `E+G` (미리보기 UX polish) → `refactor/jira-batch-probe-defer` → `B` → `C-2`.

---

## 📊 C-1 현재 상태

### 커밋 (main..HEAD)

```
4d91b1b  fix: 1-1 경로 재입력 프롬프트를 0-0b와 분리
b341e20  fix: 템플릿 매칭 안내 출력 강제 + 트리 마커 기준 명확화
e220c92  refactor: 미리보기 테이블을 트리 + 요약 축약 출력으로 전환
7c9bd60  refactor: jira-batch-create-setup → jira-batch-templates 개명
8a7941c  feat: SDD 경로 확보/템플릿 매칭/템플릿 생성 흐름 내장
```

### E2E 진행

| # | 시나리오 | 결과 |
|---|----------|------|
| S1 | 매칭 O 회귀 | ✅ (2차, Fix 후) |
| S2 | 파일 부재 → 신규 생성 | ✅ |
| S3 | 매칭 X → 신규 생성 + 동일 이름 덮어쓰기 | ✅ |
| S4 | 매칭 X → 중단 | ✅ |
| S5 | 경로 재입력 루프 (3회 상한) | ✅ (부분 A·B 모두) |
| S6 | Step 4 트리 출력 | ✅ (S1~S3 공통) |
| S7 | `jira-batch-templates` 자체 동작 | ✅ |
| S5-R | O-1 수정 후 회귀 (부분 A) | ✅ — 0-0b와 1-1 턴 분리 확인 |

### 체크리스트

- [x] Step 1-1/1-2/1-3/1-4 재구성 (`8a7941c`)
- [x] 스킬 개명 (`7c9bd60`)
- [x] P1 UX #1 트리 출력 + 40자 축약 (`e220c92`)
- [x] Fix: 매칭 안내 출력 강제 + 트리 마커 기준 명확화 (`b341e20`)
- [x] O-1 Fix: 1-1 경로 재입력 프롬프트를 0-0b와 분리 (`4d91b1b`)
- [x] ~~P1 UX #3 원클릭 설치~~ — 본 브랜치 제외. 실수요 생기면 GitHub Release + CI 포함 별건.
- [x] E2E S4·S5·S7
- [ ] main 머지
- [ ] 전역 배포 (`scripts/build-skills.sh`)
- [ ] origin push

### E2E 중 발견된 비-버그 관찰

**C-1 범위 내 해소:**
- **O-1 — Step 0-0b와 1-1 경로 재입력 프롬프트 병합** — 수정 전: 사용자 `수정` 응답이 설정 수정 분기로 오인됨. 5턴 소모. 수정 후: 두 질문 독립 턴, 3턴 복구. **`4d91b1b`로 해결, S5-R 회귀 통과.**

**C-1 범위 밖 (후속 주제):**
- **O-3 — Step 0 customfield probe가 1-2 매칭 판정 전에 수행됨**: 중단/취소 경로에서 `jira_search_fields`×3, `jira_search`, `jira_get_issue`, `jira_get_all_projects` 등 7~10회 호출이 낭비됨. 뿌리는 hub 0-0a. 단건/배치 모두 영향. 별건 `refactor/jira-batch-probe-defer`로 분리.
- **O-2 — 3회 상한 종료 문구 자연어 변형**: 본문은 "파일 접근이 계속 실패합니다. 환경을 확인 후 재실행하세요." Codex 렌더는 "스킬 규칙에 따라 여기서 중단합니다." 의미·기능 동일. **수정 불필요, 기록만.**
- **트리 들여쓰기 표기 모호**: 본문은 Sub-task 절대 4스페이스, Codex는 상대 해석(부모+2)으로 2/4/6 렌더. 가독성은 Codex 해석이 더 나음 → 본문 규칙을 "상대 들여쓰기(부모 +2)"로 바꿀지 결정 필요.
- **YAML 스키마 표기법 모호**: 본문 예시는 `{title}`/`{path}` placeholder, Codex 자동 생성은 정규식(`(?P<title>...)`, `([^`]+)`). 기능엔 지장 없지만 표기법 통일 주제.
- **1-3 경로에서 Fix 1 매칭 안내 중복 출력**: 1-3-d 저장 안내 뒤 매칭 안내가 또 나옴. "1-3 경로에선 저장 안내로 대체"를 Fix 1 블록에 명시할 여지.
- **`build-skills.sh`가 개명 후 구 디렉토리 청소 안 함**: 세션 초기에 `.agents/skills/jira-batch-create-setup/` 수동 `rm -rf` 필요했음 → `chore/build-cleanup-renamed` 후보.

### 테스트 중 남은 로컬 상태

- `~/.agents/jira-sdd-templates.yml`: `test2` + `sample-other` (S2/S3에서 Codex가 생성). 원본 `team-sdd`는 사전 백업 실패로 복구 대상 없음. `.bak`은 비어있던 Apr 23 17:41:53 상태.
- `~/.agents/sprint-workflow-config.md`: S5 테스트에서 무변경 확인 (`diff`로 `.bak`과 동일).
- `/tmp/sdd-other.md`, `/tmp/sdd-yet-other.md`: 테스트 픽스처. 삭제 선택.
- 프로젝트 scope 배포본(`.agents/skills/jira-batch-*`): 머지 후 정리 또는 유지 (정리 시 다음 테스트 전에 재배포 필요).

---

## 📋 후속 작업 체크리스트

우선순위 순. 상세는 `post-test-findings.md`·E2E 관찰 참조.

### 📌 추천 우선순위 (C-1 머지 후)

1. **E+G** (미리보기 UX polish) — 실사용 혜택 큼, 범위 좁음
2. **`refactor/jira-batch-probe-defer`** (O-3) — 성능/비용 절감, hub 수정 + 단건 회귀 필요
3. **B** (Codex 축약형 검증) — 기존 기능 회귀 검증
4. **C-2** (safety net) — 안전장치 다발
5. **C-3** (단건 정합화) — 단건 사용 빈도가 낮으면 후순위

### B. Codex 축약형 미검증 2건 (독립 fix)

- [ ] `수정 7 priority=High sp=5` 축약형이 필드 선택 대화 없이 priority/sp를 👤로 즉시 갱신하는지
- [ ] `수정 7 parent=#1` 수정 불가 필드 거절 동작
- 문제 발견 시 별도 fix 브랜치

### C-2. `chore/jira-batch-create-safety`

- [ ] post-test-findings #6 parent 타입 주석
- [ ] #10 `validate_only` 강제
- [ ] #11 이전 승인 재사용 (`--yes` 등)
- [ ] #9 중 A와 안 겹치는 잔여만

### C-3. `fix/jira-create-align-with-batch`

- [ ] 단건 `jira-create.body.md`에도 동일 P0 패턴 적용 (currentUser, 한국어 타입 맵)
- [ ] A 머지 이후 착수

### E+G. `refactor/jira-batch-preview-polish` — 미리보기/로그 출력 개선

C-1 머지 후 착수. 둘 다 `jira-batch-create.body.md` 출력 UX 범주. 1브랜치 2커밋.

**커밋 1 — 미리보기 "리스트 다시 보기" (E)**
- [ ] AskUserQuestion 환경: (C) 선택지에 "리스트 다시 보기" 추가
- [ ] Codex 환경: `리스트` / `목록 다시` 자연어 명령을 (C) 명령 매핑 표에 추가
- [ ] 선택 시 (A) 계층 요약 트리만 재출력 → (C) 재질문
- [ ] 위치: `jira-batch-create.body.md` Step 4 (C) 도입부 + (C-?) 신설
- 배경: 현재 (C-1) "특정 이슈 보기"는 단건만. 14건 규모에서 전체 트리를 다시 보고 싶다는 요구.

**커밋 2 — Phase A/B/C 진행률 로그에 키+타입 병기 (G)**
- [ ] `✅ {KEY} ({타입한국어}) 후처리 완료 ({n}/{N})` 식으로 메시지 템플릿 재작성
- [ ] Phase 이름과 타입이 중복되는 경우 중복 제거
- [ ] 위치: `jira-batch-create.body.md` Step 5-2/5-3/5-4
- 배경: 현재 `✅ JST-86 후처리 완료 (1/14)` → 어떤 이슈 타입인지 한 눈에 안 보임.

**E2E**: 축소판 `polish-e2e-codex.md` 작성.
- S1: 매칭 O 미리보기 → `리스트` 입력 → (A) 재출력 확인
- S2: 실제 생성 1건(샌드박스) → Phase A/B/C 로그에 키+타입 병기 확인

### `refactor/jira-batch-probe-defer` — customfield probe 이연 (O-3)

**배경**: hub `0-0a` customfield 검증이 Step 1-2 매칭 판정 전에 수행 → 중단/취소/재입력 경로에서 probe 7~10회 전량 낭비. C-1 S4/S5/S7 세 시나리오 모두에서 관찰.

**수정 설계 후보** (둘 중 택1, 설계 필요):
- **A — 세션 내 이연**: 0-0a probe를 "생성 직전"(batch: Step 4 미리보기 이후 사용자 `생성` 확정 시점 / 단건: `jira_create_issue` 호출 직전)으로 이동. 실패 시 현 세션은 안전 종료.
- **B — config 캐시**: 0-0a 결과를 `sprint-workflow-config.md`에 `last_validated_at: <ISO>` 기록. N시간(예: 24h) 이내면 스킵. 실패 사례도 캐시.

**수정 범위**: hub `jira-create-hub.body.md` 0-0a 블록 재작성. 단건/배치 본문에 "probe 트리거 지점" 명시 필요.

**E2E 필요**:
- [ ] hub 진입 → probe 스킵 확인 (중단 경로)
- [ ] batch 실제 생성(샌드박스 JST) → Step 4 사용자 `생성` 응답 시점에 probe 1회 수행 확인
- [ ] 단건 `jira-create` 생성 1건 → probe 위치 검증
- [ ] 잘못된 customfield로 config 손상 → probe 실패 메시지 정상 노출

### 신규 (E2E 관찰에서 도출)

- [ ] **`chore/build-cleanup-renamed`** — `scripts/build-skills.sh`에 개명 후 구 디렉토리 자동 청소 로직 추가
- [ ] **트리 들여쓰기 규칙 결정** — 절대(현재 본문) vs 상대(Codex 해석). 선택 후 본문 정합화
- [ ] **YAML 스키마 표기법 통일** — placeholder vs 정규식 중 공식 표기 결정, 본문 예시 재작성
- [ ] **Fix 1 매칭 안내 중복 출력 해소** — 1-3 경로에서 `✅ 저장했습니다` 뒤에 `템플릿 X과 매칭되었습니다`가 또 나옴. Fix 1 블록에 "1-3 저장 후엔 매칭 안내 생략, 저장 안내가 대체" 명시. 위치: `jira-batch-create.body.md` 1-2 매칭 안내 출력 강제 블록

---

## 📚 참조

### 문서

- `jira-create/jira-batch-create.body.md` — batch 본문 (C-1 반영)
- `jira-create/jira-batch-templates.body.md` — 개명 후 템플릿 편집 스킬 본문
- `jira-create/jira-create-hub.body.md` — 공유 hub (A 반영: 0-0a/0-0b/0-0c + 0-1 서브루틴 + PROJECT_ID 폴백)
- `batch-ux-e2e-codex.md` — C-1 E2E 가이드 (전 시나리오 통과)
- `hub-body-e2e-codex.md` — A 작업 E2E 가이드
- `post-test-findings.md` — 1차 테스트 피드백 12건
- `batch-create-test-workflow.md` — batch 초기 E2E 절차

### 자동 메모리

- `~/.claude/projects/-Users-psh-develop-atlassian-skills/memory/MEMORY.md` — 인덱스
- `e2e_test_pattern.md` — Codex 자연어 입력 관례, 실패 보고 4종
- `jira_batch_create_review_issues.md` — 15개 리뷰 이슈

### Plan 파일

- `/Users/psh/.claude/plans/structured-zooming-glacier.md` — C-1
- `/Users/psh/.claude/plans/a-hub-body-flickering-duckling.md` — A
- `/Users/psh/.claude/plans/fix-jira-batch-create-runtime-compat-keen-zephyr.md` — 이전 fix

---

## 🗓 완료된 작업 로그 (요약)

상세는 `git log`.

- **2026-04-24** C-1 E2E S4/S5/S7 통과 + O-1 fix(`4d91b1b`) + 회귀 통과. 머지 대기.
- **2026-04-23** A 완료 — `refactor/hub-body-entry-flow` 7커밋 main 머지, E2E S1~S7 통과
- **2026-04-23** `fix/jira-batch-create-runtime-compat` main 머지 (`77bf8ca`) — 런타임 정합성 4건 보정
- **2026-04-23** `refactor/jira-batch-create-auto-first` main 머지 (`9b84595`) — P0 fix 3건 검증 완료
- **2026-04-23** 저장소 작성자 일괄 정정(30커밋) + force push — `seunghun_park2` → `Phodol2`
- **2026-04-23** 로컬 stale 브랜치 정리 — `feat/project-scoped-config`(원격 보존), `fix/jira-batch-create-critical`(삭제), `refactor/jira-batch-create-auto-first`(삭제)

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

**왜 F-4(완전 제거) 기각**: 생성 스킬 본문에 인라인 흡수해도 "지금 내 설정/템플릿이 뭔지 확인·편집하고 싶다"는 요구는 별도 진입점 필요. 본문 비대화 + 관리 창구 소실 비용이 큼.

관련 post-test-findings #2, #4는 이 합의로 해소.

---

## 🔧 커밋·머지 규약

- 커밋: Conventional Commits + 한국어 subject. `Co-Authored-By` 푸터 없음.
- 머지: `--no-ff`. push는 사용자 명시 승인 후.
- 1커밋 = 1논리변경. 여러 스킬 동시 수정 시 스킬별로 분리.
