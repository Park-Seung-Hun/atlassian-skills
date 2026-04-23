# hub.body 진입 흐름 개편 — `jira-batch-create` Codex E2E 테스트 가이드

> **대상 변경**: `jira-create-hub.body.md`에 `0-0b 현재 설정 확인` / `0-0c 항목별 수정` / `0-0a 자동 키 검증` 3개 절 신설, `0-1`을 `0-1-PROJECT/SP/AC/EV` 서브루틴으로 분해.
> **브랜치**: `refactor/hub-body-entry-flow` (커밋 `b9e3b26`)
> **테스트 대상 스킬**: `jira-batch-create` 전용 (단건 `jira-create`는 별도 테스트 안 함)
> **환경**: Codex CLI + 프로젝트 scope 배포 (`/Users/psh/develop/atlassian-skills/.agents/skills/`)

---

## 사전 관찰 (참고)

앞선 `jira-create` 초기 테스트에서 **0-0b 요약이 나오지 않고 바로 Step 1로 진입**, 0-0c **수정 질문 자체가 안 나오는** 현상이 관찰됨. Codex가 hub 본문의 "먼저 0-0b를 수행한다"는 지시를 무시하고 본 스킬 Step 1로 뛰어넘는 패턴으로 보임. batch에서도 같은 증상이 나오면 hub 본문의 **실행 순서 지시를 강제성 있게 보강**해야 함. 시나리오마다 "0-0b가 떴는가?"를 첫 체크포인트로 두었음.

---

## 0. 사전 준비 (1회만)

### 0-1. 배포 상태 확인

```bash
cd /Users/psh/develop/atlassian-skills
grep -nE '^(#{2,4}) (0-0a|0-0b|0-0c|0-1-(PROJECT|SP|AC|EV))' .agents/skills/jira-batch-create/SKILL.md
```

아래 7개 헤더가 모두 출력돼야 정상:
```
### 0-0b. 현재 설정 확인
### 0-0c. 항목별 수정
### 0-0a. 자동 customfield 키 검증
#### 0-1-PROJECT — PROJECT_KEY + BOARD_ID 수집
#### 0-1-SP — FIELD_SP 슬롯 매칭
#### 0-1-AC — FIELD_AC 슬롯 매칭
#### 0-1-EV — FIELD_EV 슬롯 매칭
```

### 0-2. 현재 config 값 (테스트 기준점)

| 항목 | 값 |
|------|-----|
| 프로젝트 키 | `JST` |
| 보드 ID | `2155` |
| 스토리 포인트 필드 | `customfield_10016` |
| AC 필드 | `customfield_12881` |
| 증거 필드 | `customfield_12880` |
| Slack 사용자 ID | `U045EERKPMJ` |

### 0-3. config 백업 (필수)

```bash
cp ~/.agents/sprint-workflow-config.md ~/.agents/sprint-workflow-config.md.bak
```

각 시나리오가 끝나면 복구:
```bash
cp ~/.agents/sprint-workflow-config.md.bak ~/.agents/sprint-workflow-config.md
```

### 0-4. 샘플 SDD 파일

프로젝트 루트의 `test-sdd.md`를 사용합니다. 존재 확인:
```bash
ls -l /Users/psh/develop/atlassian-skills/test-sdd.md
head -20 /Users/psh/develop/atlassian-skills/test-sdd.md
```

### 0-5. Codex 실행

```bash
cd /Users/psh/develop/atlassian-skills
codex
```

### 0-6. 스킬 호출 방법 (batch 전용)

Codex엔 슬래시 명령이 없으니 자연어에 스킬명을 포함:

```
jira-batch-create 스킬로 /Users/psh/develop/atlassian-skills/test-sdd.md 파싱해서 JST에 이슈 만들어줘.
```

> 만약 Codex가 어느 스킬을 쓸지 모호해하면 더 명시적으로:
> `"~/.agents/skills/jira-batch-create/SKILL.md의 절차에 따라 /Users/psh/develop/atlassian-skills/test-sdd.md를 처리해줘"`

### 0-7. 선택지 응답 방법

hub가 `[그대로 진행 / 항목 수정]` 같은 선택지를 제시하면 **한국어 레이블을 그대로 타이핑**:

