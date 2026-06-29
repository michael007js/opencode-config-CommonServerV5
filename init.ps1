<#
.SYNOPSIS
    opencode-config 交互式安装脚本 — 万能通用模版版

.DESCRIPTION
    轻量安装脚本：检测项目名称和类型，交互式选择安装模块，
    生成适配当前项目的 AI 辅助开发模板。

.PARAMETER TargetDir
    目标项目目录（默认为当前工作目录）

.PARAMETER Force
    强制覆盖已存在的文件（默认跳过）

.PARAMETER NonInteractive
    非交互模式：使用默认选项自动安装

.EXAMPLE
    .\init.ps1
    .\init.ps1 -TargetDir D:\MyProject -Force
    .\init.ps1 -NonInteractive
#>

$TargetDir      = (Get-Location).Path
$Force          = $false
$NonInteractive = $false

for ($i = 0; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        { $_ -in '-TargetDir', '-TargetDirectory' } { $TargetDir = $args[++$i]; break }
        { $_ -in '-Force' } { $Force = $true; break }
        { $_ -in '-NonInteractive', '-Quiet', '-Yes' } { $NonInteractive = $true; break }
        { $_ -in '-?', '-Help', '--help' } {
            Write-Host @"

用法: init.ps1 [-TargetDir <路径>] [-Force] [-NonInteractive]

  -TargetDir      目标项目目录（默认当前目录）
  -Force          强制覆盖已存在的文件
  -NonInteractive 非交互模式，使用默认选项自动安装

  管道执行: irm .../init.ps1 | iex
  本地执行: .\init.ps1 -TargetDir D:\MyProject -Force

"@
            return
        }
    }
}

$ErrorActionPreference = 'Stop'

# ============================================================
# 常量
# ============================================================

$RepoOwner  = 'michael007js'
$RepoName   = 'opencode-config-CommonServerV5'
$RepoBranch = 'master'
$RepoUrl    = "https://github.com/$RepoOwner/$RepoName.git"

$TemplatesDir = 'templates'

# ============================================================
# 辅助函数
# ============================================================

function Write-Step {
    param([string]$Message)
    Write-Host "`n  $Message" -ForegroundColor Cyan
}

function Write-Ok {
    param([string]$Message)
    Write-Host "  [OK] $Message" -ForegroundColor Green
}

function Write-Skip {
    param([string]$Message)
    Write-Host "  [--] $Message" -ForegroundColor DarkGray
}

function Write-Warn {
    param([string]$Message)
    Write-Host "  [!!] $Message" -ForegroundColor Yellow
}

function Write-Fail {
    param([string]$Message)
    Write-Host "  [XX] $Message" -ForegroundColor Red
}

function Read-Choice {
    param(
        [string]$Prompt,
        [string]$Default = 'Y',
        [string[]]$ValidChoices = @('Y','N')
    )
    if ($NonInteractive) { return $Default }
    $choices = $ValidChoices -join '/'
    Write-Host "  ? $Prompt [$choices] (默认 $Default): " -NoNewline -ForegroundColor Yellow
    try {
        $input = (Read-Host).Trim().ToUpper()
        if (-not $input) { return $Default }
        if ($input -in $ValidChoices) { return $input }
        return $Default
    } catch {
        return $Default
    }
}

function Read-MultiChoice {
    param(
        [string]$Prompt,
        [hashtable]$Options,
        [string[]]$Defaults
    )
    if ($NonInteractive) { return $Defaults }
    Write-Host "  ? $Prompt" -ForegroundColor Yellow
    Write-Host "    输入编号，空格分隔（默认 $($Defaults -join ' ')): " -NoNewline -ForegroundColor DarkGray
    try {
        $input = (Read-Host).Trim()
        if (-not $input) { return $Defaults }
        $selected = $input -split '\s+' | Where-Object { $_ -in $Options.Keys }
        if ($selected.Count -eq 0) { return $Defaults }
        return $selected
    } catch {
        return $Defaults
    }
}

