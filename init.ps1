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
        [string[]]$ExtraConstraintSections
    )

    $stackLine = $ProjectFlavor -join ' + '

    $baseConstraints = @'
## A. 代码规范

| # | 约束 | 违反后果 |
|---|------|---------|
| A1 | 遵循项目现有代码风格和命名约定 | 不一致 → 代码可维护性差 |
| A2 | 不引入项目未使用的新框架或库 | 引入 → 与项目定位冲突 |
| A3 | 修改前先理解上下文，不盲目重构 | 盲目重构 → 引入 bug |

## B. 交互与输出

| # | 约束 | 违反后果 |
|---|------|---------|
| B1 | 中文交流，简洁直接 | 英文或冗长 → 被判定为错误 |
| B2 | 给方案说利弊，由用户定决策 | 不确认 → 做错方向 |
| B3 | 默认只输出结果，不解释 | 冗长解释 → 被判定为错误 |
| B4 | 有不确定时先确认，不全盘执行 | 不确认 → 做错方向 |

## C. 工作流程

| # | 约束 | 违反后果 |
|---|------|---------|
| C1 | 默认最小正确改动，不主动重构大架构 | 过度重构 → 意外破坏 |
| C2 | 有价值信息先记录再回答 | 不记录 → 下次会话重复踩坑 |
| C3 | 构建验证 → 测试验证 → 文档同步 | 不验证 → 引入构建失败 |

## D. 文件写入

| # | 约束 | 违反后果 |
|---|------|---------|
| D1 | 写入文件用 MCP 工具直接读写文本方式 | 绕过 MCP → 内容丢失或不可控 |
| D2 | 超大文件分段追加，每次 <200 行 | 一次性写入 → 内存溢出或失败 |

## E. 文档同步

| # | 约束 | 违反后果 |
|---|------|---------|
| E1 | 新增/删除源码文件后更新 directory-tree.md | 目录树过期 → AI 放错文件位置 |
| E2 | 修改技术栈/依赖后更新 tech-stack.md | 技术栈文档过期 → AI 引入错误依赖 |
| E3 | 有踩坑经验更新到 MEMORY.md | 记忆文档过时 → AI 反复踩坑 |

## F. Plan 批注审查

| # | 约束 | 违反后果 |
|---|------|---------|
| F1 | 涉及3+文件或新架构的改动，Plan 写完后必须经过批注循环（1-6 轮） | 计划有隐患未暴露 → 实施中途返工 |
| F2 | 批注必须按 annotater.md 定义的类型标记 | 批注格式混乱 → 决策无法追踪 |
| F3 | 每条批注必须有对应决策才能推进，决策后立即原地清理 | 未决策批注堆积 → plan 状态不明 |
| F4 | 仅当所有批注已解决且无新问题时，Plan 状态才可从「规划中」改为「实施中」 | 未完成审批就执行 → 方向错误 |

## G. 工具使用

| # | 约束 | 违反后果 |
|---|------|---------|
| G1 | 对项目的所有操作必须通过 MCP 工具执行 | 绕过 MCP → 操作不可追踪、不可审计 |
'@

    $allConstraintSections = $baseConstraints
    if ($ExtraConstraintSections) {
        $allConstraintSections += "`n`n" + ($ExtraConstraintSections -join "`n`n")
    }

    $constraintLetters = [regex]::Matches($allConstraintSections, '## ([A-Z])\.') |
        ForEach-Object { $_.Groups[1].Value }

    $constraintConfirmLines = foreach ($letter in $constraintLetters) {
        $idx = [array]::IndexOf($constraintLetters, $letter) + 1
        switch ($letter) {
            'A' { "$idx. [A类] 代码规范约束关键词" }
            'B' { "$idx. [B类] 交互输出约束关键词" }
            'C' { "$idx. [C类] 工作流程约束关键词" }
            'D' { "$idx. [D类] 文件写入约束关键词" }
            'E' { "$idx. [E类] 文档同步约束关键词" }
            'F' { "$idx. [F类] Plan批注审查约束关键词" }
            'G' { "$idx. [G类] 工具使用约束关键词" }
            'H' { "$idx. [H类] 目录归属约束关键词" }
            'I' { "$idx. [I类] UI/主题约束关键词" }
            'J' { "$idx. [J类] 代码规范扩展约束关键词" }
            'K' { "$idx. [K类] 测试规范约束关键词" }
            'L' { "$idx. [L类] AI执行流程约束关键词" }
            'M' { "$idx. [M类] 记忆记录约束关键词" }
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
| 1 | [PROFILE.md]($ConfigDirName/agents/PROFILE.md) | 用户称呼、交流语言、决策风格 |
| 2 | [directory-tree.md]($ConfigDirName/agents/directory-tree.md) | 文件放置规则、目录结构 |
| 3 | [tech-stack.md]($ConfigDirName/agents/tech-stack.md) | 技术栈、依赖、测试命令 |
| 4 | [MEMORY.md]($ConfigDirName/agents/MEMORY.md) | 开发注意事项、技术决策、项目经验 |

## 按需（任务触发时读取）

| # | 文件 | 触发条件 | 关键信息 |
|---|------|---------|---------|
| 5 | [planner.md]($ConfigDirName/agents/planner.md) | Plan 制定任务 | 计划制定流程、自检清单 |
| 6 | [annotater.md]($ConfigDirName/agents/annotater.md) | Plan/批注任务 | 批注审查流程 |

---

# 强制记忆清单（红线 — 违反即错误）

以下是从 MEMORY.md 和项目经验中提炼的**绝对禁止项**。AI 必须逐条理解并遵守，不得以"忘记"、"上下文太长"为由绕过。

$allConstraintSections

---

# 步骤2：约束确认输出（强制）

读完上下文文件后，首次回复必须输出以下确认标记。**禁止用占位符**，必须写出每条约束的具体内容关键词：

``````
上下文已加载: PROFILE ✓ 目录树 ✓ 技术栈 ✓ 记忆 ✓ 约束 ✓
我已经确认了用户对我的约束：
$confirmBlock
``````

**每类至少写出总结具体内容**，证明你不是在走过场。

---

# 任务执行前自检

| # | 自检项 | 通过条件 |
|---|--------|---------|
| 1 | 代码风格 | 与项目现有风格一致 |
| 2 | 最小改动 | 只改必要的，不重构不相关部分 |
| 3 | 依赖安全 | 不引入新框架/库（除非用户要求） |
| 4 | 构建验证 | 改动后构建通过 |

自检不通过的项目，必须先修正再继续执行，不得跳过。

---

# 执行方式

| 方式 | 适用场景 | 机制 | 优势 |
|------|---------|------|------|
| **Subagent 驱动（推荐）** | 多个独立子任务 | 每个 Task 派一个新 subagent | 隔离上下文、并行加速 |
| **内联执行** | 有顺序依赖 | 在当前会话中逐步执行 | 上下文连续、调试方便 |
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
Write-Host "  技术栈:     $($projectFlavor -join ' + ')" -ForegroundColor White
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
    $null = Install-File -SourcePath $srcProfile -DestinationPath $dstProfile -Label 'PROFILE.md'
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
$agentsMd = New-AdaptiveAgentsMd -ProjectName $script:projectName -ProjectFlavor $projectFlavor -ConfigDirName $configDirName -SelectedConstraints $selectedConstraints -ExtraConstraintSections $script:extraConstraintSections
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
    $agentsMd = New-AdaptiveAgentsMd -ProjectName $script:projectName -ProjectFlavor $projectFlavor -ConfigDirName $configDirName -SelectedConstraints $selectedConstraints -ExtraConstraintSections $script:extraConstraintSections
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