- `그대로 진행`
- `항목 수정`
- `AC 필드, Slack 사용자 ID` (복수 선택 예)
- `재지정`
- `비활성화`
- `중단`

### 0-8. 테스트 티켓 최소화 전략 (중요)

batch는 SDD 하나로 **여러 이슈**(Epic + Story + Sub-task 등 10건 이상)를 한 번에 만듭니다. hub 흐름만 검증할 때는 실제 생성을 안 해도 되므로, batch의 **Step 4 미리보기 단계에서 `취소`**를 응답해 종료할 수 있습니다.

각 시나리오에서 "실제 생성까지 / Step 4에서 취소"를 표기해뒀으니, **hub 분기 확인 위주인 S3/S4/S5/S8은 "취소" 경로를 권장**합니다. 정상 파이프라인 회귀 확인용인 S1/S6/S7만 실제 생성까지 진행.

### 0-9. 0-0b가 안 뜰 때 Codex 유도 방법 (관찰된 이슈 대응)

사전 관찰에서 0-0b 요약이 자동으로 안 나온 사례가 있었습니다. 같은 증상이 나오면 바로 아래와 같이 명시 지시:

```
hub.body Step 0의 0-0b부터 순서대로 진행해줘. config를 로드한 뒤에 "현재 설정 확인" 요약을 먼저 출력하고, 내가 선택지를 답할 때까지 Step 1로 넘어가지 마.
```

이 유도로 0-0b가 나오면 "**Codex가 hub를 제대로 읽었지만 지시 강도가 약해서 건너뛴 경우**"로 판정 (→ 본문 보강 필요). 유도 후에도 안 나오면 "**SKILL.md에 0-0b가 실제로 반영 안 된 경우**"(→ 빌드 문제). 구분해서 보고해주세요.

---

## S1. config 정상 + "그대로 진행" → 실제 생성

**목적**: hub 정상 경로가 batch 본문(Step 1~5)으로 자연스럽게 이어지는지 회귀 확인

### 전제
- config는 0-2 표 그대로 (편집 없음)

### 입력
```
jira-batch-create 스킬로 /Users/psh/develop/atlassian-skills/test-sdd.md 파싱해서 JST에 이슈 만들어줘.
```

### 기대 흐름
1. **0-0b 요약 출력** (프로젝트 키 JST, FIELD_* 3개, Slack 등 표시) ← **첫 체크포인트**
2. `그대로 진행` 응답
3. **0-0a `jira_search_fields` 1회 호출** → 3개 customfield 모두 존재 확인
4. batch Step 1 (SDD 파싱) → Step 2 (메타데이터 보강) → Step 2-0 ISSUE_TYPE_MAP probe → Step 3 (payload 구성) → Step 4 (미리보기 + 사용자 승인)
5. 승인 → Phase A/B/C로 실제 이슈 생성

### 합격 체크리스트
- [ ] **0-0b 요약이 자동으로 출력된다** (안 나오면 0-9 유도 시도 후 재판정)
- [ ] 0-0a probe 로그가 정확히 1회
- [ ] Step 2-0 ISSUE_TYPE_MAP probe가 0-0a와 **별개로** 실행됨 (서로 다른 목적)
- [ ] JST에 이슈들이 실제 생성됨 (Phase A/B/C 완료 메시지)

### 정리
- 생성된 테스트 티켓은 JQL로 일괄 삭제: `project = JST AND summary ~ "hub E2E"` 필터
- config 미변경이라 복구 불필요

---

## S2. 항목별 수정 + 0-0b 복귀 → Step 4 취소

**목적**: 0-0c 복수 선택 + config 영속화 + 0-0b 재진입 루프 검증

### 전제
- config 정상 상태

### 입력
```
jira-batch-create 스킬로 /Users/psh/develop/atlassian-skills/test-sdd.md 파싱해서 JST에 이슈 만들어줘.
```