function Get-ProjectName {
    param([string]$Dir)
    $checks = @(
        @{ File = 'pubspec.yaml'; Pattern = 'name:\s*(\S+)' }
        @{ File = 'package.json'; Pattern = '"name"\s*:\s*"([^"]+)"'; Json = $true }
        @{ File = 'Cargo.toml'; Pattern = 'name\s*=\s*"([^"]+)"' }
        @{ File = 'pyproject.toml'; Pattern = 'name\s*=\s*"([^"]+)"' }
        @{ File = 'go.mod'; Pattern = 'module\s+(\S+)'; Top = 5 }
    )
    foreach ($c in $checks) {
        $p = Join-Path $Dir $c.File
        if (Test-Path -LiteralPath $p) {
            try {
                $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8
                if ($c.Top) { $raw = ($raw -split "`n" | Select-Object -First $c.Top) -join "`n" }
                if ($c.Json) {
                    $j = $raw | ConvertFrom-Json
                    if ($j.name) { return $j.name }
                } elseif ($raw -match $c.Pattern) { return $Matches[1] }
            } catch {}
        }
    }
    $csproj = Get-ChildItem -LiteralPath $Dir -Filter '*.csproj' -Depth 0 -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($csproj) { return $csproj.BaseName }
    foreach ($gf in @('settings.gradle', 'settings.gradle.kts')) {
        $gp = Join-Path $Dir $gf
        if (Test-Path -LiteralPath $gp) {
            try { $c = Get-Content -LiteralPath $gp -Raw -Encoding UTF8; if ($c -match "rootProject\.name\s*=?\s*['`"`"]([^'`"`"]+)['`"`"]") { return $Matches[1] } } catch {}
        }
    }
    $pom = Join-Path $Dir 'pom.xml'
    if (Test-Path -LiteralPath $pom) {
        try { $x = [xml](Get-Content -LiteralPath $pom -Raw -Encoding UTF8); if ($x.project.artifactId) { return $x.project.artifactId } } catch {}
    }
    return (Split-Path -Leaf $Dir)
}

function Get-ProjectFlavor {
    param([string]$Dir)
    $indicators = @(
        @{ File = 'pubspec.yaml'; Name = 'Flutter/Dart' }
        @{ File = '*.csproj'; Name = '.NET'; Glob = $true }
        @{ File = 'package.json'; Name = 'Node.js' }
        @{ File = 'Cargo.toml'; Name = 'Rust' }
        @{ File = 'pyproject.toml'; Name = 'Python' }
        @{ File = 'go.mod'; Name = 'Go' }
        @{ File = 'CMakeLists.txt'; Name = 'C/C++' }
        @{ File = 'build.gradle.kts'; Name = 'Gradle' }
        @{ File = 'build.gradle'; Name = 'Gradle' }
        @{ File = 'pom.xml'; Name = 'Maven' }
        @{ File = 'Package.swift'; Name = 'Swift' }
        @{ File = 'Gemfile'; Name = 'Ruby' }
        @{ File = 'composer.json'; Name = 'PHP' }
    )
    $results = [System.Collections.Generic.List[string]]::new()
    foreach ($ind in $indicators) {
        $found = if ($ind.Glob) {
            Get-ChildItem -LiteralPath $Dir -Filter $ind.File -Depth 2 -ErrorAction SilentlyContinue | Select-Object -First 1
        } else {
            Test-Path -LiteralPath (Join-Path $Dir $ind.File)
        }
        if ($found) { $results.Add($ind.Name) }
    }
    if ($results.Count -eq 0) { return @('Unknown') }
    return $results.ToArray()
}

function New-DirectoryTree {
    param([string]$Dir, [int]$MaxDepth = 4)
    $excludePatterns = @('[\\/]bin$', '[\\/]obj$', '[\\/]node_modules$', '[\\/]\.git$', '[\\/]\.idea$', '[\\/]\.vs$',
                         '[\\/]\.ai$', '[\\/]\.opencode$', '[\\/]\dist$', '[\\/]\coverage$', '[\\/]__pycache__$',
                         '[\\/]\.venv$', '[\\/]venv$', '[\\/]\target$', '[\\/]\.next$', '[\\/]\.gradle$',
                         '[\\/]build$', '[\\/]\.dart_tool$', '[\\/]Pods$', '[\\/]\.build$', '[\\/]DerivedData$')
    $sb = [System.Text.StringBuilder]::new()

    function Should-Exclude($path) {
        foreach ($p in $excludePatterns) { if ($path -match $p) { return $true } }
        return $false
    }

    function Build-Tree {
        param([string]$CurrentDir, [int]$Depth, [string]$Prefix)
        if ($Depth -gt $MaxDepth) { return }
        try {
            $items = Get-ChildItem -LiteralPath $CurrentDir -ErrorAction SilentlyContinue |
                Where-Object { -not (Should-Exclude $_.FullName) } |
                Sort-Object { -not $_.PSIsContainer }, Name
        } catch { return }
        $idx = 0; $total = $items.Count
        foreach ($item in $items) {
            $idx++; $isLast = ($idx -eq $total)
            $connector    = if ($isLast) { "└── " } else { "├── " }
            $childPrefix  = if ($isLast) { '    ' } else { '│   ' }
            if ($item.PSIsContainer) {
                [void]$sb.AppendLine("$Prefix$connector$($item.Name)/")
                Build-Tree -CurrentDir $item.FullName -Depth ($Depth + 1) -Prefix ($Prefix + $childPrefix)
            } else {
                [void]$sb.AppendLine("$Prefix$connector$($item.Name)")
            }
        }
    }

    $rootName = Split-Path -Leaf $Dir
    [void]$sb.AppendLine("$rootName/")
    Build-Tree -CurrentDir $Dir -Depth 1 -Prefix ''
    return $sb.ToString()
}

function Get-MatchingAddons {
    param([string[]]$Flavors, [string]$AddonsDir)
    $addonsJsonPath = Join-Path $AddonsDir 'addons.json'
    if (-not (Test-Path -LiteralPath $addonsJsonPath)) { return @() }

    $addons = (Get-Content -LiteralPath $addonsJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json).addons
    $matched = @()

    foreach ($addon in $addons) {
        $addonMatch = $false
        foreach ($mf in $addon.matchFlavors) {
            foreach ($f in $Flavors) {
                if ($f -like "*$mf*") { $addonMatch = $true; break }
            }
            if ($addonMatch) { break }
        }
        if ($addonMatch) {
            $matched += $addon
        }
    }
    return ,$matched
}

function New-AdaptiveAgentsMd {
    param(
        [string]$ProjectName,
        [string[]]$ProjectFlavor,
        [string]$ConfigDirName,
        [string[]]$SelectedConstraints,
        [string[]]$ExtraConstraintSections,
        [string]$WorklogDir = ''
    )

    $stackLine = $ProjectFlavor -join ' + '

    $baseConstraints = @'
## A. 目录归属（放错 = 迁移 + 重构）

| # | 约束 | 违反后果 |
|---|------|---------|
| A1 | SDK 代码放 `Sdk/`，零 UI 依赖，可独立测试 | SDK 混入 UI 依赖 → 无法独立测试，需迁移 |
| A2 | 框架能力放 `Components/Atomic/`（Theming/DesignTime/AppImageCache） | 纯逻辑类型混入 Composite → 归属错误 |
| A3 | 自绘控件放 `Components/Composite/`（AppButton/AppImage/AppTabPane） | 控件散落在项目根目录 → 归属错误 |
| A4 | 命名空间 = 目录路径（`$projectName.` + 目录路径斜杠换点） | 命名空间不匹配 → 构建失败 |
| A5 | 依赖方向不可逆：上层 → 下层；禁止下层引用上层 | 反向依赖 → 循环依赖，需提取公共层或用事件反转 |

## B. UI / 主题（硬编码 = 违反调色板规则）

| # | 约束 | 违反后果 |
|---|------|---------|
| B1 | 禁止 `Color.FromArgb(...)` / `Color.Xxx` 硬编码颜色 | 必须用 `AppThemePalette` 语义颜色 |
| B2 | 自绘控件走 `OnPaint` + 订阅 `ThemeChanged` | 走 ApplySingle BackColor/ForeColor → 主题切换失效 |
| B3 | 新窗体继承 `AppThemedForm`，不直接继承 `Form` | 直接继承 Form → 主题不生效，生命周期不安全 |
| B4 | 修改调色板必须同步 Light + Dark | 只改一个 → 另一主题下视觉破损 |
| B5 | 自绘控件圆角用离屏位图，Region 赋值前先 Dispose 旧值 | 直接 SetClip 产生 1px 黑边；不释放旧 Region → GDI 泄漏 |

## C. 代码规范（违反 = 构建失败或设计器崩溃）

| # | 约束 | 违反后果 |
|---|------|---------|
| C1 | 遵循项目现有代码风格和命名约定 | 不一致 → 代码可维护性差 |
| C2 | 不引入项目未使用的新框架或库 | 引入 → 与项目定位冲突 |
| C3 | 修改前先理解上下文，不盲目重构 | 盲目重构 → 引入 bug |

## D. 交互与输出（违反 = 被老板判定为冗余错误）

| # | 约束 | 违反后果 |
|---|------|---------|
| D1 | 中文交流，简洁直接 | 英文或冗长 → 被判定为错误 |
| D2 | 给方案说利弊，由老板定决策；有不确定时先确认，不全盘执行 | 不确认 → 做错方向 |
| D3 | 默认只输出结果，不解释 | 冗长解释 → 被判定为错误 |
| D4 | 代码优先输出差异，避免返回完整文件 | 返回完整文件 → 上下文爆炸 |
| D5 | 每次回复结尾打招呼 + 输出实时时间（精确到秒） | 不打招呼 → 老板认为记忆丢失 |

## E. 工作流程（违反 = 被老板判定为不负责任）

| # | 约束 | 违反后果 |
|---|------|---------|
| E1 | 默认最小正确改动，不主动重构大架构 | 过度重构 → 意外破坏 |
| E2 | 不主动引入 WPF/MAUI/Avalonia/ASP.NET/第三方 UI 框架 | 引入 → 与项目定位冲突 |
| E3 | 有价值信息先记录再回答（MEMORY.md / PROFILE.md / 每日笔记） | 不记录 → 下次会话重复踩坑 |
| E4 | 有不确定时先确认，不全盘执行 | 不确认 → 做错方向 |

## F. 文件写入（违反 = 写入失败或内容丢失）

| # | 约束 | 违反后果 |
|---|------|---------|
| F1 | 写入文件必须用 Rider MCP tools 直接读写文本方式，禁止内置 write/edit 写整文件 | 绕过 MCP → 内容丢失或不可控 |
| F2 | 超大文件分段追加，每次 <200 行 | 一次性写入 → 内存溢出或失败 |

## G. 文档同步（违反 = 文档与代码不一致）

| # | 约束 | 违反后果 |
|---|------|---------|
| G1 | 新增/删除源码文件后更新 `directory-tree.md` + 中文注释 | 目录树过期 → AI 放错文件位置 |
| G2 | 修改主题系统后更新 `theming.md` | 主题文档过期 → AI 违反调色板规则 |
| G3 | 修改组件规范后更新 `component-guide.md` | 组件文档过期 → AI 创建控件流程错误 |
| G4 | 修改技术栈/依赖/测试后更新 `tech-stack.md` | 技术栈文档过期 → AI 引入错误依赖 |
| G5 | 有踩坑经验、有价值信息可以更新到 `MEMORY.md` | 记忆文档过时 → AI 无处理经验，反复尝试某个错误 |

## H. 测试规范（违反 = 测试失效或归属错误）

| # | 约束 | 违反后果 |
|---|------|---------|
| H1 | 测试文件放 `Tests/` 目录，由测试项目 `<Compile Include>` 引用 | 测试散落主项目根目录 → 归属错误 |
| H2 | 测试四重隔离：`[Collection]` 串行 + `ResetForTesting` + `Dispose` + Guid Key | 无隔离 → 测试状态残留，断言失败 |
| H3 | MySqlSdk 测试连接字符串用环境变量，禁止硬编码 | 硬编码连接字符串 → 不可移植 |
| H4 | 测试命名空间避免与类型同名（用 `XxxTests` 后缀） | 命名空间与类型冲突 |

## I. Plan 批注审查（违反 = 计划不充分就执行，返工率高）

| # | 约束 | 违反后果 |
|---|------|---------|
| I1 | 涉及3+文件或新架构的改动，Plan 写完后必须经过批注循环（1-6 轮），不可跳过直接执行 | 计划有隐患未暴露 → 实施中途返工 |
| I2 | 批注必须按 `annotater.md` 定义的类型标记（🔴 批注/否决、🟡 补充、🔵 流程图、⏸️ don't implement yet） | 批注格式混乱 → 决策无法追踪、清理 |
| I3 | 每条批注必须有对应决策（✅ 采纳/❌ 不同意/✏️ 调整/⏭️ 跳过）才能推进，决策后立即原地清理 plan.md | 未决策批注堆积 → plan 状态不明 |
| I4 | 批注审查维度必须覆盖：章节与 plan 模板对应 + AGENTS.md 约束体系（目录归属/主题合规/代码规范/依赖方向/测试规范/最小改动） | 审查维度缺失 → 约束违反未被发现 |
| I5 | 仅当所有批注已解决且无新问题时，Plan 状态才可从 `规划中` 改为 `实施中` | 未完成审批就执行 → 方向错误 |
| I6 | 标记 ⏸️ don't implement yet 的项必须在 plan 阶段跟踪表备注，不影响整体状态推进 | 暂缓项丢失 → 后续版本遗漏 |

## J. AI 执行流程（违反 = 流程混乱导致遗漏）

| # | 约束 | 违反后果 |
|---|------|---------|
| J1 | 改动前：判断任务类型 → 选正确目录 → UI判断是否接入主题 | 跳过 → 文件放错或主题未接入 |
| J2 | 改动时：最小改动 + 不破坏 Designer + 不引入新框架 | 破坏 Designer → 设计器崩溃 |
| J3 | 改动后：构建验证 → 测试验证 → 结构变化同步 agents 文档 | 不验证 → 引入构建失败 |
| J4 | 自检6项不通过不得跳过（目录/命名空间/依赖/主题/Designer/最小改动） | 跳过自检 → 约束违反 |

## K. 记忆与记录（违反 = 信息丢失或覆盖）

| # | 约束 | 违反后果 |
|---|------|---------|
| K1 | 长期记忆 = `MEMORY.md`，每日笔记 = `$worklogDir` | 不记录 → 下次会话重复踩坑 |
| K2 | 先读取原内容再更新文件，避免信息覆盖 | 直接覆盖 → 历史记忆丢失 |
| K3 | 临时文件存项目根目录，按日期组织，不提交 git | 临时文件进 git → 仓库污染 |
| K4 | 不等用户说"记住这个"，有价值信息主动记录 | 不主动记录 → 关键信息遗漏 |

## L. 上下文使用（违反 = token浪费或重复劳动）

| # | 约束 | 违反后果 |
|---|------|---------|
| L1 | 不总结历史对话，不重复上下文，只关注当前任务 | 重复上下文 → token浪费 |
| L2 | 禁止复述用户输入 | 复述 → 被判定为冗余错误 |
| L3 | 仅在用户要求时解释，最多 3 行 | 冗长解释 → 被判定为错误 |

## M. 工具使用（违反 = 操作绕过MCP导致不可控）

| # | 约束 | 违反后果 |
|---|------|---------|
| M1 | 对项目的所有操作必须通过 MCP 工具执行，严禁用 `bash` 替代（如 `cat` 替代 `read`、`grep` 替代 `search`） | 绕过 MCP → 操作不可追踪、不可审计 |
'@

    if ($WorklogDir) {
        $baseConstraints = $baseConstraints -replace '\$worklogDir', "``$WorklogDir``"
    } else {
        $baseConstraints = $baseConstraints -replace '\$worklogDir', '（待配置）'
    }

    $allConstraintSections = $baseConstraints
    if ($ExtraConstraintSections) {
        $allConstraintSections += "`n`n" + ($ExtraConstraintSections -join "`n`n")
    }

    $constraintLetters = [regex]::Matches($allConstraintSections, '## ([A-Z])\.') |
        ForEach-Object { $_.Groups[1].Value }

    $constraintConfirmLines = foreach ($letter in $constraintLetters) {
        $idx = [array]::IndexOf($constraintLetters, $letter) + 1
        switch ($letter) {
            'A' { "$idx. [A类] 目录归属约束关键词" }
            'B' { "$idx. [B类] UI/主题约束关键词" }
            'C' { "$idx. [C类] 代码规范约束关键词" }
            'D' { "$idx. [D类] 交互输出约束关键词" }
            'E' { "$idx. [E类] 工作流程约束关键词" }
            'F' { "$idx. [F类] 文件写入约束关键词" }
            'G' { "$idx. [G类] 文档同步约束关键词" }
            'H' { "$idx. [H类] 测试规范约束关键词" }
            'I' { "$idx. [I类] Plan批注审查约束关键词" }
            'J' { "$idx. [J类] AI执行流程约束关键词" }
            'K' { "$idx. [K类] 记忆记录约束关键词" }
            'L' { "$idx. [L类] 上下文使用约束关键词" }
            'M' { "$idx. [M类] 工具使用约束关键词" }
            default { "$idx. [${letter}类] 约束关键词" }
        }
    }
    $confirmBlock = $constraintConfirmLines -join "`n"

    @"
# AGENTS

本文档是给 AI 助手快速读取的项目执行上下文。目标是用最少的阅读成本，建立对 ``$projectName`` 的稳定工作认知。

# 启动门控（不可跳过）

在执行任何用户任务之前，你必须完成以下步骤：

# 步骤1：读取上下文文件

## 必读（启动时）

| # | 文件 | 必须提取的关键信息 |
|---|------|------------------|
| 1 | [PROFILE.md]($ConfigDirName/agents/PROFILE.md) | 用户称呼（老板）、交流语言（中文）、决策风格（给方案说利弊，由他定）、结尾招呼要求 |
| 2 | [directory-tree.md]($ConfigDirName/agents/directory-tree.md) | 文件放置规则 |
| 3 | [tech-stack.md]($ConfigDirName/agents/tech-stack.md) | 技术栈、自研SDK清单、外部依赖、测试命令、AI工作约束 |
| 4 | [MEMORY.md]($ConfigDirName/agents/MEMORY.md) | 开发注意事项（禁止项）、技术决策记录、项目经验规则、常用命令 |

## 按需（任务触发时读取）

| # | 文件 | 触发条件 | 关键信息 |
|---|------|---------|---------|
| 5 | [planner.md]($ConfigDirName/agents/planner.md) | Plan 制定任务 | 计划制定流程、Skill 声明、自检清单 |
| 6 | [annotater.md]($ConfigDirName/agents/annotater.md) | Plan/批注任务 | 批注审查流程 |
| 7 | [theming.md]($ConfigDirName/agents/theming.md) | UI/控件任务 | 主题系统架构、API 约定、扩展约束 |
| 8 | [component-guide.md]($ConfigDirName/agents/component-guide.md) | 新增/修改控件任务 | 组件规范、步骤、检查清单 |

⚠️ 读完必读文件后，对照下方「强制记忆清单」确认理解。按需文件在对应任务触发时再读取。

# 步骤2：按任务类型提取规则

执行任务时，根据任务类型从对应文件提取约束规则：

| 任务类型 | 必须遵守的文件规则 |
|----------|-------------------|
| UI / 控件 | directory-tree.md 的放置规则 + tech-stack.md 的主题系统 + MEMORY.md 的开发注意事项 |
| SDK / 基础设施 | directory-tree.md 的 Sdk/ 规则 + tech-stack.md 的依赖约束 + MEMORY.md 的项目经验 |
| 目录操作 | directory-tree.md 的完整结构 + MEMORY.md 的命名空间=目录路径规则 |
| Plan / 批注 | planner.md 的制定流程 + annotater.md 的批注审查流程 + I类约束 |
| 测试 | tech-stack.md 的测试框架/命令 + MEMORY.md 的测试四重隔离 |
| 文档 | MEMORY.md 的文档同步规则 |

⚠️ 未完成步骤1直接执行任务，将因上下文缺失导致：文件放错目录需迁移、颜色硬编码违反调色板规则、命名空间不匹配构建失败。

---

# 强制记忆清单（红线 — 违反即错误）

以下是从 MEMORY.md 和项目经验中提炼的**绝对禁止项**。AI 必须逐条理解并遵守，不得以"忘记"、"上下文太长"为由绕过。

$allConstraintSections

---

# 步骤3：约束确认输出（强制 — 不可用占位符）

读完上下文文件后，首次回复必须输出以下确认标记。**禁止用 "xxx" 占位符**，必须写出每条约束的具体内容关键词：

``````
上下文已加载: PROFILE ✓ 目录树 ✓ 技术栈 ✓ 记忆 ✓  约束 ✓
我已经确认了老板对我的约束：
$confirmBlock
``````

**每类至少写出总结具体内容**，证明你不是在走过场。如果写不出具体内容，说明你没有真正读完上下文文件，必须重新读取。

---

# 任务执行前自检（每次改动前必须过）

在执行任何代码改动前，逐项自检：

| # | 自检项 | ✅ 通过条件 |
|---|--------|------------|
| 1 | 目录归属 | 文件放在正确目录（Sdk/Atomic/Composite/Tests/） |
| 2 | 命名空间 | 命名空间 = ``$projectName.`` + 目录路径 |
| 3 | 依赖方向 | 无反向依赖（下层不引用上层） |
| 4 | 主题合规 | UI 代码用 AppThemePalette，无硬编码颜色 |
| 5 | Designer 安全 | 手写逻辑不在 Designer.cs 中 |
| 6 | 最小改动 | 只改必要的，不重构不相关部分 |

自检不通过的项目，必须先修正再继续执行，不得跳过。

---

# 执行方式（任务派发时选择）

在开始执行多步骤任务前，根据任务复杂度和上下文需求选择执行方式：

| 方式 | 适用场景 | 机制 | 优势 |
|------|---------|------|------|
| **Subagent 驱动（推荐）** | 多个独立子任务、可并行的工作 | 每个 Task 派一个新 subagent 执行，任务间审查，迭代快 | 隔离上下文、并行加速、审查节点清晰 |
| **内联执行** | 有顺序依赖、需要共享上下文的任务 | 在当前会话中逐 Task 执行，带检查点审查 | 上下文连续、调试方便、无需重复加载上下文 |

## Subagent 驱动模式

1. 将任务拆分为独立子任务，每个子任务有明确输入和预期输出
2. 每个子任务派一个新 subagent（`Task` 工具 + `subagent_type`）
3. 可并行的子任务同时派发，单条消息内多个 Task 调用
4. subagent 返回结果后，审查产出是否符合预期
5. 审查通过 → 继续下一个；不通过 → 反馈修正或重新派发
6. 所有子任务完成后汇总结果

## 内联执行模式

1. 将任务拆分为有序步骤，每步有检查点
2. 在当前会话中逐步执行，完成一步后暂停
3. 在检查点审查：构建是否通过、约束是否满足
4. 审查通过 → 继续下一步；不通过 → 修正后继续
5. 所有步骤完成后汇总结果
"@
}

function Install-File {
    param([string]$SourcePath, [string]$DestinationPath, [string]$Label = '')
    $destDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    if ((Test-Path -LiteralPath $DestinationPath) -and -not $Force) {
        Write-Skip "已存在: $(if ($Label) { $Label } else { Split-Path -Leaf $DestinationPath })"
        return $false
    }
    $content = Get-Content -LiteralPath $SourcePath -Raw -Encoding UTF8
    $content = $content -replace '\{\{PROJECT_NAME\}\}', $script:projectName
    $content = $content -replace 'CommonServerV5', $script:projectName
    Set-Content -LiteralPath $DestinationPath -Value $content -Encoding UTF8 -NoNewline
    Write-Ok "安装: $(if ($Label) { $Label } else { Split-Path -Leaf $DestinationPath })"
    return $true
}

function Install-GeneratedFile {
    param([string]$DestinationPath, [string]$Content, [string]$Label = '')
    $destDir = Split-Path -Parent $DestinationPath
    if (-not (Test-Path -LiteralPath $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    if ((Test-Path -LiteralPath $DestinationPath) -and -not $Force) {
        Write-Skip "已存在: $(if ($Label) { $Label } else { Split-Path -Leaf $DestinationPath })"
        return $false
    }
    Set-Content -LiteralPath $DestinationPath -Value $Content -Encoding UTF8 -NoNewline
    Write-Ok "生成: $(if ($Label) { $Label } else { Split-Path -Leaf $DestinationPath })"
    return $true
}

function Install-Addon {
    param(
        [string]$AddonPath,
        [string]$ConfigRoot,
        [string]$ProjectName,
        [string]$ConfigDirName
    )

    $addonJsonPath = Join-Path $AddonPath 'addon.json'
    if (-not (Test-Path -LiteralPath $addonJsonPath)) {
        Write-Warn "Addon 清单缺失: $addonJsonPath"
        return
    }

    $addon = Get-Content -LiteralPath $addonJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    Write-Host "  安装扩展: $($addon.name)" -ForegroundColor Magenta

    # 安装 agents 文件
    if ($addon.agents) {
        foreach ($agentFile in $addon.agents) {
            $srcPath = Join-Path $AddonPath "agents/$agentFile"
            if (Test-Path -LiteralPath $srcPath) {
                $dstPath = Join-Path $ConfigRoot "agents/$agentFile"
                $null = Install-File -SourcePath $srcPath -DestinationPath $dstPath -Label "agents/$agentFile"
            } else {
                Write-Warn "Addon agents 文件缺失: $agentFile"
            }
        }
    }

    # 安装 skills
    if ($addon.skills) {
        foreach ($skillCategory in @('core', 'domain', 'external')) {
            $skillList = $addon.skills.$skillCategory
            if ($skillList) {
                foreach ($skillName in $skillList) {
                    $srcSkillDir = Join-Path $AddonPath "skills/$skillCategory/$skillName"
                    if (Test-Path -LiteralPath $srcSkillDir) {
                        $dstSkillDir = Join-Path $ConfigRoot "skills/$skillCategory/$skillName"
                        if (-not (Test-Path -LiteralPath $dstSkillDir) -or $Force) {
                            if (Test-Path -LiteralPath $dstSkillDir) { Remove-Item -LiteralPath $dstSkillDir -Recurse -Force }
                            Copy-Item -LiteralPath $srcSkillDir -Destination $dstSkillDir -Recurse -Force
                            Get-ChildItem -LiteralPath $dstSkillDir -Recurse -File | ForEach-Object {
                                try {
                                    $c = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
                                    $c = $c -replace '\{\{PROJECT_NAME\}\}', $ProjectName
                                    $c = $c -replace 'CommonServerV5', $ProjectName
                                    Set-Content -LiteralPath $_.FullName -Value $c -Encoding UTF8 -NoNewline
                                } catch {}
                            }
                            Write-Ok "安装: skills/$skillCategory/$skillName/"
                        } else {
                            Write-Skip "已存在: skills/$skillCategory/$skillName/"
                        }
                    }
                }
            }
        }
    }

    # 安装 plan templates
    if ($addon.planTemplates) {
        foreach ($tpl in $addon.planTemplates) {
            $srcPath = Join-Path $AddonPath $tpl
            if (Test-Path -LiteralPath $srcPath) {
                $dstPath = Join-Path $ConfigRoot "plans/template/$tpl"
                $null = Install-File -SourcePath $srcPath -DestinationPath $dstPath -Label "plans/template/$tpl"
            }
        }
    }

    # 收集额外约束
    $extraConstraints = ''
    if ($addon.agentsExtra) {
        $extraPath = Join-Path $AddonPath $addon.agentsExtra
        if (Test-Path -LiteralPath $extraPath) {
            $extraConstraints = Get-Content -LiteralPath $extraPath -Raw -Encoding UTF8
            $extraConstraints = $extraConstraints -replace '\{\{PROJECT_NAME\}\}', $ProjectName
            $extraConstraints = $extraConstraints -replace 'CommonServerV5', $ProjectName
        }
    }

    return $extraConstraints
}

# ============================================================
# 主流程
# ============================================================

Write-Host ''
Write-Host '  +=============================================================+' -ForegroundColor Magenta
Write-Host '  |     opencode-config 交互式安装脚本                            |' -ForegroundColor Magenta
Write-Host '  |     万能通用模版 — 适配任意项目语言                            |' -ForegroundColor Magenta
Write-Host '  +=============================================================+' -ForegroundColor Magenta

# ── 1. 确定仓库源 ─────────────────────────────────────
Write-Step '[1/7] 确定安装源...'

$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$tempClone = $null
$repoDir   = $null

$localTemplatesDir = Join-Path $scriptDir $TemplatesDir
if ((Test-Path -LiteralPath (Join-Path $scriptDir 'init.ps1')) -and
    (Test-Path -LiteralPath $localTemplatesDir)) {
    $repoDir = $scriptDir
    Write-Ok "本地仓库: $repoDir"
} else {
    Write-Host '  远程执行模式，正在获取仓库...' -ForegroundColor DarkGray
        $tempClone = Join-Path $env:TEMP "opencode-config-$(Get-Random)"
        $gotRepo = $false

        if (Get-Command git -ErrorAction SilentlyContinue) {
            try {
                git clone --depth 1 -b $RepoBranch $RepoUrl $tempClone 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $tempClone)) {
                    $repoDir = $tempClone; $gotRepo = $true
                }
            } catch {}
        }
        if (-not $gotRepo) {
            $zipUrl = "https://github.com/$RepoOwner/$RepoName/archive/refs/heads/$RepoBranch.zip"
            $zipPath = Join-Path $env:TEMP "opencode-config-$(Get-Random).zip"
            try {
                Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $env:TEMP)
                $repoDir = Join-Path $env:TEMP "$RepoName-$RepoBranch"
                $gotRepo = $true
            } catch {
                Write-Fail "获取仓库失败: $_"; exit 1
            } finally {
                if (Test-Path -LiteralPath $zipPath) { Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue }
            }
        }
}

