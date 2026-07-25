# workspace-init — Claude Code Workspace Personalisation Skill

![GitHub release](https://img.shields.io/badge/version-2.1.0-blue)
![Claude Code](https://img.shields.io/badge/Claude%20Code-✓-purple)

**workspace-init** 係一個 Claude Code skill，每次對話開始時自動注入你嘅 workspace 背景、身份、語言偏好同 project context。

**目的：** 提高 LLM 嘅 cache hit rate、減少重複解釋、令每次對話更個人化。

---

## 功能

- ✅ 第一次用 `/init` 問你嘅名、公司、語言偏好、tone，然後記住
- ✅ 每次對話自動注入 context，唔使再重複講「我用廣東話」、「唔好亂估」
- ✅ 自動 call 其他 skills（ponytail、graphify、yuanyuai-quota 等）
- ✅ 支援多種語言（廣東話、普通話、English、其他）
- ✅ **Git 整合** — 自動 detect branch、project language
- ✅ **Tone 設定** — casual / formal / technical / friendly / minimal
- ✅ **Skill 推薦系統** — 根據 project language 同 branch 推薦相關 skills
- ✅ **Profile 匯出/匯入** — backup 或搬去第二部機
- ✅ **多 project 支援** — 唔同 folder 自動 detect 用唔同 profile
- ✅ 所有資料自己控制，唔會洩漏俾其他人

## 安裝

### 方法 1：快速安裝（推薦）

```bash
curl -L -o /tmp/hkinit.zip https://github.com/ricehung29/workspace-hkinit-skill/archive/refs/heads/main.zip
unzip /tmp/hkinit.zip -d /tmp/hkinit
cp -r /tmp/hkinit/workspace-hkinit-skill-main/skills/workspace-init ~/.claude/skills/
```

### 方法 2：直接 clone

```bash
git clone https://github.com/ricehung29/workspace-hkinit-skill.git /tmp/hkinit
cp -r /tmp/hkinit/skills/workspace-init ~/.claude/skills/
```

### 方法 3：Project-scoped（跟 repo 分享）

如果你想將 skill 綁定喺某個 project，其他人 clone 就有：

```bash
cp -r ~/.claude/skills/workspace-init .claude/skills/
git add .claude/skills/workspace-init
git commit -m "add workspace-init skill"
```

## 首次使用

開一個新對話，然後輸入：

```
/init
```

Skill 會問你：

1. **你叫咩名？** — 英文名 / 中文名 / 代號都得
2. **你嘅公司 / 團隊名？** — optional，可以 skip
3. **你個 project 係咩？** — 簡短描述
4. **你想用咩語言交流？** — 廣東話 / 普通話 / English / 其他
5. **你嘅稱呼偏好？** — 例如「師兄」、「大佬」、「你」
6. **你想用咩 tone？** — casual / formal / technical / friendly / minimal

之後資料會 save 喺 `~/.config/claude/workspace-init-profile.json`，唔會再問。

## 用法

| 指令 | 功能 |
|------|------|
| `/init` | 重新注入 workspace context（自動 detect Git + 推薦 skills） |
| `/init --full` | 完整版（含 quota check + memory 狀態） |
| `/init --reset` | 重置所有已儲存嘅資料 |
| `/init --lang 廣東話` | 直接切換語言，唔使重置 |
| `/init --tone formal` | 設定 tone（casual/formal/technical/friendly/minimal） |
| `/init --export` | 匯出 profile 做 JSON |
| `/init --export my-backup.json` | 匯出到指定檔案 |
| `/init --import my-backup.json` | 匯入 profile |
| `/init --list-projects` | 列出所有已儲存嘅 project profiles |
| `/init --save-project <dir> <json>` | 儲存 project-specific profile（`~/.config/claude/`） |
| `/init --save-local|--sl <dir> <json>` | 儲存 profile 喺 `.claude/` 入面，自動 merge global profile |
| `/init --update` | 自動更新 workspace-init 到最新版 |

## 更新

```bash
/init --update
# 或者手動：
curl -sL https://raw.githubusercontent.com/ricehung29/workspace-hkinit-skill/main/skills/workspace-init/scripts/update.sh | bash
```

## 技術細節

### Git 整合

每次 `/init` 會自動 detect：
- Git repo 位置
- 當前 branch
- Project language（自動 detect `package.json` / `Cargo.toml` / `go.mod` 等）
- File count

呢啲資料會注入 LLM context，令回覆更貼近你嘅 project 實際情況。

### Tone 設定

| Tone | 效果 |
|------|------|
| `casual`（預設） | 輕鬆自然，可以加 slang |
| `formal` | 正式書面語，structure 清晰 |
| `technical` | 精準直接，多 spec 同數據 |
| `friendly` | 好似同朋友傾偈，可以 emoji |
| `minimal` | 只講重點，最短回覆 |

### Skill 推薦系統

根據 detect 到嘅 project language 同 branch 自動推薦：

- **JavaScript/TypeScript** → ponytail, impeccable, dependency-auditor
- **Rust** → CI/CD, dependency-auditor, ponytail
- **Python** → RAG architect, database-designer, ponytail
- **Go** → performance-profiler, CI/CD
- **Branch `main`** → 推 changelog-generator
- **Branch `feat/*`** → 推 PR review expert
- **Branch `fix/*`** → 推 focused-fix

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

非 Git project 或者你想 profile 跟 repo 一齊 share，可以用 `--save-local`（或 `--sl`）：

```bash
/init --save-local /path/to/project '{"project":"My App","project_details":"..."}'
# 或者短版
/init --sl /path/to/project '{"project":"My App","project_details":"..."}'
```

`--save-local` 會自動 merge global profile 嘅 `user_name`、`company`、`language`，所以你只需提供 project 相關嘅 field 就得。

Profile 會 save 喺 project 嘅 `.claude/project-profile.json`，無論係 Git 定非 Git project 都 work。

**載入優先級：**
1. `.claude/project-profile.json`（最高優先，跟 project 走）
2. `~/.config/claude/workspace-profiles/<hash>.json`（Git project 專用）
3. 冇 → 用 global profile 嘅預設值

### Profile 位置

```
~/.config/claude/workspace-init-profile.json          # 主 profile
~/.config/claude/workspace-profiles/                  # multi-project profiles（舊方式）
.claude/project-profile.json                          # local project profile（新方式，跟 project 走）
```

權限：`chmod 600`（僅 owner 可讀寫），唔會俾 git 追蹤。

### 依賴

- Claude Code（已安裝）
- `jq`（multi-project 同 profile 匯出/匯入用）：`brew install jq`
- 其他 skills（optional）：ponytail、graphify、yuanyuai-quota 等，冇嘅話就 skip

---

## 解除安裝

```bash
rm -rf ~/.claude/skills/workspace-init
rm -f ~/.config/claude/workspace-init-profile.json
rm -rf ~/.config/claude/workspace-profiles
```

## License

MIT