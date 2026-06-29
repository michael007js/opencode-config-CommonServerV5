# opencode-config-CommonServerV5

AI 辅助开发配置的一键安装模板。通过 `init.ps1` 将通用 agents/skills/plans/reviews 配置体系安装到任意项目。

## 快速安装

### 远程安装（推荐）

```powershell
irm https://raw.githubusercontent.com/michael007js/opencode-config-CommonServerV5/master/init.ps1 -OutFile init.ps1; .\init.ps1
```

### 本地安装

```powershell
git clone https://github.com/michael007js/opencode-config-CommonServerV5.git
cd opencode-config-CommonServerV5
.\init.ps1
```

### 指定目标目录

```powershell
.\init.ps1 -TargetDir D:\MyProject
```

### 强制覆盖

```powershell
.\init.ps1 -Force
```

### 无交互全自动

```powershell
.\init.ps1 -NonInteractive
```

## 安装流程（7 步）

| 步骤 | 说明 |
|------|------|
| 1 | 确定安装源（本地 / 远程） |
| 2 | 分析目标项目（名称、技术栈） |
| 3 | 交互式配置（适配/通用模式、约束模块、RTK、扩展包） |
| 4 | 创建目录结构 |
| 5 | 安装模板文件 + 动态生成 AGENTS.md |
| 6 | 安装扩展包（按技术栈匹配） |
| 7 | 安装完成 + 引导 + 目录树扫描（可选） |

## 安装模式

| 模式 | 说明 |
|------|------|
| 适配模式 | 自动替换 `{{PROJECT_NAME}}` 为项目名，按技术栈推荐扩展包 |
| 通用模式 | 安装带占位符的空白模板，手动填写项目信息 |

## 安装内容

- `AGENTS.md` ← 项目根目录（AI 约束规则，动态生成）
- `opencode.json` ← 项目根目录（OpenCode 配置）
- `.ai/agents/` ← PROFILE / MEMORY / planner / annotater / dev-workflow / REVIEW
- `.ai/plans/template/` ← Plan 模板
- `.ai/reviews/template/` ← Review 模板
- `.opencode/skills/rtk/` ← RTK 技能（可选）
- 扩展包 ← 按技术栈自动推荐（如 .NET 项目推荐 dotnet-winforms）

## 扩展包系统

扩展包位于 `templates/addons/`，按技术栈匹配自动推荐安装：

| 扩展包 | 匹配条件 | 额外安装内容 |
|--------|---------|-------------|
| dotnet-winforms | .NET + WinForms 项目 | H-M 约束段、theming.md、component-guide.md、7 个 .NET skills |

## 仓库结构

```
opencode-config-CommonServerV5/
├── init.ps1                          ← 一键安装脚本
├── AGENTS.md                         ← 本仓库的 AI 约束
├── README.md                         ← 本文件
└── templates/                        ← 通用模板源
    ├── agents/                       ← 7 个通用 agents 模板
    │   ├── PROFILE.example.md
    │   ├── MEMORY.example.md
    │   ├── planner.md
    │   ├── annotater.md
    │   ├── dev-workflow.md
    │   ├── dev-workflow-template.md
    │   └── REVIEW.md
    ├── skills/rtk/                   ← 通用 RTK 模板
    ├── plans/template/               ← Plan 模板
    ├── reviews/template/             ← Review 模板
    ├── opencode.json                 ← OpenCode 配置模板
    └── addons/                       ← 项目类型扩展包
        ├── addons.json               ← 扩展包注册表
        └── dotnet-winforms/          ← .NET/WinForms 扩展包
            ├── addon.json
            ├── agents/ (theming.md, component-guide.md)
            ├── agents-extra.md       ← H-M 约束节
            ├── skills/               ← 7 个 .NET skills
            ├── plan-template-dotnet.md
            └── code-review-template-dotnet.md
```