$sourceTemplatesDir = Join-Path $repoDir $TemplatesDir
$sourceAddonsDir = Join-Path $sourceTemplatesDir 'addons'

if (-not (Test-Path -LiteralPath $sourceTemplatesDir)) {
    Write-Fail "源目录不存在: $sourceTemplatesDir"; exit 1
}

# ── 2. 分析目标项目 ────────────────────────────────────
Write-Step '[2/7] 分析目标项目...'

$targetDir = (Resolve-Path -LiteralPath $TargetDir).Path
$script:projectName = Get-ProjectName -Dir $targetDir
$projectFlavor = Get-ProjectFlavor -Dir $targetDir
$configDirName = '.opencode'
$configRoot = Join-Path $targetDir $configDirName

Write-Host "  项目名:     $($script:projectName)" -ForegroundColor White
Write-Host "  技术栈:     $($projectFlavor -join ' + ')" -ForegroundColor White
Write-Host "  配置目录:   $configDirName/" -ForegroundColor White

# ── 3. 交互式配置 ──────────────────────────────────────
Write-Step '[3/7] 交互式配置...'

# 3.1 安装模式
$adaptMode = Read-Choice "是否适配当前项目 ($($script:projectName))?" 'Y' @('Y','N')
$script:adaptProject = ($adaptMode -eq 'Y')

