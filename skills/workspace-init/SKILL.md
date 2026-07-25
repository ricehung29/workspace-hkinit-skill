---
name: workspace-init
description: "每次對話開始時注入 workspace 背景、用戶偏好、語言設定、project context，提高 cache hit rate 同個人化體驗。第一次用會問你嘅名同公司，然後記住。"
---

# workspace-init

每次對話開始時自動注入 workspace 背景資訊，或者手動用 `/init` 呼叫。

## 用法

```
/init                             — 重新注入 workspace 背景（自動 detect Git + 推薦 skills）
/init --full                      — 完整版（含 quota check + memory 狀態）
/init --reset                     — 重置所有已儲存嘅資料
/init --lang 廣東話                — 直接切換語言
/init --tone formal               — 設定 tone（casual/formal/technical/friendly/minimal）
/init --export [file.json]        — 匯出 profile
/init --import <file.json>        — 匯入 profile
/init --list-projects             — 列出所有已儲存嘅 project profiles
/init --save-project <dir> <json>   — 儲存 project-specific profile（`~/.config/claude/`）
/init --save-local|--sl <dir> <json> — 儲存 project profile 喺 `.claude/` 入面，自動 merge global profile
/init --update                      — 自動更新 workspace-init 到最新版
```

## 首次使用流程

第一次用 `/init` 嘅時候，會問你：

1. **你叫咩名？**（英文名 / 中文名 / 代號）
2. **你嘅公司 / 團隊名？**（optional，可以 skip）
3. **你個 project 係咩？**（簡短描述）
4. **你想用咩語言交流？**（廣東話 / 普通話 / English / 其他）
5. **你嘅稱呼偏好？**（例如：叫你「師兄」/「大佬」/「你」/ 直接用名）
6. **你想用咩 tone？**（casual / formal / technical / friendly / minimal，預設 casual）

呢啲資料會 save 落 `~/.config/claude/workspace-init-profile.json`，之後唔會再問。

## 注入內容

### 用戶身份（由 profile 讀取）
- 名: **{{user_name}}**
- 公司: **{{company}}**（如果有）
- 專案: **{{project}}**
- 稱呼: 用「{{preferred_form}}」

### 語言設定
- 用 **{{language}}** 回覆
- 如果係廣東話：口語、香港用語、繁中
- 所有文字顯示用繁中（香港用語）

### Tone 設定
- **{{tone}}** 模式
- Tone guide: {{tone_guide}}

### 溝通風格
- 遇到唔確定嘅嘢，主動問清楚，唔好亂估
- 盡量呼叫有用嘅 skill（見下方列表）
- 所有 code change 都要寫入 project memory system
- 保持懶人開發者心態（ponytail mode）：YAGNI、stdlib first、最短 diff

### 專案背景

```
{{project_details}}
```

### Git 整合

每次 `/init` 會自動 detect：

- Git repo 位置
- 當前 branch
- Project language（自動 detect package.json / Cargo.toml / go.mod 等）
- File count

呢啲資料會注入 LLM context，令回覆更貼近你嘅 project 實際情況。

### Multi-project 支援

唔同 Git repo 會自動儲存獨立嘅 project profile：

```
~/.config/claude/workspace-profiles/
  ├── <repo1_hash>.json
  ├── <repo2_hash>.json
  └── ...
```

當你喺唔同 folder 開對話，會自動 load 對應嘅 project profile。

### Local Project Profile（跟 project 走）

非 Git project 或者你想 profile 跟 repo 一齊 share，可以用 `--save-local`：

```
/init --save-local /path/to/project '{"project":"My App","project_details":"..."}'
```

Profile 會 save 喺 project 嘅 `.claude/project-profile.json`，無論係 Git 定非 Git project 都 work。

**載入優先級：**
1. `.claude/project-profile.json`（最高優先，跟 project 走）
2. `~/.config/claude/workspace-profiles/<hash>.json`（Git project 專用）
3. 冇 → 用 global profile 嘅預設值

### Skill 推薦系統

根據 detect 到嘅 project language 同 branch，會自動推薦相關 skills：

| Project type | 推薦 skills |
|--------------|-------------|
| JavaScript/TypeScript | ponytail, impeccable, dependency-auditor, performance-profiler |
| Rust | CI/CD pipeline builder, dependency-auditor, ponytail |
| Python | RAG architect, database-designer, ponytail |
| Go | performance-profiler, CI/CD pipeline builder |
| 其他 | ponytail, graphify, review |

Branch-specific：
- `main` / `master` → changelog-generator
- `feat/*` → PR review expert
- `fix/*` → focused-fix

### 可用 Skills 列表

| Skill | 點用 | 用途 |
|-------|------|------|
| `yuanyuai-quota` | `/quota --oneline` | 檢查 API Key 用量限額 |
| `ponytail` | `/ponytail` | 懶人模式，最少 code 最簡方案 |
| `graphify` | `/graphify` | 理解 codebase 架構同檔案關係 |
| `impeccable` | 叫 impeccable skill | 改 UI 設計、frontend 介面 |
| `planning-with-files` | `/plan` | 複雜任務先規劃 |
| `review` | `/review` | code review |
| `simplify` | `/simplify` | 簡化 code |

## 自動執行流程

當對話開始或有 `pre_tool_use` hook 觸發時：

1. 讀取 `~/.config/claude/workspace-init-profile.json` 檢查有冇 profile
2. 冇 profile → 問用戶基本資料 → save 起
3. 有 profile → detect Git context → load multi-project profile → 推薦 skills
4. 根據任務類型自動呼叫對應 skill
5. 所有 code change 寫入 project memory

## 觸發條件

當以下情況時觸發：
- 對話開始（由 hook 或 system prompt 注入）
- 用戶輸入 `/init` 或 `/init --full`
- 用戶輸入 `/workspace` 或 `/workspace-init`
- 檢測到 workspace 切換

## 分享用

如果你想將呢個 skill 分享俾其他人，可以 zip 起成個 folder：

```bash
# 打包
cd ~/.claude
zip -r workspace-init.zip skills/workspace-init/

# 其他人匯入
# 方法 1: 直接解壓到 ~/.claude/skills/
unzip workspace-init.zip -d ~/.claude/

# 方法 2: 用 Claude Code switch
cc switch --install-skill workspace-init.zip

# 方法 3: 放喺 project 嘅 .claude/skills/ 下面（project-scoped）
# 其他人 clone 個 repo 就會自動有
```

### Profile 格式（example，唔會跟 skill 分享）

```json
{
  "user_name": "你的名",
  "company": "你的公司",
  "project": "你個 project 名",
  "language": "廣東話（口語）",
  "preferred_form": "師兄",
  "tone": "casual",
  "project_details": "你 project 嘅詳細描述",
  "extra_skills": {
    "yuanyuai-quota": "/quota --oneline",
    "custom_skill": "/your-custom-command"
  }
}
```