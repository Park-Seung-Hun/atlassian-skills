# {{TASK_ID}} `{{BRANCH_NAME}}` — Codex E2E 테스트 가이드

> 이 파일은 `templates/e2e-codex-template.md`를 복사해 만든 가이드입니다. `{{...}}` 플레이스홀더를 전부 채운 뒤 저장소 루트에 `{{task-slug}}-e2e-codex.md` 이름으로 두세요. 가이드 파일 자체는 **untracked 로컬 유지**가 관례 — 회귀가 끝나면 지우거나 브랜치 작업 노트로만 씁니다.
>
> **대상 변경**:
> - {{변경 요약 1 — 본문·스킬·파일 경로}}
> - {{변경 요약 2}}
> - {{변경 요약 3}}
>
> **브랜치**: `{{BRANCH_NAME}}`
> **테스트 대상 스킬**: `{{skill-a}}`, `{{skill-b}}`
> **환경**: Codex CLI + 프로젝트 scope 배포 (`/Users/psh/develop/atlassian-skills/.agents/skills/`)
>
> **Codex 입력 관례**: Codex는 슬래시 명령을 쓰지 않는다. 자연어 명시로 스킬을 트리거한다. 예: `{{skill-a}} 스킬로 {{sample-file}} 처리해줘`.

---

## 0. 사전 준비 (1회만)

### 0-1. project scope 배포

```bash
cd /Users/psh/develop/atlassian-skills
bash scripts/build-skills.sh --target codex --scope project \
  --project-dir /Users/psh/develop/atlassian-skills
```

기대 출력에 다음 줄 포함:
```
[codex ] {{skill-a}} -> .../skills/{{skill-a}}/SKILL.md
[codex ] {{skill-b}} -> .../skills/{{skill-b}}/SKILL.md
```

### 0-2. 배포 본문 스폿체크

이번 변경이 배포 산출물에 반영됐는지 키워드로 확인:

```bash
cd /Users/psh/develop/atlassian-skills
grep -n "{{키워드1}}\|{{키워드2}}" \
  .agents/skills/{{skill-a}}/SKILL.md \
  .agents/skills/{{skill-b}}/SKILL.md
```

기대: 양쪽 SKILL.md에 {{기대 동작 — 몇 줄 이상 찍혀야 함 등}}.

### 0-3. 상태 백업 (필요 시)

테스트가 config/데이터 파일을 건드린다면 백업:

```bash
cp ~/.agents/sprint-workflow-config.md ~/.agents/sprint-workflow-config.md.bak
# 필요하면 다른 파일도
```

### 0-4. 트레이스 관찰 방법

Codex는 MCP tool call 로그를 세션에 펼쳐 보여준다. 각 시나리오에서 관찰 대상 호출(예: `{{관찰할 mcp tool 이름}}`)의 **호출 횟수·인자·타이밍**을 기록한다. 로그가 길어 잘렸다면:

```bash
tail -f ~/.codex/logs/mcp-atlassian.log | grep -i "{{tool-keyword}}"
```

(경로는 환경별로 다를 수 있음)

---

## 시나리오 S1 — {{시나리오 제목, 예: 중단 경로}}

**목표**: {{한 문장 — 무엇을 확인하는가}}.

### 절차

1. 새 Codex 세션 시작.
2. 입력:
   ```
   {{자연어 트리거 입력 전문}}
   ```
3. {{중간 단계 지시 — 0-0b 선택, Step N 응답 등}}
4. {{관찰 지점}}
5. {{종료 조건 — "취소" / "생성" / 수동 MCP 취소 등}}

### 핵심 관찰 포인트

- {{포인트 1 — MCP 호출 여부·횟수}}
- {{포인트 2 — 특정 문구 출력 여부}}
- {{포인트 3 — 분기 UI 동작}}

### 체크리스트

- [ ] {{기대 동작 1}}
- [ ] {{기대 동작 2}}
- [ ] {{기대 동작 3}}

### 붙여주실 것

- Codex 세션 **입력·응답 전문** (자르지 말고 세션 시작부터 종료까지)
- 특히 `Called mcp-*` 블록 전체
- (필요 시) 직전·직후 파일 상태: `ls -la {{경로}}` 또는 `grep {{키} {{파일}}`

---

## 시나리오 S2 — {{제목}}

**목표**: {{…}}.

### 절차

1. …
2. …

### 체크리스트

- [ ] …

### 붙여주실 것

…

---

<!-- 필요한 만큼 S3, S4, … 복제 -->

## 통과 기준 요약

| 시나리오 | 기대 결과 | PASS/FAIL |
|----------|-----------|-----------|
| S1 {{제목}} | {{기대}} | ☐ |
| S2 {{제목}} | {{기대}} | ☐ |

모두 PASS여야 머지 후보.

---

## 관찰 메모란

### S1
-

### S2
-

### 이상 징후 / 회귀 / 후속 주제
-

---

## 사후 정리

```bash
# 백업 복구 (필요 시)
cp ~/.agents/sprint-workflow-config.md.bak ~/.agents/sprint-workflow-config.md
# 생성된 테스트 이슈 삭제 (실 생성을 포함한 시나리오가 있다면)
```

---

## 가이드 사용 규약 (템플릿 상수)

이 섹션은 템플릿에서 채우지 않고 그대로 둔다. 가이드를 따라가는 사용자와 판정자(모델) 모두 참조.

- **실패 보고 포맷 4종 필수**: ① 시나리오 번호 + 체크항목, ② 입력 전문, ③ Codex 응답 전문(자르지 말 것), ④ 직전·직후 `~/.agents/` 파일 상태.
- **보정 사이클**: 실패 리포트 → 본문 지문 보강 → 새 fix 커밋 → 재테스트. 동일 지점 **2회 반복 실패** 시 자동 수정 중단하고 사용자에게 대안 상의.
- **체크리스트는 줄 단위로 모두 체크돼야 머지 승인**. 부분 통과는 회귀 위험.
- **실 Jira 이슈 생성 최소화**: 미리보기 단계에서 `취소`로 빠지게 하거나, 실 생성 시 즉시 삭제 스크립트 준비. 실 생성 회귀는 별도 세션으로 분리.
- **project scope 배포 기본**. 전역 배포는 검증 통과 후.
- **개명 커밋 후에는 구 디렉토리 수동 청소**: `rm -rf .agents/skills/{{옛이름}}` (`build-skills.sh`는 삭제를 안 함).