if ($script:adaptProject) {
    Write-Host "  > 适配模式：模板将替换为当前项目信息" -ForegroundColor Green
} else {
    Write-Host "  > 通用模式：安装带占位符的空白模板" -ForegroundColor Yellow
    $script:projectName = '{{PROJECT_NAME}}'
}

# 3.2 项目背景信息
$script:projectDesc = ''
$script:projectPlatform = ''
$script:worklogDir = ''
if ($script:adaptProject) {
    Write-Host ''
    Write-Host '  请输入项目背景信息:' -ForegroundColor White
    Write-Host '  项目描述 (如: C#/.NET 代码助手，正在开发 MyApp): ' -NoNewline -ForegroundColor Yellow
    try { $script:projectDesc = (Read-Host).Trim() } catch {}
    Write-Host '  支持平台 (如: Windows / Linux / 跨平台): ' -NoNewline -ForegroundColor Yellow
    try { $script:projectPlatform = (Read-Host).Trim() } catch {}
    Write-Host '  每日笔记目录 (如: C:/_worklog，默认不配置): ' -NoNewline -ForegroundColor Yellow
    try { $script:worklogDir = (Read-Host).Trim() } catch {}
}

# 3.2 约束模块选择
Write-Host ''
Write-Host '  基础约束模块（A-G）:' -ForegroundColor White
$baseConstraintOptions = @{
    '1' = 'A. 代码规范'
    '2' = 'B. 交互输出'
    '3' = 'C. 工作流程'
    '4' = 'D. 文件写入'
    '5' = 'E. 文档同步'
    '6' = 'F. Plan批注审查'
    '7' = 'G. 工具使用'
}
$selectedConstraints = Read-MultiChoice '选择基础约束模块（默认全选）' $baseConstraintOptions @('1','2','3','4','5','6','7')