### 기대 흐름
1. 0-0b 요약 출력
2. `항목 수정` 응답
3. 0-0c 복수 선택 질문 → `AC 필드, Slack 사용자 ID` 응답
4. **0-1-AC 서브루틴 재진입**: "현재 값: customfield_12881. 재수집하시겠습니까? [예/아니오]" → `예`
5. `jira_search_fields`에서 AC 후보 재조회 → 올바른 AC 선택 (원래 값 그대로 선택해도 무방)
6. Slack ID 직접 입력 → 임시로 `U999TEST999`
7. config 파일 갱신 (해당 2개 라인만)
8. **0-0b 복귀** — 갱신된 요약 재출력 (Slack ID가 `U999TEST999`로 보임)
9. `그대로 진행` → 0-0a → batch Step 1 ~ Step 4
10. **Step 4 미리보기 단계에서 `취소` 응답** (실제 이슈 생성 안 함)

### 합격 체크리스트
- [ ] 0-0c에서 선택 안 한 항목은 재질문되지 않는다
- [ ] 복귀한 0-0b에 새 Slack ID가 반영됨
- [ ] config 파일에서 **해당 2개 라인만** 변경됨:
  ```bash
  diff ~/.agents/sprint-workflow-config.md.bak ~/.agents/sprint-workflow-config.md
  ```
  `AC 필드:`와 `Slack 사용자 ID:` 두 라인만 diff에 나와야 함

### 정리
```bash
cp ~/.agents/sprint-workflow-config.md.bak ~/.agents/sprint-workflow-config.md
```

---

## S3. 키 오류 감지 + "재지정" → Step 4 취소

**목적**: 0-0a probe 실패 감지와 슬롯별 재지정 루프 검증

### 전제
FIELD_AC 오염:
```bash
sed -i '' 's/^AC 필드:.*$/AC 필드: customfield_99999/' ~/.agents/sprint-workflow-config.md
grep '^AC 필드' ~/.agents/sprint-workflow-config.md
```

### 입력
```
jira-batch-create 스킬로 /Users/psh/develop/atlassian-skills/test-sdd.md 파싱해서 JST에 이슈 만들어줘.
```

### 기대 흐름
1. 0-0b 요약 — FIELD_AC = `customfield_99999`
2. `그대로 진행`
3. 0-0a `jira_search_fields` → `customfield_99999` 없음 감지
4. 안내: "FIELD_AC(`customfield_99999`)가 jira_search_fields 결과에서 확인되지 않습니다."
5. 선택지: `재지정`
6. 0-1-AC 재실행 → 후보 선택 → 올바른 customfield 확정
7. config 파일 갱신 (AC 라인만)
8. batch Step 1 ~ Step 4 미리보기 진입
9. **Step 4에서 `취소`**

### 합격 체크리스트
- [ ] 0-0a가 FIELD_AC **1건만** 실패로 보고
- [ ] diff로 AC 라인만 바뀐 것 확인:
  ```bash
  diff ~/.agents/sprint-workflow-config.md.bak ~/.agents/sprint-workflow-config.md
  ```
- [ ] Step 4까지 도달 (취소로 종료)

### 정리
```bash
cp ~/.agents/sprint-workflow-config.md.bak ~/.agents/sprint-workflow-config.md
```

---

## S4. 키 오류 + "비활성화" → Step 4 취소

**목적**: 비활성화 분기 (세션 내 `(none)` 처리 + config 미변경) 검증

### 전제
S3과 동일하게 오염:
```bash
sed -i '' 's/^AC 필드:.*$/AC 필드: customfield_99999/' ~/.agents/sprint-workflow-config.md
```

### 입력
```
jira-batch-create 스킬로 /Users/psh/develop/atlassian-skills/test-sdd.md 파싱해서 JST에 이슈 만들어줘.
```

### 기대 흐름
1. 0-0b → `그대로 진행`
2. 0-0a에서 FIELD_AC 실패 감지
3. 선택지: `비활성화`
4. 세션 내 `FIELD_AC = (none)` 처리 (config 파일 미변경)
5. batch Step 1 ~ Step 4 미리보기
6. 미리보기에서 AC 필드 열이 비어있거나 생략된 걸 확인 → `취소`

### 합격 체크리스트
- [ ] config 파일의 AC 라인이 여전히 `customfield_99999`:
  ```bash
  grep '^AC 필드' ~/.agents/sprint-workflow-config.md
  ```
- [ ] 미리보기 payload에서 AC 필드가 누락됨을 확인
- [ ] "다음 실행 시 동일 오류가 재발할 수 있음" 경고 메시지 유무 (있으면 가산점)

### 정리
```bash
cp ~/.agents/sprint-workflow-config.md.bak ~/.agents/sprint-workflow-config.md
```

