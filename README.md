# atlassian-skills

Atlassian(Jira / Confluence) 워크플로우 중심의 Claude Code / Codex CLI 스킬을 한 저장소에서 작성하고, 빌드 스크립트로 양 환경에 동시에 배포하는 워크스페이스다.

## 들어 있는 스킬

| 스킬 | 설명 |
|------|------|
| `jira-create` | Jira 이슈 단건 생성 (Story / Task / Bug / Spike / Sub-task) + Slack DM 알림 |
| `jira-batch-create` | SDD(spec kit `tasks.md` 등) 기반 Epic/PBI/Sub-task 일괄 생성 |
| `jira-batch-templates` | `jira-batch-create`가 사용하는 SDD 파싱 템플릿 편집 진입점 |
| `confluence-fetch` | Confluence 페이지를 Markdown으로 내려받기 (손실 변환) |
| `confluence-write` | Markdown 초안을 Confluence 새 페이지로 업로드 |

팀 도입·시연용 자료는 [`Park-Seung-Hun.github.io/plans/atlassian-skills-team-demo.md`](../Park-Seung-Hun.github.io/plans/atlassian-skills-team-demo.md)에 따로 있다.

## 디렉토리 구조

각 스킬은 도메인 폴더 안에 3-파일 구조로 작성한다.

```
<domain>/
├── <name>.body.md       # 환경 중립 본문 (단일 소스, frontmatter 없음)
├── <name>.claude.yml    # Claude Code 프론트매터
└── <name>.codex.yml     # Codex Agent Skill 프론트매터
```

`<name>.body.md` 안의 `{{CONFIG_PATH}}` 토큰은 빌드 시 환경별 config 경로(`~/.claude/...` 또는 `~/.agents/...`)로 치환된다.

## 빌드 / 설치

```bash
# Claude + Codex 양쪽, 사용자 전역에 설치 (기본값)
bash scripts/build-skills.sh

# Claude만
bash scripts/build-skills.sh --target claude

# Codex만
bash scripts/build-skills.sh --target codex

# 특정 프로젝트 디렉토리에만 설치 (project scope)
bash scripts/build-skills.sh --scope project --project-dir <path>
```

### 배포 경로

| target | scope=global | scope=project |
|--------|--------------|---------------|
| claude | `~/.claude/commands/<name>.md` | `<project>/.claude/commands/<name>.md` |
| codex  | `~/.agents/skills/<name>/SKILL.md` | `<project>/.agents/skills/<name>/SKILL.md` |

Codex는 세션 실행 시 현재 작업 디렉토리에서 저장소 루트까지 올라가며 `.agents/skills`를 스캔한 뒤 `$HOME/.agents/skills`로 이동한다 ([공식 문서](https://developers.openai.com/codex/skills)).

### 권장 배포 흐름

새 스킬이나 본문 수정을 적용할 때는 **project scope에서 먼저 검증**한 뒤 global로 승격한다. 전역 선배포는 다른 세션에 섣부르게 영향을 주므로 이 단계를 건너뛰지 않는다.

```bash
# 1. 작업 중인 프로젝트에 먼저 배포
bash scripts/build-skills.sh --scope project --project-dir ~/work/some-project

# 2. 해당 프로젝트에서 스킬을 한두 번 직접 돌려본다
#    (의도대로 동작하는지, 미리보기 형식이 깨지지 않는지 등)

# 3. 문제 없으면 전역 승급
bash scripts/build-skills.sh
```

## 새 스킬 추가

1. 도메인 폴더 결정 (기존 폴더에 묶을지 신규 폴더 만들지)
2. `<name>.body.md` 작성 (frontmatter 없이)
3. `<name>.claude.yml`, `<name>.codex.yml` 생성 — `description`은 동일 문장
4. `allowed-tools`에 본문에서 실제로 호출하는 도구만 명시 (과다 권한 금지)
5. `scripts/build-skills.sh`의 `SKILLS` 배열에 등록
6. project scope 배포로 한두 번 실전 검증 후 global 승격

자세한 작성 규칙은 [`CLAUDE.md`](./CLAUDE.md) 참고.

## 외부 의존

- **MCP 서버**: `mcp-atlassian`, `slack`, 그리고 일부 스킬은 `notion`. Claude는 `~/.claude.json` / `~/.claude/`에서, Codex는 `~/.codex/config.toml`에서 등록을 확인한다.
- **Config 파일**: 사용자별 설정(보드 ID, 프로젝트 키, customfield ID, Notion DB ID 등)은 본문에 하드코딩하지 않고, `{{CONFIG_PATH}}`가 가리키는 외부 파일에서 읽는다.
  - Claude: `~/.claude/sprint-workflow-config.md`
  - Codex: `~/.agents/sprint-workflow-config.md`
- **SDD 템플릿**: `jira-batch-create` / `jira-batch-templates`는 `~/.agents/jira-sdd-templates.yml`(Codex) 또는 `~/.claude/jira-sdd-templates.yml`(Claude)을 사용한다. 인스턴스마다 customfield ID가 다르므로 **저장소에 커밋하지 않는다**.

## 라이선스 / 컨벤션

커밋 컨벤션과 본문 작성 규칙은 [`CLAUDE.md`](./CLAUDE.md)에 정리되어 있다.