# 3.3 RTK 技能
$installRtk = Read-Choice "是否安装 RTK 技能?" 'Y' @('Y','N')
$script:installRtk = ($installRtk -eq 'Y')

# 3.4 扩展包
$script:extraConstraintSections = @()
$script:selectedAddons = @()

if ($sourceAddonsDir -and (Test-Path -LiteralPath $sourceAddonsDir)) {
    $matchedAddons = Get-MatchingAddons -Flavors $projectFlavor -AddonsDir $sourceAddonsDir

    if ($matchedAddons.Count -gt 0) {
        Write-Host ''
        Write-Host "  检测到技术栈匹配的扩展包:" -ForegroundColor White
        foreach ($addon in $matchedAddons) {
            $installAddon = Read-Choice "  是否安装 $($addon.name)?" 'Y' @('Y','N')
            if ($installAddon -eq 'Y') {
                $script:selectedAddons += $addon
            }
        }
    }

    # 也列出所有扩展包供选择
    $allAddonsJson = Join-Path $sourceAddonsDir 'addons.json'
    if (Test-Path -LiteralPath $allAddonsJson) {
        $allAddons = (Get-Content -LiteralPath $allAddonsJson -Raw -Encoding UTF8 | ConvertFrom-Json).addons
        $unmatched = @($allAddons | Where-Object {
            $aid = $_.id
            -not (@($matchedAddons) | Where-Object { $_.id -eq $aid })
        })
        if ($unmatched.Count -gt 0) {
            Write-Host ''
            Write-Host '  其他可用扩展包:' -ForegroundColor DarkGray
            foreach ($addon in $unmatched) {
                $installAddon = Read-Choice "  是否安装 $($addon.name)?" 'N' @('Y','N')
                if ($installAddon -eq 'Y') {
                    $script:selectedAddons += $addon
                }
            }
        }
    }
}

