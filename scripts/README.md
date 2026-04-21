# scripts

저장소 내 빌드/배포 스크립트 모음.

---

## `build-skills.sh`

`<domain>/<name>.body.md` + `<name>.{claude,codex}.yml` 3-파일 구조로 작성된 스킬을 Claude Code(`~/.claude/commands/`)와 Codex(`~/.agents/skills/`) 환경 각각이 이해하는 단일 파일(`SKILL.md` 또는 `<name>.md`)로 조립해 배포한다.

### 동작 개요

1. `SKILLS` 배열(스크립트 상단)에 등록된 각 스킬에 대해
2. `<name>.<target>.yml` 프론트매터를 읽고
3. `<name>.body.md` 본문을 조립(필요 시 shared body hub prepend)
4. `{{CONFIG_PATH}}` 토큰을 환경별 config 경로로 치환
5. target별 배포 경로에 `frontmatter + body` 형식으로 기록

### 사용법

```bash
# 기본: Claude + Codex 양쪽에 전역 배포
bash scripts/build-skills.sh

# 특정 환경만
bash scripts/build-skills.sh --target claude
bash scripts/build-skills.sh --target codex

# 특정 스킬만 (쉼표 구분)
bash scripts/build-skills.sh --skill jira-batch-create
bash scripts/build-skills.sh --skill jira-create,jira-create-setup

# 프로젝트 scope (테스트용, Claude만 지원)
bash scripts/build-skills.sh --scope project --project-dir <path>
```

### 옵션

| 옵션 | 값 | 기본값 | 설명 |
|------|----|--------|------|
| `--target` | `all` / `claude` / `codex` | `all` | 배포할 환경 |
| `--scope` | `global` / `project` | `global` | `global`은 사용자 홈, `project`는 `<project>/.claude/commands/` |
| `--project-dir` | 경로 | — | `--scope project` 필수 |
| `--skill` | 스킬명(쉼표 구분) | — | 미지정 시 `SKILLS` 배열 전체 빌드 |

### 배포 경로

| target | scope=global | scope=project |
|--------|--------------|---------------|
| claude | `~/.claude/commands/<name>.md` | `<project>/.claude/commands/<name>.md` |
| codex  | `~/.agents/skills/<name>/SKILL.md` | (skip — Codex는 project scope 미지원) |

### Shared Body (hub)

여러 스킬이 공통 Step(예: 설정 로드)을 공유할 때 사용한다. `SKILLS` 배열 entry의 세 번째 컬럼에 hub 이름을 적으면, hub 본문의 `## Step 0` 이후 내용이 각 스킬 본문 앞에 prepend된다.

```bash
SKILLS=(
  "jira-create:jira-create:jira-create-hub"        # jira-create-hub.body.md를 prepend
  "jira-create-setup:jira-create:"                 # hub 없음
)
```

### `{{CONFIG_PATH}}` 치환

본문에 `{{CONFIG_PATH}}` 토큰이 있으면 빌드 시 환경별 경로로 바뀐다.

| target | 치환 결과 |
|--------|----------|
| claude | `~/.claude/sprint-workflow-config.md` |
| codex  | `~/.agents/sprint-workflow-config.md` |

---

## 새 스킬 추가 시

1. `<domain>/<name>.body.md`, `<name>.claude.yml`, `<name>.codex.yml` 3개 파일 작성
2. `build-skills.sh`의 `SKILLS` 배열에 `"skill_name:relative_dir:shared_body"` 형식으로 등록
3. 사용자가 빌드 트리거 (스크립트는 자동 실행하지 않음)

자세한 규약은 저장소 루트 `CLAUDE.md`의 "스킬 디렉토리 규약" 섹션 참조.
