#!/usr/bin/env bash
# workspace-init profile manager v2
# 支援: 多 project、Git 整合、Tone 設定、Profile 匯出/匯入、Skill 推薦

set -euo pipefail

CONFIG_DIR="$HOME/.config/claude"
SKILL_DIR="$HOME/.claude/skills/workspace-init"
PROFILE="$CONFIG_DIR/workspace-init-profile.json"
PROFILE="$CONFIG_DIR/workspace-init-profile.json"
MULTI_PROFILE_DIR="$CONFIG_DIR/workspace-profiles"
CACHE_FILE="$CONFIG_DIR/workspace-cache.json"
CACHE_TTL=300

# ---- 顏色 ----
DIM='\033[2m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

# ---- Git 偵測 ----
detect_git_context() {
  local dir="${1:-$(pwd)}"
  local git_root branch lang files
  git_root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || true)
  [[ -z "$git_root" ]] && { echo '{"in_git":false}'; return 0; }

  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null || "unknown")

  # Detect project language
  lang=$(detect_project_lang "$git_root")

  # File count
  files=$(git -C "$dir" ls-files 2>/dev/null | wc -l | tr -d ' ')

  cat << JSON
{
  "in_git": true,
  "root": "$git_root",
  "branch": "$branch",
  "language": "$lang",
  "files": $files
}
JSON
}

detect_project_lang() {
  local root="$1"
  if [[ -f "$root/package.json" ]]; then echo "JavaScript/TypeScript"
  elif [[ -f "$root/Cargo.toml" ]]; then echo "Rust"
  elif [[ -f "$root/go.mod" ]]; then echo "Go"
  elif [[ -f "$root/pyproject.toml" || -f "$root/requirements.txt" ]]; then echo "Python"
  elif [[ -f "$root/Gemfile" ]]; then echo "Ruby"
  elif [[ -f "$root/CMakeLists.txt" ]]; then echo "C/C++"
  elif [[ -f "$root/Package.swift" ]]; then echo "Swift"
  elif [[ -f "$root/composer.json" ]]; then echo "PHP"
  elif [[ -f "$root/Makefile" ]]; then echo "Makefile"
  else echo "unknown"
  fi
}

# ---- Multi-project 支援 ----
get_project_key() {
  local dir="${1:-$(pwd)}"
  git -C "$dir" rev-parse --show-toplevel 2>/dev/null || echo "$dir"
}

project_profile_path() {
  local key dir="${1:-$(pwd)}"
  key=$(get_project_key "$1" | md5sum 2>/dev/null | head -c 16 || echo "default")
  echo "$MULTI_PROFILE_DIR/$key.json"
}

# 新：.claude/project-profile.json（非 Git project 專用，跟 project 走）
local_project_profile_path() {
  local dir="${1:-$(pwd)}"
  echo "$dir/.claude/project-profile.json"
}

# 新：優先級 search
find_project_profile() {
  local dir="${1:-$(pwd)}"

  # 優先 1：.claude/project-profile.json（跟 project 走，Git 同非 Git 都適用）
  local local_path
  local_path=$(local_project_profile_path "$dir")
  if [[ -f "$local_path" ]]; then
    cat "$local_path"
    return 0
  fi

  # 優先 2：multi-project profile（Git project 專用）
  if git -C "$dir" rev-parse --show-toplevel 2>/dev/null >/dev/null; then
    local mp_path
    mp_path=$(project_profile_path "$dir")
    if [[ -f "$mp_path" ]]; then
      cat "$mp_path"
      return 0
    fi
  fi

  return 1
}

