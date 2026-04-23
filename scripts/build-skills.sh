#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── SKILLS 배열: "skill_name:relative_dir:shared_body" ──
SKILLS=(
  "confluence-fetch:confluence-fetch:"
  "confluence-write:confluence-write:"
  "jira-create:jira-create:jira-create-hub"
  "jira-create-setup:jira-create:"
  "jira-batch-create:jira-create:jira-create-hub"
  "jira-batch-templates:jira-create:"
)

# ── 기본값 ──
TARGET="all"
SCOPE="global"
PROJECT_DIR=""
SKILL_FILTER=""
DEPLOY_COUNT=0

# ── CONFIG_PATH 치환 맵 ──
CONFIG_PATH_CLAUDE="~/.claude/sprint-workflow-config.md"
CONFIG_PATH_CODEX="~/.agents/sprint-workflow-config.md"

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      --target)   TARGET="$2";      shift 2 ;;
      --scope)    SCOPE="$2";       shift 2 ;;
      --project-dir) PROJECT_DIR="$2"; shift 2 ;;
      --skill)    SKILL_FILTER="$2"; shift 2 ;;
      *) echo "[ERROR] Unknown option: $1"; exit 1 ;;
    esac
  done
}

validate_args() {
  if [[ "$SCOPE" == "project" && -z "$PROJECT_DIR" ]]; then
    echo "[ERROR] --project-dir required when --scope=project"
    exit 1
  fi
}

filter_skills() {
  if [[ -z "$SKILL_FILTER" ]]; then
    return
  fi

  local filtered=()
  IFS=',' read -ra requested <<< "$SKILL_FILTER"

  for req in "${requested[@]}"; do
    local found=false
    for entry in "${SKILLS[@]}"; do
      local name="${entry%%:*}"
      if [[ "$name" == "$req" ]]; then
        filtered+=("$entry")
        found=true
        break
      fi
    done
    if [[ "$found" == false ]]; then
      echo "[ERROR] Skill '$req' not found in SKILLS array"
      exit 1
    fi
  done

  SKILLS=("${filtered[@]}")
}

get_deploy_path() {
  local skill_name="$1" target="$2"

  if [[ "$target" == "claude" ]]; then
    if [[ "$SCOPE" == "global" ]]; then
      echo "$HOME/.claude/commands/${skill_name}.md"
    else
      echo "${PROJECT_DIR}/.claude/commands/${skill_name}.md"
    fi
  else
    if [[ "$SCOPE" == "global" ]]; then
      echo "$HOME/.agents/skills/${skill_name}/SKILL.md"
    else
      echo "${PROJECT_DIR}/.agents/skills/${skill_name}/SKILL.md"
    fi
  fi
}

build_body() {
  local src_dir="$1" skill_name="$2" shared_body="$3"
  local body=""

  if [[ -n "$shared_body" ]]; then
    local hub_file="$src_dir/${shared_body}.body.md"
    if [[ ! -f "$hub_file" ]]; then
      echo "[ERROR] ${shared_body}.body.md not found in $src_dir"
      exit 1
    fi
    local hub_content
    hub_content=$(sed -n '/^## Step 0/,$p' "$hub_file")
    if [[ -z "$hub_content" ]]; then
      echo "[WARN] '## Step 0' not found in ${shared_body}.body.md -- prepending entire file"
      hub_content=$(cat "$hub_file")
    fi
    body="${hub_content}"$'\n\n'
  fi

  local body_file="$src_dir/${skill_name}.body.md"
  if [[ ! -f "$body_file" ]]; then
    echo "[ERROR] ${skill_name}.body.md not found in $src_dir"
    exit 1
  fi

  body+="$(cat "$body_file")"
  echo "$body"
}

build_skill() {
  local skill_name="$1" rel_dir="$2" shared_body="$3" target="$4"
  local src_dir="$ROOT_DIR/$rel_dir"

  # 프론트매터 읽기
  local yml_file="$src_dir/${skill_name}.${target}.yml"
  if [[ ! -f "$yml_file" ]]; then
    echo "[WARN] ${skill_name}.${target}.yml not found -- skipping $target"
    return
  fi
  local frontmatter
  frontmatter=$(cat "$yml_file")

  # 본문 조립
  local body
  body=$(build_body "$src_dir" "$skill_name" "$shared_body")

  # 토큰 치환
  local config_path="$CONFIG_PATH_CLAUDE"
  if [[ "$target" == "codex" ]]; then
    config_path="$CONFIG_PATH_CODEX"
  fi
  body=$(echo "$body" | sed "s|{{CONFIG_PATH}}|$config_path|g")

  local config_dir
  config_dir=$(dirname "$config_path")
  body=$(echo "$body" | sed "s|{{CONFIG_DIR}}|$config_dir|g")

  # 배포
  local deploy_path
  deploy_path=$(get_deploy_path "$skill_name" "$target")
  local deploy_dir
  deploy_dir=$(dirname "$deploy_path")
  mkdir -p "$deploy_dir"

  printf '%s\n%s\n' "$frontmatter" "$body" > "$deploy_path"

  local shared_note=""
  if [[ -n "$shared_body" ]]; then
    shared_note="  (shared: $shared_body)"
  fi
  printf '[%-6s] %s -> %s%s\n' "$target" "$skill_name" "$deploy_path" "$shared_note"

  DEPLOY_COUNT=$((DEPLOY_COUNT + 1))
}

main() {
  parse_args "$@"
  validate_args
  filter_skills

  local targets=()
  if [[ "$TARGET" == "all" ]]; then
    targets=(claude codex)
  else
    targets=("$TARGET")
  fi

  echo "[build-skills] Building ${#SKILLS[@]} skill(s) | target=$TARGET scope=$SCOPE"

  for entry in "${SKILLS[@]}"; do
    IFS=: read -r name dir shared <<< "$entry"
    for t in "${targets[@]}"; do
      build_skill "$name" "$dir" "$shared" "$t"
    done
  done

  echo "[build-skills] Done. $DEPLOY_COUNT file(s) deployed."
}

main "$@"