# 3.5 确认配置
Write-Host ''
Write-Host '  ─── 安装配置确认 ──────────────────────────' -ForegroundColor Cyan
Write-Host "  安装模式:   $(if ($script:adaptProject) { '适配当前项目' } else { '通用模板' })" -ForegroundColor White
Write-Host "  项目名:     $($script:projectName)" -ForegroundColor White
Write-Host "  项目描述:   $(if ($script:projectDesc) { $script:projectDesc } else { '（默认）' })" -ForegroundColor White
Write-Host "  支持平台:   $(if ($script:projectPlatform) { $script:projectPlatform } else { '（默认）' })" -ForegroundColor White
Write-Host "  技术栈:     $($projectFlavor -join ' + ')" -ForegroundColor White
Write-Host "  笔记目录:   $(if ($script:worklogDir) { $script:worklogDir } else { '（未配置）' })" -ForegroundColor White
Write-Host "  约束模块:   $($selectedConstraints -join ', ')" -ForegroundColor White
Write-Host "  RTK 技能:   $(if ($script:installRtk) { '是' } else { '否' })" -ForegroundColor White
Write-Host "  扩展包:     $(if ($script:selectedAddons.Count -gt 0) { ($script:selectedAddons | ForEach-Object { $_.name }) -join ', ' } else { '无' })" -ForegroundColor White

$confirm = Read-Choice '确认安装?' 'Y' @('Y','N')
if ($confirm -ne 'Y') {
    Write-Host '  安装已取消。' -ForegroundColor Yellow
    return
}

# ── 4. 创建目录结构 ────────────────────────────────────
Write-Step '[4/7] 创建目录结构...'

$dirsToCreate = @(
    $configRoot
    (Join-Path $configRoot 'agents')
    (Join-Path $configRoot 'plans/template')
    (Join-Path $configRoot 'plans/research')
    (Join-Path $configRoot 'reviews/template')
    (Join-Path $configRoot 'scripts')
)

foreach ($d in $dirsToCreate) {
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
        Write-Ok "创建: $($d.Replace("$targetDir\", ''))"
    }
}

# ── 5. 安装模板文件 ───────────────────────────────────
Write-Step '[5/7] 安装模板文件...'

$sourceAgentsDir = Join-Path $sourceTemplatesDir 'agents'
$sourceSkillsDir = Join-Path $sourceTemplatesDir 'skills'
$sourcePlansTplDir = Join-Path $sourceTemplatesDir 'plans/template'
$sourceReviewsTplDir = Join-Path $sourceTemplatesDir 'reviews/template'

# 优先使用 templates/agents/，回退到 .ai/agents/
if (-not (Test-Path -LiteralPath $sourceAgentsDir)) {
    $sourceAgentsDir = Join-Path $sourceTemplatesDir 'agents'
}