---

## S5. 프로젝트 키 오버라이드 → 0-0b/0-0c/0-0a 스킵

**목적**: 0-2 경로에서 hub 신규 절들이 스킵되는지 검증. 접근 가능한 다른 프로젝트가 있을 때만 수행 (없으면 **스킵**).

### 전제
- config 정상 상태
- `OTHER` 자리에 본인이 접근 가능한 다른 Jira 프로젝트 키를 넣을 것

### 입력
```
jira-batch-create 스킬로 /Users/psh/develop/atlassian-skills/test-sdd.md 파싱해서 OTHER 프로젝트에 이슈 만들어줘.
```

### 기대 흐름
1. 0-0 후 0-2에서 `OTHER`를 PROJECT_KEY로 감지
2. "프로젝트 키 `OTHER`로 1회성 생성합니다. 보드/필드를 재탐색합니다."
3. **0-0b/0-0c/0-0a 모두 건너뜀**
4. 0-1-PROJECT → 0-1-SP → 0-1-AC → 0-1-EV 순차 강제 실행
5. batch Step 1 ~ Step 4 미리보기 → `취소`

### 합격 체크리스트
- [ ] 0-0b 요약이 출력되지 않는다
- [ ] 0-0a probe 로그가 찍히지 않는다
- [ ] config 파일 미변경:
  ```bash
  diff ~/.agents/sprint-workflow-config.md.bak ~/.agents/sprint-workflow-config.md
  ```
  diff 없어야 함

### 정리
없음 (config 미변경)

---

## S6. config 파일 없음 → 실제 생성

**목적**: 최초 사용자 경로(0-1 전체 진입) + batch 본문 정상 연결 검증

### 전제
```bash
mv ~/.agents/sprint-workflow-config.md ~/.agents/sprint-workflow-config.md.stash
```

### 입력
```
jira-batch-create 스킬로 /Users/psh/develop/atlassian-skills/test-sdd.md 파싱해서 JST에 이슈 만들어줘.
```

### 기대 흐름
1. 0-0 로드 실패
2. **0-0b/0-0c/0-0a 모두 건너뛰고** 0-1 순차 실행:
   - 0-1-PROJECT: `JST` 입력 → 보드 자동/선택 (2155)
   - 0-1-SP: `customfield_10016` 선택
   - 0-1-AC: `customfield_12881` 선택
   - 0-1-EV: `customfield_12880` 선택
3. 완료 후 config 파일 신규 생성 (SLACK_ID는 `(none)` 고정)
4. batch Step 1 ~ Step 5 → 실제 이슈 생성

### 합격 체크리스트
- [ ] 0-0b가 호출되지 않는다
- [ ] `~/.agents/sprint-workflow-config.md`가 새로 생성:
  ```bash
  ls -l ~/.agents/sprint-workflow-config.md
  cat ~/.agents/sprint-workflow-config.md
  ```
- [ ] 신규 파일의 Slack 사용자 ID가 `(none)`
- [ ] JST에 이슈들이 실제 생성됨

### 정리
```bash
mv ~/.agents/sprint-workflow-config.md.stash ~/.agents/sprint-workflow-config.md
```
(신규 생성된 config는 덮어써짐)

---

## S7. `(none)` 슬롯이 섞인 config → Step 4 취소

**목적**: 0-0a probe가 `(none)` 슬롯을 오경보 없이 스킵하는지 검증

### 전제
FIELD_EV를 비활성화:
```bash
sed -i '' 's/^증거 필드:.*$/증거 필드: (none)/' ~/.agents/sprint-workflow-config.md
grep '^증거 필드' ~/.agents/sprint-workflow-config.md
```

### 입력
```
jira-batch-create 스킬로 /Users/psh/develop/atlassian-skills/test-sdd.md 파싱해서 JST에 이슈 만들어줘.
```

### 기대 흐름
1. 0-0b 요약에서 증거 필드 = `(none)` 표시
2. `그대로 진행`
3. 0-0a probe에서 FIELD_EV는 검증 대상에서 **제외**
4. batch Step 1 ~ Step 4 → `취소`

### 합격 체크리스트
- [ ] 0-0a가 FIELD_EV에 대해 "확인되지 않습니다" 오경보를 내지 않는다
- [ ] 미리보기 payload에서 EV 필드가 누락돼 있어야 함

