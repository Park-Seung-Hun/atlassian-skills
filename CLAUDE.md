# atlassian-skills

Atlassian(Jira/Confluence) 워크플로우 중심의 Claude Code / Codex CLI 스킬을 한 저장소에서 작성하고, 빌드 스크립트로 양 환경에 배포하는 워크스페이스.

이 파일은 Claude가 이 프로젝트에서 작업할 때 항상 따라야 할 규칙을 정의한다.

---

## 작업 원칙

- **빌드 스크립트로만 배포한다.** `~/.claude/commands/`, `~/.agents/skills/`, 또는 프로젝트의 `.claude/` 디렉토리에 직접 쓰지 않는다. 모든 배포는 `scripts/build-skills.sh`를 거친다.
- **사용자가 명시 요청 전엔 빌드 스크립트를 실행하지 않는다.** 본문/프론트매터 수정은 자유롭게 하되, 실제 설치는 사용자가 트리거한다.
- **본문은 단일 소스다.** Claude/Codex 양쪽에서 동작 차이가 필요하면 본문에 분기 지시를 넣고, 프론트매터로 분기하지 않는다.
- **새 스킬 추가 시 `scripts/build-skills.sh`의 `SKILLS` 배열에 등록**해야 빌드 대상이 된다.

---

## 스킬 디렉토리 규약

각 스킬은 도메인별 폴더 안에 **3-파일 구조**로 작성한다.

```
<domain>/
├── <name>.body.md       # 환경 중립 본문 (단일 소스, frontmatter 없음)
├── <name>.claude.yml    # Claude Code 프론트매터
└── <name>.codex.yml     # Codex Agent Skill 프론트매터
```

한 도메인 폴더에 여러 스킬을 묶을 수 있다 (예: `jira-create/`에 `jira-create`와 `jira-create-setup` 공존).

도메인 폴더에는 `README.md`로 스킬 설계 의도를 기록한다(선택).

---

## 프론트매터 형식

### `<name>.claude.yml`
```yaml
---
allowed-tools: <쉼표 구분 도구 목록>
description: <한 문장 — 사용자/모델이 언제 호출할지 판단하는 근거>
disable-model-invocation: false   # true면 자동 호출 차단, 슬래시 명시 호출만 허용
---
```

### `<name>.codex.yml`
```yaml
---
name: <name>
description: <claude.yml과 동일한 한 문장>
---
```

`description`은 양쪽이 동일해야 한다. 빌드 시 검증하지는 않으니 수정 시 함께 갱신.

---

## 본문 작성 규칙

- `<name>.body.md`는 **frontmatter 없이 순수 본문**으로 작성한다. 빌드 시 프론트매터가 prepend된다.
- **config 토큰**: 빌드 시 환경별 경로로 치환된다. 용도에 따라 사용:
  - `{{CONFIG_PATH}}` / `{{CONFIG_PATH_GLOBAL}}` → 글로벌 절대 경로. Claude `~/.claude/sprint-workflow-config.md`, Codex `~/.agents/sprint-workflow-config.md`. 두 토큰은 동의어(기존 호환 유지).
  - `{{CONFIG_LOCAL_REL}}` → 프로젝트 범위 상대 경로. Claude `.claude/sprint-workflow-config.md`, Codex `.agents/sprint-workflow-config.md`.
  - `{{CONFIG_LOCAL_DIR}}` → 프로젝트 범위 디렉토리명. Claude `.claude`, Codex `.agents`.
  - `{{CONFIG_FILENAME}}` → `sprint-workflow-config.md` (양 환경 공통).
  - 프로젝트/글로벌 2단 저장을 지원하는 스킬은 setup에서 `{{CONFIG_LOCAL_REL}}`·`{{CONFIG_PATH_GLOBAL}}`을 조합해 저장 위치를 결정하고, 소비 스킬은 `<CWD>/{{CONFIG_LOCAL_REL}}` → `{{CONFIG_PATH_GLOBAL}}` → 인라인 fallback 순으로 로드한다.
- **공유 본문**(shared body): 여러 스킬이 공통 단계(예: 워크플로우 hub)를 공유할 경우, hub 본문 파일(`<hub>.body.md`)을 만들고 빌드 등록 시 `shared_body` 컬럼에 hub 이름을 적는다. 빌드 시 hub 본문의 `## Step 0` 이후 내용이 각 스킬 본문 앞에 inline-prepend된다.

---

## 빌드 / 설치

```bash
bash scripts/build-skills.sh                       # Claude + Codex, 전역 설치 (기본)
bash scripts/build-skills.sh --target claude       # Claude만
bash scripts/build-skills.sh --target codex        # Codex만
bash scripts/build-skills.sh --scope global        # ~/.claude/ , ~/.agents/ (기본값)
bash scripts/build-skills.sh --scope project --project-dir <path>
                                                    # <path>/.claude/commands/ , <path>/.agents/skills/ 에 설치
```

### 배포 경로