# directory-tree.md（自动扫描目标项目）
if ($script:adaptProject) {
    $treeContent = New-DirectoryTree -Dir $targetDir -MaxDepth 4
} else {
    $treeContent = "{{PROJECT_NAME}}/" + "`n" + "（待填写项目目录结构）"
}
$treeMd = @"
# 项目目录树

本文档供 AI 助手阅读。记录 ``$($script:projectName)`` 项目的源码目录结构。

> **维护规则**：每次新增或删除源码文件/目录后，必须同步更新本文档。

---

``````
$treeContent``````
"@
$null = Install-GeneratedFile -DestinationPath (Join-Path $configRoot 'agents/directory-tree.md') -Content $treeMd -Label 'directory-tree.md'

# tech-stack.md
$stackMd = @"
# $($script:projectName) 技术栈

- 项目名：``$($script:projectName)``
- 技术栈：$($projectFlavor -join ' + ')

## 测试

| 项 | 值 |
|----|-----|
| 框架 | （待根据项目实际情况填写） |
| 运行命令 | （待根据项目实际情况填写） |

## 给 AI 的工作约束

- 保持项目的技术栈习惯
- 未经明确要求，不要引入其他框架
- 如需新增依赖包，说明引入原因
"@
$null = Install-GeneratedFile -DestinationPath (Join-Path $configRoot 'agents/tech-stack.md') -Content $stackMd -Label 'tech-stack.md'

# PROFILE.example.md → PROFILE.md
$srcProfile = Join-Path $sourceAgentsDir 'PROFILE.example.md'
$dstProfile = Join-Path $configRoot 'agents/PROFILE.md'
if (Test-Path -LiteralPath $srcProfile) {
    $profileContent = Get-Content -LiteralPath $srcProfile -Raw -Encoding UTF8
    if ($script:projectDesc) {
        $profileContent = $profileContent -replace '- 正在开发 \{\{PROJECT_NAME\}\}', "- $($script:projectDesc)"
    }
    if ($script:projectPlatform) {
        $profileContent = $profileContent -replace '- 支持平台：Windows', "- 支持平台：$($script:projectPlatform)"
    }
    $profileContent = $profileContent -replace '\{\{PROJECT_NAME\}\}', $script:projectName
    if ((Test-Path -LiteralPath $dstProfile) -and -not $Force) {
        Write-Skip '已存在: PROFILE.md'
    } else {
        Set-Content -LiteralPath $dstProfile -Value $profileContent -Encoding UTF8 -NoNewline
        Write-Ok '安装: PROFILE.md'
    }
}

# MEMORY.example.md → MEMORY.md
$srcMemory = Join-Path $sourceAgentsDir 'MEMORY.example.md'
$dstMemory = Join-Path $configRoot 'agents/MEMORY.md'
if (Test-Path -LiteralPath $srcMemory) {
    $null = Install-File -SourcePath $srcMemory -DestinationPath $dstMemory -Label 'MEMORY.md'
}

# 其余 agents 文件
$agentFiles = @('planner.md', 'annotater.md', 'dev-workflow.md', 'dev-workflow-template.md', 'REVIEW.md')
foreach ($file in $agentFiles) {
    $srcPath = Join-Path $sourceAgentsDir $file
    if (-not (Test-Path -LiteralPath $srcPath)) {
        Write-Warn "源文件缺失: $file"
        continue
    }
    $dstPath = Join-Path $configRoot "agents/$file"
    $null = Install-File -SourcePath $srcPath -DestinationPath $dstPath -Label $file
}

# AGENTS.md → 项目根（动态生成）
$agentsMd = New-AdaptiveAgentsMd -ProjectName $script:projectName -ProjectFlavor $projectFlavor -ConfigDirName $configDirName -SelectedConstraints $selectedConstraints -ExtraConstraintSections $script:extraConstraintSections -WorklogDir $script:worklogDir
$null = Install-GeneratedFile -DestinationPath (Join-Path $targetDir 'AGENTS.md') -Content $agentsMd -Label 'AGENTS.md'

# RTK skill
if ($script:installRtk) {
    $srcRtkDir = Join-Path $sourceSkillsDir 'rtk'
    if (Test-Path -LiteralPath $srcRtkDir) {
        $dstRtkDir = Join-Path $configRoot 'skills/rtk'
        if (-not (Test-Path -LiteralPath $dstRtkDir) -or $Force) {
            if (Test-Path -LiteralPath $dstRtkDir) { Remove-Item -LiteralPath $dstRtkDir -Recurse -Force }
            New-Item -ItemType Directory -Path (Join-Path $configRoot 'skills/rtk') -Force | Out-Null
                            Copy-Item -LiteralPath (Join-Path $srcRtkDir 'SKILL.md') -Destination $dstRtkDir -Recurse -Force
            Get-ChildItem -LiteralPath $dstRtkDir -Recurse -File | ForEach-Object {
                try {
                    $c = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
                    $c = $c -replace '\{\{PROJECT_NAME\}\}', $script:projectName
                    $c = $c -replace 'CommonServerV5', $script:projectName
                    Set-Content -LiteralPath $_.FullName -Value $c -Encoding UTF8 -NoNewline
                } catch {}
            }
            Write-Ok '安装: skills/rtk/'
        } else {
            Write-Skip '已存在: skills/rtk/'
        }
    }
}

# plan / review 模板
if (Test-Path -LiteralPath $sourcePlansTplDir) {
    $planTemplates = Get-ChildItem -LiteralPath $sourcePlansTplDir -File -ErrorAction SilentlyContinue
    foreach ($tpl in $planTemplates) {
        $dstPath = Join-Path $configRoot "plans/template/$($tpl.Name)"
        $null = Install-File -SourcePath $tpl.FullName -DestinationPath $dstPath -Label "plans/template/$($tpl.Name)"
    }
}
if (Test-Path -LiteralPath $sourceReviewsTplDir) {
    $reviewTemplates = Get-ChildItem -LiteralPath $sourceReviewsTplDir -File -ErrorAction SilentlyContinue
    foreach ($tpl in $reviewTemplates) {
        $dstPath = Join-Path $configRoot "reviews/template/$($tpl.Name)"
        $null = Install-File -SourcePath $tpl.FullName -DestinationPath $dstPath -Label "reviews/template/$($tpl.Name)"
    }
}

# ── 6. 安装扩展包 ──────────────────────────────────────
Write-Step '[6/7] 安装扩展包...'

foreach ($addon in $script:selectedAddons) {
    $addonPath = Join-Path $sourceAddonsDir $addon.path
    if (Test-Path -LiteralPath $addonPath) {
        $extraConstraints = Install-Addon -AddonPath $addonPath -ConfigRoot $configRoot -ProjectName $script:projectName -ConfigDirName $configDirName
        if ($extraConstraints) {
            $script:extraConstraintSections += $extraConstraints
        }
    } else {
        Write-Warn "扩展包目录缺失: $($addon.path)"
    }
}

