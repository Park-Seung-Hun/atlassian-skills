# HANDOFF — jira-batch-create 후속 정비

**갱신**: 2026-04-24 · E+G 구현·검증 완료, main 로컬 머지 대기
**브랜치**: `refactor/jira-batch-preview-polish` (main 기준 3커밋 + 본 HANDOFF 커밋 예정)
**main 동기화**: `origin/main` = 커밋 기준 구. 로컬 `main`이 C-1 머지본으로 **앞섬** (미push).
**배포 방침**: 사용자 방침 — **"한번에 배포"**. push/전역배포는 다음 브랜치까지 누적 후 한 번에.

---

## 🎯 지금 이어갈 것

1. **E+G main 로컬 머지** (승인 받음, 실행 대기):
   ```bash
   git checkout main
   git merge --no-ff refactor/jira-batch-preview-polish
   git branch -d refactor/jira-batch-preview-polish
   ```
2. **다음 브랜치 착수** — 추천: `refactor/jira-batch-probe-defer` (O-3)
3. **누적 push + 전역 배포** (다음 브랜치 완료 후 한 번에, 사용자 승인 필요):
   ```bash
   git push origin main
   bash scripts/build-skills.sh
   ```

---

## 📊 현재 상태

### 로컬 main (미push)
```
900aca4  Merge branch 'refactor/jira-batch-create-ux'     ← C-1 머지 커밋
3886866  docs: C-1 E2E 전체 통과 및 머지 대기 반영
4d91b1b  fix: 1-1 경로 재입력 프롬프트를 0-0b와 분리
b341e20  fix: 템플릿 매칭 안내 출력 강제 + 트리 마커 기준 명확화
e220c92  refactor: 미리보기 테이블을 트리 + 요약 축약 출력으로 전환
7c9bd60  refactor: jira-batch-create-setup → jira-batch-templates 개명
8a7941c  feat: SDD 경로 확보/템플릿 매칭/템플릿 생성 흐름 내장
```

### E+G 브랜치 (main..HEAD, 머지 대기)
```
0a0cbcd  fix: 트리 라인 증거 placeholder를 {증거값}으로 명시
aa1636c  feat: Phase A/B/C 진행률 로그에 타입 한국어 병기
eedfc51  feat: 미리보기 (C)에 리스트 다시 보기 선택지 추가
```

### E+G 검증 결과

| 커밋 | 검증 | 결과 |
|------|------|------|
| `eedfc51` 리스트 다시 보기 | S1 본검증 + mini 재검증 | ✅ |
| `aa1636c` Phase 로그 타입 병기 | 본문 diff + 배포본 grep | ⚠️ S2 (실 이슈 생성 경로) **스킵** — 실사용 때 확인 |
| `0a0cbcd` 증거 placeholder fix | 회귀 재검증 (`수정 N 증거=X` → 실제 값 렌더) | ✅ |

### B 항목 병행 검증 결과 (HANDOFF 섹션 B — 완료)

| 체크 | 결과 |
|------|------|
| `수정 N priority=High sp=X` 축약형 즉시 반영 | ✅ 필드 선택 대화 없이 즉시 반영 |
| `수정 N parent=#X` 수정 불가 필드 거절 | ✅ "parent는 수정할 수 없습니다..." 안내 |

### E+G 체크리스트

- [x] 커밋 1: (C-5) 리스트 다시 보기 서브섹션 신설
- [x] 커밋 2: Phase A/B/C 로그 타입 한국어 병기
- [x] 커밋 3: 증거 placeholder `{증거값}` fix
- [x] S1 본검증 + mini 재검증
- [x] O-7 회귀 재검증
- [x] B 항목 2건 병행 검증
- [ ] main 로컬 머지

---

## 🔍 발견 관찰 (후속 주제)

**C-1 E2E에서 발견:**

- **O-3 — Step 0 customfield probe 낭비** → 별건 `refactor/jira-batch-probe-defer` 등재
- **O-2 — 3회 상한 종료 문구 자연어 변형** → 기능 동등, 기록만
- **트리 들여쓰기 규칙 모호** / **YAML 스키마 표기법 모호** / **1-3 매칭 안내 중복** / **build-skills.sh 개명 청소 누락** (이전 HANDOFF와 동일)

**E+G + B 검증에서 신규 발견:**

- **O-4 — Codex `gpt-5.5` "Model Set Context" 덤프**: 모델의 내부 메모리 블록 노출 quirk. 본문·스킬 무관. 회피: `/model gpt-5.4`. OpenAI 측 버그 리포트 대상.
- **O-6 — 트리 `👤` 마커 기준의 모델별 해석 차이**: 본문 규약(397행) "summary origin 기준"을 `gpt-5.5`는 준수, `gpt-5.4`는 any-field-user로 확장 해석. 본문 설계 주제 — any-field-user로 명시 변경할지 결정 필요.
- **O-7 — 트리 증거 placeholder literal 누수** (`0a0cbcd`로 해결): 본문 라인 템플릿 `{, 증거=…}`의 `…`이 Codex에 축약 기호로 오인돼 실제 값 대신 리터럴 복사. `{증거값}` 중괄호 placeholder로 교체하여 해결.
- **O-8 — 이슈 번호 순서 모델별 차이**: 본문에 `#{N}` 번호 결정 규칙 미명시로 세션/모델마다 번호 매김 순서가 다름(parent-child 순 vs 타입별 그룹 순). `수정 7` 명령이 세션마다 다른 이슈를 가리킬 수 있는 UX 혼선 유발. 본문에 번호 매김 규칙 추가 필요.