### 정리
```bash
cp ~/.agents/sprint-workflow-config.md.bak ~/.agents/sprint-workflow-config.md
```

---

## 최종 복구 (모든 시나리오 완료 후)

```bash
cp ~/.agents/sprint-workflow-config.md.bak ~/.agents/sprint-workflow-config.md
rm ~/.agents/sprint-workflow-config.md.bak
```

JST에 생성된 테스트 티켓들은 Jira에서 JQL로 일괄 조회 후 삭제:
```
project = JST AND summary ~ "hub E2E"
```
또는 SDD에 들어있던 제목 패턴으로 검색.

---

## 시나리오 매트릭스

| 시나리오 | 0-0b | 0-0c | 0-0a | 0-1 재진입 | config 저장 | 실제 생성? |
|----------|:----:|:----:|:----:|:---------:|:-----------:|:----------:|
| S1 정상 진행 | ✓ | ✗ | ✓ pass | ✗ | ✗ | 생성 |
| S2 항목 수정 | ✓→✓(복귀) | ✓ | ✓ | ✓(AC) | ✓ | 취소 |
| S3 키 오류 재지정 | ✓ | ✗ | ✓ fail→재지정 | ✓(AC) | ✓ | 취소 |
| S4 키 오류 비활성화 | ✓ | ✗ | ✓ fail→비활성화 | ✗ | ✗ | 취소 |
| S5 프로젝트 오버라이드 | 스킵 | 스킵 | 스킵 | ✓(전체 재탐색) | ✗ | 취소 |
| S6 config 없음 | 스킵 | 스킵 | 스킵 | ✓(전체) | ✓(신규) | 생성 |
| S7 (none) 포함 | ✓ | ✗ | ✓(부분) | ✗ | ✗ | 취소 |

**실제 생성 시나리오는 2개 (S1, S6)**. 나머지는 Step 4 취소로 티켓 생성 부담 없음.

---

## 실패 시 디버깅 힌트

- **0-0b 요약이 자동으로 안 나옴** (관찰된 이슈)
  → 0-9의 명시 유도 문구로 재시도
  → 유도 후 나오면: hub 본문의 0-0b 진입 지시를 더 강하게 표현할 필요 (예: "**반드시 0-0b를 먼저 수행**", "Step 1로 진입하기 전에…")
  → 유도 후에도 안 나오면: `grep -n '0-0b' .agents/skills/jira-batch-create/SKILL.md`로 실제 prepend 여부 확인

- **0-0c에서 선택 안 한 슬롯도 재질문됨**
  → 0-1 서브루틴 격리 실패. SKILL.md에서 0-1-AC 등이 독립 섹션인지 확인

- **config 갱신 후 다른 라인 손상**
  ```bash
  diff ~/.agents/sprint-workflow-config.md.bak ~/.agents/sprint-workflow-config.md
  ```
  의도한 라인 외에도 바뀌면 0-0c의 "해당 라인만 교체" 지시 강화 필요

- **0-0a probe가 실제 존재하는 customfield를 실패로 보고**
  → `jira_search_fields` 응답 스키마 확인. hub는 `id` 필드 기준(예: `customfield_10016`) 비교. Codex가 `key` 혹은 다른 필드로 비교했다면 본문 표현 보강 필요

- **0-0a와 Step 2-0 probe의 중복/누락**
  → 0-0a는 `jira_search_fields`(customfield 검증), Step 2-0은 `jira_batch_create_issues(validate_only=true)`(ISSUE_TYPE_MAP 구축). 서로 다른 MCP 호출이므로 둘 다 실행돼야 정상

---

## 결과 보고 포맷

```
S1: ✅ 통과 / ❌ 실패 — (실패 시) 단계 + 1~2문장 관찰
    특이사항: ...
S2: ...
...
S7: ...

전반 관찰:
- 0-0b 자동 출력 여부:
- 0-9 유도 필요 여부:
- 기타:
```

전체 통과 시 "S1~S7 통과, 0-0b 자동 출력 정상"만 주셔도 됩니다. 실패 1건 발견하는 즉시 보고하셔도 좋습니다 — hub 본문 보강이 필요한지 바로 판정 가능.