| target | scope=global | scope=project |
|--------|--------------|---------------|
| claude | `~/.claude/commands/<name>.md` | `<project>/.claude/commands/<name>.md` |
| codex  | `~/.agents/skills/<name>/SKILL.md` | `<project>/.agents/skills/<name>/SKILL.md` |

Codex는 세션 실행 시 현재 작업 디렉토리에서 저장소 루트까지 올라가며 `.agents/skills`를 스캔하고, 그 뒤 `$HOME/.agents/skills`·`/etc/codex/skills`·내장 스킬 순으로 읽는다([공식 문서](https://developers.openai.com/codex/skills)). 따라서 project scope로 배포한 Codex 스킬은 해당 프로젝트 안에서 Codex를 실행할 때만 노출된다.

### `SKILLS` 등록 형식

`scripts/build-skills.sh` 안의 `SKILLS` 배열에 `"skill_name:relative_dir:shared_body"` 형식으로 추가한다. `shared_body`는 비워두거나 hub 본문 이름을 적는다.

```bash
SKILLS=(
  "jira-create:jira-create:"             # shared body 없음
  "sprint-bootstrap:sprint:sprint"        # sprint.body.md를 prepend
)
```

---

## 새 스킬 만들 때 체크리스트

1. 도메인 폴더 결정 (기존 폴더에 묶을지 신규 폴더 만들지)
2. `<name>.body.md` 작성 (frontmatter 없이)
3. `<name>.claude.yml`, `<name>.codex.yml` 생성 — `description`은 동일 문장
4. `allowed-tools`에 본문에서 실제로 호출하는 도구만 명시 (과다 권한 금지)
5. `scripts/build-skills.sh`의 `SKILLS` 배열에 등록
6. 빌드 실행은 사용자에게 위임 (자동 실행 금지)
7. **사용자 테스트는 project scope에서 먼저 한다** — 전역 배포 전에 `--scope project --project-dir <path>`로 배포해 실전에서 한 번 이상 호출·검증한 뒤 global 배포를 승인한다. 초기 설계는 실전에서 구멍이 드러나기 쉽고, 전역 선배포는 다른 세션에 섣부르게 영향을 준다.

---

## 커밋 컨벤션

Conventional Commits를 따른다. 형식: `type(scope): subject`

### type
| type | 용도 |
|------|------|
| `feat` | 신규 스킬 추가, 기존 스킬에 새 동작/기능 추가 |
| `fix` | 본문/프론트매터/스크립트의 버그 수정 |
| `docs` | README, CLAUDE.md, 스킬 설계 문서 변경 |
| `refactor` | 동작 변화 없는 본문/스크립트 재구성 (공유 본문 추출 등) |
| `build` | `scripts/build-skills.sh` 등 빌드/배포 로직 변경 |
| `chore` | 그 외 잡일 (gitignore, 메타파일 등) |

### scope
- 스킬 단위 변경: 스킬 이름 (`jira-create`, `sprint-bootstrap`, `ticket-done` 등)
- 도메인 단위 변경: 도메인 폴더명 (`sprint`, `ticket` — 도메인 내 여러 스킬에 걸친 변경)
- 빌드/스크립트: `scripts`
- 저장소 루트 문서: scope 생략

### subject
- 한국어로 작성. 명령형 어미("추가", "수정", "변경") 권장. 마침표 없음.
- 50자 이내 권장.

### body (선택)
- 한 줄 비우고 작성. **왜** 바꿨는지를 적는다 (무엇을 바꿨는지는 diff로 충분).
- 호환성 깨지는 변경은 `BREAKING CHANGE:` 푸터로 명시.

### 예시
```
feat(jira-create): Sub-task 생성 시 부모 이슈 자동 검증 추가
fix(scripts): --scope project일 때 codex 빌드 skip 처리
docs(sprint): 공유 본문 prepend 동작을 README에 명시
refactor(ticket): work-log 규칙을 ticket.body.md로 추출
build(scripts): --project-dir 옵션 추가
chore: .gitignore에 빌드 산출물 임시 파일 추가
```

### 1커밋 = 1논리변경
- 여러 스킬을 한 번에 손댔다면 스킬별로 커밋을 나눈다.
- 단, 동일 변경이 여러 스킬에 동일 패턴으로 적용되는 경우(예: 공통 변수명 변경)는 한 커밋으로 묶고 scope를 도메인이나 생략으로 둔다.

---

## 외부 의존

- **MCP 서버**: 스킬에 따라 `mcp-atlassian`, `notion`, `slack` 등이 필요할 수 있다. Claude는 `~/.claude.json` / `~/.claude/`에서, Codex는 `~/.codex/config.toml`에서 등록을 확인한다.
- **Config 파일**: 사용자별 설정(보드 ID, 프로젝트 키, Notion DB ID 등)은 본문에 하드코딩하지 않고, `{{CONFIG_PATH}}`가 가리키는 외부 파일에서 읽도록 작성한다.