---

## 📋 후속 작업 체크리스트

### 📌 추천 우선순위 (E+G 머지 후)

1. **`refactor/jira-batch-probe-defer`** (O-3) — 성능/비용 절감, hub 수정 + 단건 회귀 필요
2. **`fix/jira-batch-tree-numbering`** (O-8) — 번호 매김 규칙 본문 명시
3. **`chore/tree-marker-design-decision`** (O-6) — any-field-user로 갈지 summary 기준 유지할지 설계 결정 + 본문 반영
4. **C-2** (safety) — parent 주석 / validate_only 강제 / 재승인 재사용
5. **C-3** (단건 정합화) — 단건 `jira-create.body.md`에 P0 패턴 적용

### `refactor/jira-batch-probe-defer` — customfield probe 이연 (O-3)

**배경**: hub `0-0a` customfield 검증이 Step 1-2 매칭 판정 전에 수행 → 중단/취소/재입력 경로에서 probe 7~10회 전량 낭비.

**수정 설계 후보** (둘 중 택1, 설계 필요):
- **A — 세션 내 이연**: 0-0a probe를 "생성 직전"(batch: Step 4 미리보기 이후 사용자 `생성` 확정 시점 / 단건: `jira_create_issue` 호출 직전)으로 이동.
- **B — config 캐시**: 0-0a 결과를 `sprint-workflow-config.md`에 `last_validated_at: <ISO>` 기록. N시간(예: 24h) 이내면 스킵.

**수정 범위**: hub `jira-create-hub.body.md` 0-0a 블록 재작성. 단건/배치 본문에 "probe 트리거 지점" 명시 필요.

**E2E 필요**:
- [ ] hub 진입 → probe 스킵 확인 (중단 경로)
- [ ] batch 실제 생성(샌드박스 JST) → Step 4 사용자 `생성` 응답 시점에 probe 1회 수행 확인
- [ ] 단건 `jira-create` 생성 1건 → probe 위치 검증
- [ ] 잘못된 customfield로 config 손상 → probe 실패 메시지 정상 노출

### `fix/jira-batch-tree-numbering` — 트리 번호 매김 규칙 명시 (O-8)

- [ ] 본문에 `#{N}` 결정 규칙 추가: 예) "트리를 깊이 우선 순회(Epic → 자식 PBI → 자식 Sub-task → 다음 PBI) 순서로 1부터 매긴다."
- [ ] (B-1) 블록의 "상위: #M" 참조, (C-2) 수정 축약형 `수정 N field=value`의 N 매칭도 이 규칙 기반
- [ ] 본문 수정 위치: Step 1-3 파싱 결과 구조 설명 부분 또는 Step 4 (A) 도입부

### `chore/tree-marker-design-decision` — 마커 기준 설계 결정 (O-6)

- [ ] 선택: (a) summary origin 유지 (현재 본문) / (b) any-field-user 확장 / (c) 트리 접두 마커 폐기하고 (B-1) 블록만 사용
- [ ] 결정 기록을 본문 주석으로 추가 ("이 마커는 ..."이라는 의도 문서화)
- [ ] (b) 선택 시 본문 397행 수정

### C-2. `chore/jira-batch-create-safety`

- [ ] post-test-findings #6 parent 타입 주석
- [ ] #10 `validate_only` 강제
- [ ] #11 이전 승인 재사용 (`--yes` 등)
- [ ] #9 중 A와 안 겹치는 잔여만

### C-3. `fix/jira-create-align-with-batch`

- [ ] 단건 `jira-create.body.md`에도 동일 P0 패턴 적용 (currentUser, 한국어 타입 맵)
- [ ] A 머지 이후 착수

### 신규 (E2E 관찰에서 도출, 기존)

- [ ] **`chore/build-cleanup-renamed`** — `scripts/build-skills.sh`에 개명 후 구 디렉토리 자동 청소 로직 추가
- [ ] **트리 들여쓰기 규칙 결정** — 절대(현재 본문) vs 상대(Codex 해석). 선택 후 본문 정합화
- [ ] **YAML 스키마 표기법 통일** — placeholder vs 정규식 중 공식 표기 결정, 본문 예시 재작성
- [ ] **Fix 1 매칭 안내 중복 출력 해소** — 1-3 경로에서 `✅ 저장했습니다` 뒤에 `템플릿 X과 매칭되었습니다`가 또 나옴

---

## 📚 참조

### 문서

- `jira-create/jira-batch-create.body.md` — batch 본문 (C-1 + E+G 반영)
- `jira-create/jira-batch-templates.body.md` — 개명 후 템플릿 편집 스킬 본문
- `jira-create/jira-create-hub.body.md` — 공유 hub (A 반영: 0-0a/0-0b/0-0c + 0-1 서브루틴 + PROJECT_ID 폴백)
- `batch-ux-e2e-codex.md` — C-1 E2E 가이드 (전 시나리오 통과, untracked 로컬 유지)
- `polish-e2e-codex.md` — E+G E2E 가이드 축소판 (untracked 로컬 유지)
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

- **2026-04-24** E+G 구현 — `refactor/jira-batch-preview-polish` 3커밋 (리스트 다시 보기 / Phase 로그 타입 병기 / 증거 placeholder fix). S1 + O-7 회귀 + B 2건 통과. 머지 대기.
- **2026-04-24** C-1 main 머지 (`900aca4`) — E2E S1~S7 전 시나리오 통과 + O-1 fix 회귀 통과. 6커밋 편입. push 미완.
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