# 新：save 去 .claude/project-profile.json（自動 merge global profile）
save_local_project_profile() {
  local dir="$1" json="$2"
  local path
  path=$(local_project_profile_path "$dir")

  # Merge: 如果 global profile 存在，用佢嘅 user_name / company / language / preferred_form / tone 做 default
  if [[ -f "$PROFILE" ]]; then
    local merged
    merged=$(jq -n --argjson given "$json" --argjson global "$(cat "$PROFILE")" '
      {
        user_name: ($given.user_name // $global.user_name // ""),
        company: ($given.company // $global.company // ""),
        project: ($given.project // ""),
        language: ($given.language // $global.language // ""),
        preferred_form: ($given.preferred_form // $global.preferred_form // ""),
        tone: ($given.tone // $global.tone // "casual"),
        project_details: ($given.project_details // $given.project // ""),
        extra_skills: ($given.extra_skills // $global.extra_skills // {})
      }
    ')
    json="$merged"
  fi

  mkdir -p "$(dirname "$path")"
  echo "$json" > "$path"
  chmod 600 "$path"
  echo -e "${GREEN}✓ Project profile saved: ${BOLD}$path${NC} ${DIM}(跟 project 走)${NC}"
}

load_project_profile() {
  local dir="${1:-$(pwd)}"
  local path
  path=$(project_profile_path "$dir")
  if [[ -f "$path" ]]; then
    cat "$path"
    return 0
  fi
  return 1
}

save_project_profile() {
  local dir="$1" json="$2"
  local path
  path=$(project_profile_path "$dir")
  mkdir -p "$(dirname "$path")"
  echo "$json" > "$path"
  chmod 600 "$path"
  echo "✓ Project profile saved: $path"
}

list_projects() {
  echo -e "${CYAN}已儲存嘅 projects:${NC}"
  if [[ ! -d "$MULTI_PROFILE_DIR" ]]; then
    echo "  （冇）"
    return
  fi
  for f in "$MULTI_PROFILE_DIR"/*.json; do
    [[ -f "$f" ]] || continue
    local name
    name=$(jq -r '.project // "unknown"' "$f" 2>/dev/null || echo "unknown")
    local key
    key=$(basename "$f" .json)
    echo -e "  ${GREEN}•${NC} ${BOLD}$name${NC} ${DIM}($key)${NC}"
  done
}

# ---- Tone 設定 ----
get_tone_guide() {
  local tone="${1:-casual}"
  case "$tone" in
    casual)
      echo "用輕鬆自然嘅語氣，可以加下 slang，唔使太 formal"
      ;;
    formal)
      echo "用正式書面語，避免 slang，structure 清晰"
      ;;
    technical)
      echo "用技術性語言，精準、直接，可以多啲 spec 同數據"
      ;;
    friendly)
      echo "用 friendly 嘅語氣，好似同朋友傾偈咁，可以 emoji"
      ;;
    minimal)
      echo "只講重點，最短回覆，唔廢話"
      ;;
    *)
      echo "$tone"
      ;;
  esac
}

# ---- Skill 推薦 ----
recommend_skills() {
  local lang="${1:-unknown}"
  local branch="${2:-unknown}"

  local recommendations=""

  case "$lang" in
    "JavaScript/TypeScript")
      recommendations+="  - ponytail (懶人開發模式，少 code)\n"
      recommendations+="  - impeccable (UI 設計檢測)\n"
      recommendations+="  - engineering-advanced-skills:dependency-auditor (依賴審計)\n"
      recommendations+="  - engineering-advanced-skills:performance-profiler (效能分析)\n"
      ;;
    "Rust")
      recommendations+="  - engineering-advanced-skills:ci-cd-pipeline-builder (CI/CD)\n"
      recommendations+="  - engineering-advanced-skills:dependency-auditor (依賴審計)\n"
      recommendations+="  - ponytail (懶人模式)\n"
      ;;
    "Python")
      recommendations+="  - engineering-advanced-skills:rag-architect (RAG 架構)\n"
      recommendations+="  - engineering-advanced-skills:database-designer (數據庫設計)\n"
      recommendations+="  - ponytail (懶人模式)\n"
      ;;
    "Go")
      recommendations+="  - engineering-advanced-skills:performance-profiler (效能)\n"
      recommendations+="  - engineering-advanced-skills:ci-cd-pipeline-builder (CI/CD)\n"
      ;;
    *)
      recommendations+="  - ponytail (懶人模式，通用)\n"
      recommendations+="  - graphify (codebase 架構理解)\n"
      recommendations+="  - review (code review)\n"
      ;;
  esac

  # Branch-specific
  case "$branch" in
    main|master)
      recommendations+="  - engineering-advanced-skills:changelog-generator (release notes)\n"
      ;;
    feat/*|feature/*)
      recommendations+="  - engineering-advanced-skills:pr-review-expert (PR review)\n"
      ;;
    fix/*|hotfix/*)
      recommendations+="  - engineering-advanced-skills:focused-fix (集中修 bug)\n"
      ;;
  esac

  echo -e "$recommendations"
}

# ---- Profile 匯出/匯入 ----
export_profile() {
  local out_file="${1:-workspace-init-profile-export.json}"

  if [[ ! -f "$PROFILE" ]]; then
    echo -e "${RED}❌ 冇 profile 可以匯出${NC}"
    return 1
  fi

  # 包埋 multi-project profiles 如果有的話
  local export_obj
  export_obj=$(cat "$PROFILE")

  if [[ -d "$MULTI_PROFILE_DIR" ]]; then
    local projects_json="{}"
    for f in "$MULTI_PROFILE_DIR"/*.json; do
      [[ -f "$f" ]] || continue
      local key
      key=$(basename "$f" .json)
      local content
      content=$(cat "$f")
      projects_json=$(echo "$projects_json" | jq --arg k "$key" --argjson v "$content" '. + {($k): $v}')
    done
    export_obj=$(echo "$export_obj" | jq --argjson projects "$projects_json" '. + {projects: $projects}')
  fi

  echo "$export_obj" > "$out_file"
  echo -e "${GREEN}✓ Profile 已匯出到: $out_file${NC}"
}

import_profile() {
  local in_file="${1:-}"
  if [[ -z "$in_file" || ! -f "$in_file" ]]; then
    echo -e "${RED}❌ 檔案唔存在: $in_file${NC}"
    return 1
  fi

  local data
  data=$(cat "$in_file")

  # 主 profile
  echo "$data" | jq 'del(.projects)' > "$PROFILE" 2>/dev/null || {
    echo -e "${RED}❌ 無效嘅 JSON 格式${NC}"
    return 1
  }
  chmod 600 "$PROFILE"

  # Multi-project profiles
  local projects
  projects=$(echo "$data" | jq -r '.projects // empty' 2>/dev/null)
  if [[ -n "$projects" && "$projects" != "null" ]]; then
    mkdir -p "$MULTI_PROFILE_DIR"
    echo "$projects" | jq -r 'to_entries[] | "\(.key)\t\(.value)"' | while IFS=$'\t' read -r key json_str; do
      echo "$json_str" > "$MULTI_PROFILE_DIR/$key.json"
      chmod 600 "$MULTI_PROFILE_DIR/$key.json"
    done
    echo -e "${GREEN}✓ 已匯入 $(echo "$projects" | jq 'length') 個 project profiles${NC}"
  fi

  echo -e "${GREEN}✓ Profile 已匯入${NC}"
}

# ---- Cache ----
get_cache() {
  if [[ -f "$CACHE_FILE" ]]; then
    local cache_time age
    cache_time=$(stat -f %m "$CACHE_FILE" 2>/dev/null || stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
    age=$(( $(date +%s) - cache_time ))
    if (( age < CACHE_TTL )); then
      cat "$CACHE_FILE"
      return 0
    fi
  fi
  return 1
}

set_cache() {
  local data="$1"
  mkdir -p "$(dirname "$CACHE_FILE")"
  echo "$data" > "$CACHE_FILE"
}

# ---- 主要功能 ----
get_profile() {
  if [[ -f "$PROFILE" ]]; then
    cat "$PROFILE"
    return 0
  fi
  return 1
}

save_profile() {
  local name="$1" company="$2" project="$3" lang="$4" form="$5" details="$6" tone="${7:-casual}"
  mkdir -p "$(dirname "$PROFILE")"
  cat > "$PROFILE" << JSON
{
  "user_name": "$name",
  "company": "$company",
  "project": "$project",
  "language": "$lang",
  "preferred_form": "$form",
  "tone": "$tone",
  "project_details": "$details"
}
JSON
  chmod 600 "$PROFILE"
  echo -e "${GREEN}✓ Profile saved: $PROFILE${NC}"
}

reset_profile() {
  rm -f "$PROFILE"
  echo -e "${YELLOW}✓ Profile reset${NC}"
}

# ---- Init 流程（俾 LLM 用，輸出 context block） ----
init_context() {
  local dir="${1:-$(pwd)}"

  # 檢查有冇 profile
  if [[ ! -f "$PROFILE" ]]; then
    echo '{"status":"no_profile"}'
    return 0
  fi

  local profile_data
  profile_data=$(cat "$PROFILE")
  local git_data
  git_data=$(detect_git_context "$dir")
  local project_profile_data="null"

  # 優先 search：.claude/project-profile.json > multi-project profile
  if find_project_profile "$dir" >/dev/null 2>&1; then
    project_profile_data=$(find_project_profile "$dir")
  fi

  # Build 完整 context
  local tone
  tone=$(echo "$profile_data" | jq -r '.tone // "casual"')
  local tone_guide
  tone_guide=$(get_tone_guide "$tone")

  local ctx
  ctx=$(cat << CTX
{
  "status": "ok",
  "profile": $profile_data,
  "git": $git_data,
  "project_profile": $project_profile_data,
  "tone_guide": "$tone_guide"
}
CTX
)

  set_cache "$ctx"
  echo "$ctx"
}

# ---- Main ----
main() {
  local cmd="${1:-}"

  mkdir -p "$CONFIG_DIR"

  case "$cmd" in
    --get) get_profile ;;
    --save)
      save_profile "${2:-}" "${3:-}" "${4:-}" "${5:-}" "${6:-}" "${7:-}" "${8:-casual}"
      ;;
    --reset) reset_profile ;;
    --check)
      if [[ -f "$PROFILE" ]]; then echo "EXISTS"; else echo "NOT_FOUND"; fi
      ;;
    --ctx)
      init_context "${2:-$(pwd)}"
      ;;
    --git)
      detect_git_context "${2:-$(pwd)}"
      ;;
    --tone)
      get_tone_guide "${2:-casual}"
      ;;
    --recommend)
      recommend_skills "${2:-unknown}" "${3:-unknown}"
      ;;
    --export)
      export_profile "${2:-}"
      ;;
    --import)
      import_profile "${2:-}"
      ;;
    --list-projects)
      list_projects
      ;;
    --update)
      echo -e "${CYAN}⬇️  Updating workspace-init...${NC}"
      bash "$SKILL_DIR/scripts/update.sh"
      ;;
    --save-project)
      local dir="${2:-$(pwd)}"
      local json="${3:-}"
      [[ -z "$json" ]] && { echo -e "${RED}❌ 需要 JSON data${NC}"; exit 1; }
      save_project_profile "$dir" "$json"
      ;;
    --save-local|--sl)
      local dir="${2:-$(pwd)}"
      local json="${3:-}"
      [[ -z "$json" ]] && { echo -e "${RED}❌ 需要 JSON data${NC}"; exit 1; }
      save_local_project_profile "$dir" "$json"
      ;;
    *)
      echo "workspace-init profile manager v2"
      echo ""
      echo "用法:"
      echo "  --get                       讀取 profile"
      echo "  --save <name> <company> <project> <lang> <form> <details> [tone]  儲存"
      echo "  --reset                     重置"
      echo "  --check                     檢查是否存在"
      echo "  --ctx [dir]                 完整 context（含 git + multi-project）"
      echo "  --git [dir]                 Git 偵測"
      echo "  --tone [tone]               Tone 指南（casual/formal/technical/friendly/minimal）"
      echo "  --recommend <lang> <branch> Skill 推薦"
      echo "  --export [file]             匯出 profile"
      echo "  --import <file>             匯入 profile"
      echo "  --list-projects             列出所有 project profiles"
      echo "  --save-project <dir> <json> 儲存 project-specific profile（~/.config/claude/）"
      echo "  --save-local|--sl <dir> <json> 儲存 project profile 喺 .claude/ 入面（自動 merge global profile）"
      echo "  --update                    自動更新 workspace-init 到最新版"
      ;;
  esac
}

main "$@"
