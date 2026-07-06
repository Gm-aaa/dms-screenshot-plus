# 设计：菜单内语言设置（i18n Settings Menu）

日期：2026-07-06
范围：仅 `bin/dms-screenshot-plus`（+ `README.md` / `config.example` 各一处说明）

## 背景与现状

`dms-screenshot-plus` 是一个纯 bash 的、菜单驱动的 Wayland 截图工具。它**已经具备 i18n 基础设施**：

- `msg <key>` 函数持有完整的 zh/en 双语字符串表。
- 配置项 `DSP_LANG=auto|zh|en`；`_resolve_lang()` 在 `auto` 时按 `LC_ALL/LC_MESSAGES/LANG` 猜测 locale。
- 生效顺序：内置默认 < 配置文件（`$XDG_CONFIG_HOME/dms-screenshot-plus/config`，被 `source`）< 环境变量。

目前**缺**的是：无法在运行时从菜单里切换语言——只能手动改配置文件或导出环境变量。本项目没有独立的 DMS/QML 图形设置面板；"设置"就在这个 bash 菜单内。

## 目标

1. 主菜单新增「设置 / Settings」入口。
2. 设置子菜单内可选「语言」：`自动 / 中文 / English`，当前值有标记。
3. 选中后**写入配置文件持久化**（`DSP_LANG=...`），下次启动仍生效。
4. 切换后主菜单立即用新语言重新渲染。
5. 设置菜单自身文案随当前语言显示（复用 `msg`）。

非目标（YAGNI）：设置面板暂不暴露语言以外的其它配置项；不做独立 GUI；不引入新依赖。

## 设计

### 1. 新增 `msg` 词条

在现有 `case "$k"` 表中追加：

| key | zh | en |
|---|---|---|
| `menu_settings` | 设置 | Settings |
| `title_settings` | 设置 | Settings |
| `set_language` | 语言 | Language |
| `lang_auto` | 自动（跟随系统） | Auto (follow system) |
| `lang_zh` | 中文 | 中文 |
| `lang_en` | English | English |
| `set_back` | 返回 | Back |
| `set_lang_changed` | 语言已切换 | Language changed |

（语言名 `中文 / English` 两语言下都用其本名，便于任意语言下识别。）

### 2. `config_set KEY VALUE` — 持久化 upsert

职责：把 `KEY="VALUE"` 安全写入 `$CONFIG_FILE`。

- `mkdir -p "$CONFIG_DIR"`；文件不存在则视作空。
- 若存在**未注释**的 `^[[:space:]]*KEY=` 行 → 原地替换该行为 `KEY="VALUE"`。
- 否则在文件末尾追加 `KEY="VALUE"`。
- 注释掉的示例行（如从 `config.example` 复制来的 `# DSP_LANG=...`）保持不动——被 `source` 时会忽略，不影响生效。
- 通过写临时文件再 `mv` 覆盖，保证原子性，避免写坏用户配置。
- 值按 shell 双引号安全转义（本场景值只会是 `auto|zh|en`，风险极低，但函数保持通用）。

### 3. `mode_settings()` — 设置子菜单

循环显示，直到用户选「返回」或取消：

```
标题：title_settings
项：  1 <set_language>: <当前语言可读名>
      0 <set_back>
```

- 「语言」→ 调 `settings_language()`。
- 「返回」/取消 → 从函数返回（回到主菜单循环）。

### 4. `settings_language()` — 语言选择

- 列出三项：`lang_auto` / `lang_zh` / `lang_en`。
- 当前项前加 `● ` 标记：对比 `$DSP_LANG` **原始值**（`auto|zh|en`），不是解析后的 `DSP_UI_LANG`。
- 选中映射回 `auto|zh|en` 后：
  1. `config_set DSP_LANG <val>`
  2. 更新内存：`DSP_LANG=<val>`；`DSP_UI_LANG="$(_resolve_lang)"`
  3. `notify "$(msg set_lang_changed)"`
- 取消 → 直接返回，不改动。

### 5. `show_menu()` 改为循环

当前 `show_menu` 是一次性的。改成 `while true`：

- 每轮**重建**标签（`menu_region` 等经 `msg`，读当前 `DSP_UI_LANG`）。
- 主菜单项追加 `5 <menu_settings>`。
- 选中截图动作（region/full/ocr/scroll）→ 执行对应 `mode_*` 后 `return`（结束程序，保持现有行为）。
- 选中设置 → `mode_settings`；`continue` 回到主菜单，标签用新语言。
- 取消（`menu_pick` 返回非 0）→ `exit 0`。

### 6. CLI 与文档

- `main()` 新增子命令 `settings)` → `mode_settings`（并在 `usage()` 中列出）。
- `README.md`：在功能/菜单说明处补一句「菜单内『设置』可切换语言并持久化」。
- `config.example`：`DSP_LANG` 注释处补一句「也可在菜单『设置』中切换」。

## 影响面与风险

- 只改一个脚本文件 + 两处文档；无新依赖，符合"零硬编码 / 优雅降级"风格。
- 复用现有 `menu_pick` 后端抽象，fuzzel/wofi/rofi/bemenu/fzf/term 全部自动适配。
- 唯一有写盘副作用的是 `config_set`；用临时文件 + `mv` 降低损坏风险，且只 upsert 单行、不重排用户其余内容。
- 菜单从"一次性"变"循环"：需确保截图动作路径仍然只执行一次并退出，避免回到菜单造成重复截图。

## 测试要点

- `config_set` 三种情形：空文件追加、已有未注释行替换、仅有注释行时追加（注释保留）。
- 切换到 zh/en/auto 后 `--print-config` 的 `DSP_LANG` 与 `(resolved UI lang)` 正确。
- 切换后主菜单标签立即变语言（循环重建生效）。
- 截图动作执行后正常退出，不回菜单、不重复截图。
- `DSP_MENU_BACKEND=term` 下非交互/交互路径可用（便于无 GUI 冒烟测试）。