# 如果有扩展包额外约束，需要重新生成 AGENTS.md
if ($script:extraConstraintSections.Count -gt 0) {
    $agentsMd = New-AdaptiveAgentsMd -ProjectName $script:projectName -ProjectFlavor $projectFlavor -ConfigDirName $configDirName -SelectedConstraints $selectedConstraints -ExtraConstraintSections $script:extraConstraintSections -WorklogDir $script:worklogDir
    Set-Content -LiteralPath (Join-Path $targetDir 'AGENTS.md') -Value $agentsMd -Encoding UTF8 -NoNewline
    Write-Ok '更新: AGENTS.md（含扩展约束）'
}

# opencode.json
$srcOcJson = Join-Path $sourceTemplatesDir 'opencode.json'
$dstOcJson = Join-Path $targetDir 'opencode.json'
if (Test-Path -LiteralPath $srcOcJson) {
    if ((Test-Path -LiteralPath $dstOcJson) -and -not $Force) {
        Write-Skip '已存在: opencode.json'
    } else {
        Copy-Item -LiteralPath $srcOcJson -Destination $dstOcJson -Force
        Write-Ok '安装: opencode.json'
    }
}

# plans/README.md
$plansReadme = Join-Path $configRoot 'plans/README.md'
if (-not (Test-Path -LiteralPath $plansReadme) -or $Force) {
    $null = Install-GeneratedFile -DestinationPath $plansReadme -Content @"
# Plans

开发计划目录。每个计划一个 Markdown 文件。

## 命名规范

``````
plan-{功能名}-v{版本号}.md
``````
"@ -Label 'plans/README.md'
}

# ── 清理临时文件 ─────────────────────────────────────
$cleanupDirs = @($tempClone) + @(Join-Path $env:TEMP "$RepoName-$RepoBranch") | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
if ($cleanupDirs) {
    Write-Step '清理临时文件...'
    foreach ($d in $cleanupDirs) { Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue }
    Write-Ok '已清理临时目录'
}

# ── directory-tree.md 扫描更新 ─────────────────────────
$treeDepth = 4
$scanTree = Read-Choice '是否扫描项目目录更新 directory-tree.md?' 'Y' @('Y','N')
if ($scanTree -eq 'Y') {
    Write-Host '  输入目录扫描深度 (1-8，默认 4): ' -NoNewline -ForegroundColor Yellow
    try {
        $depthInput = (Read-Host).Trim()
        if ($depthInput -and $depthInput -match '^\d+$' -and [int]$depthInput -ge 1 -and [int]$depthInput -le 8) {
            $treeDepth = [int]$depthInput
        }
    } catch {}

    Write-Host "  扫描目录: $targetDir (深度 $treeDepth)..." -ForegroundColor DarkGray
    $treeContent = New-DirectoryTree -Dir $targetDir -MaxDepth $treeDepth

    $lineCount = ($treeContent -split "`n").Count
    if ($lineCount -le 2) {
        Write-Warn "扫描结果为空，请检查目标目录: $targetDir"
    }

    $treeMd = @"
# 项目目录树

本文档供 AI 助手阅读。记录 ``$($script:projectName)`` 项目的源码目录结构。

> **维护规则**：每次新增或删除源码文件/目录后，必须同步更新本文档。

---

``````
$treeContent``````
"@
    $treePath = Join-Path $configRoot 'agents/directory-tree.md'
    Set-Content -LiteralPath $treePath -Value $treeMd -Encoding UTF8 -NoNewline
    Write-Ok "已更新: directory-tree.md (深度 $treeDepth, $lineCount 行)"
}

# ── 安装完成 + 交互 ──────────────────────────────────
Write-Step '[7/7] 安装完成!'

Write-Host ''
Write-Host "  项目:      $($script:projectName)" -ForegroundColor White
Write-Host "  技术栈:    $($projectFlavor -join ' + ')" -ForegroundColor White
Write-Host "  配置目录:  $configDirName\" -ForegroundColor White
Write-Host ''
Write-Host '  已安装:' -ForegroundColor Green
Write-Host "    $targetDir\" -ForegroundColor DarkGray
Write-Host "    +-- AGENTS.md" -ForegroundColor DarkGray
if (Test-Path -LiteralPath $dstOcJson) {
    Write-Host "    +-- opencode.json" -ForegroundColor DarkGray
}
Write-Host "    +-- $configDirName\" -ForegroundColor DarkGray
Write-Host "        +-- agents/     AI 配置文件" -ForegroundColor DarkGray
Write-Host "        +-- plans/      开发计划" -ForegroundColor DarkGray
Write-Host "        +-- reviews/    Review 文档" -ForegroundColor DarkGray
if ($script:installRtk) {
    Write-Host "        +-- skills/rtk/ RTK 技能" -ForegroundColor DarkGray
}
foreach ($addon in $script:selectedAddons) {
    Write-Host "        +-- skills/     $($addon.name)" -ForegroundColor DarkGray
}
Write-Host ''

if ($script:adaptProject) {
    Write-Host '  >> 适配安装完成! 模板已适配当前项目。' -ForegroundColor Green
} else {
    Write-Host '  >> 通用模板安装完成! 请手动填写占位符 {{PROJECT_NAME}}。' -ForegroundColor Yellow
}
Write-Host ''

Write-Host '  ─── 接下来可以做什么? ────────────────────────' -ForegroundColor Cyan
Write-Host ''
Write-Host '  1. 编辑 PROFILE.md 填写你的称呼和偏好' -ForegroundColor DarkGray
Write-Host '     (路径: .opencode/agents/PROFILE.md)' -ForegroundColor DarkGray
Write-Host '  2. 补充 tech-stack.md 的测试命令和依赖细节' -ForegroundColor DarkGray
Write-Host '     (路径: .opencode/agents/tech-stack.md)' -ForegroundColor DarkGray
Write-Host '  3. 在 MEMORY.md 记录项目经验和踩坑' -ForegroundColor DarkGray
Write-Host '     (路径: .opencode/agents/MEMORY.md)' -ForegroundColor DarkGray
Write-Host '  4. 用 opencode 打开项目，AI 会自动加载配置' -ForegroundColor DarkGray
Write-Host ''

try {
    $userChoice = Read-Host '  输入编号继续 (1-4)，或直接回车跳过'
    switch ($userChoice) {
        '1' { Write-Host "  >> 请编辑: $configRoot\agents\PROFILE.md" -ForegroundColor Yellow }
        '2' { Write-Host "  >> 请编辑: $configRoot\agents\tech-stack.md" -ForegroundColor Yellow }
        '3' { Write-Host "  >> 请编辑: $configRoot\agents\MEMORY.md" -ForegroundColor Yellow }
        '4' { Write-Host '  >> 在项目目录运行: opencode .' -ForegroundColor Yellow }
        default { Write-Host '  随时可以重新运行 init.ps1 -Force 覆盖配置' -ForegroundColor DarkGray }
    }
} catch {
    Write-Host '  随时可以重新运行 init.ps1 -Force 覆盖配置' -ForegroundColor DarkGray
}

Write-Host ''
Write-Host '  使用 opencode 打开项目即可自动加载配置。' -ForegroundColor DarkGray
Write-Host ''
