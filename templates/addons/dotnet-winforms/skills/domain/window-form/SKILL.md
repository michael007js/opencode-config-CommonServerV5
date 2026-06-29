---
name: "window-form"
description: "三段式/两段式/四段式窗口创建技能。根容器为 TableLayoutPanel（3-4行：AppTitleBar+菜单栏+内容区+AppBottomStatusBar）。创建新窗体时触发。"
version: "4.0.0"
updatedAt: "2026-06-22"
tags: [窗体, 窗口, 三段式, 两段式, 四段式, AppForm, AppTitleBar, AppMenuStrip, AppBottomStatusBar, TableLayoutPanel]
---

# 窗口创建 Skill

本 Skill 用于按统一模式快速产出新窗体（AppForm 子类），根容器为 TableLayoutPanel 三行布局。

---

## §1 概述与触发条件

### 触发条件

- 用户要求"新建窗体""新增窗口""创建一个 xxx 窗体/窗口/界面"
- 需要创建新的继承 `AppForm` 的窗体类

### 布局架构

**所有 AppForm 子类的根容器统一为 `rootTableLayoutPanel`**，3~4 行 1 列：

| 行 | 内容 | RowStyle | Dock | 说明 |
|----|------|----------|------|------|
| Row 0 | AppTitleBar | AutoSize | Fill | 自绘标题栏，高度由 MinimumSize 决定 |
| Row 1 | AppMenuStrip（可选） | AutoSize | Fill | 自绘菜单栏，不需要菜单的窗体不添加此行 |
| Row 1/2 | 客户区 | Percent 100% | Fill | 中间内容区，填满剩余空间 |
| Row 2/3 | AppBottomStatusBar | AutoSize | Fill | 底部状态栏，通过 `SetupRootLayout()` 添加 |

> 无菜单栏时为 3 行（Row 0=标题栏, Row 1=客户区, Row 2=状态栏），有菜单栏时为 4 行（Row 0=标题栏, Row 1=菜单栏, Row 2=客户区, Row 3=状态栏）。

### 三种模式

| 模式 | 布局结构 | 适用场景 |
|------|---------|---------|
| **三段式** | AppTitleBar（row 0）+ 内容区（row 1）+ AppBottomStatusBar（row 2） | 无菜单的简单窗口 |
| **四段式** | AppTitleBar（row 0）+ AppMenuStrip（row 1）+ 内容区（row 2）+ AppBottomStatusBar（row 3） | 有菜单的完整窗口 |
| **两段式** | AppTitleBar（row 0）+ 内容区（row 1）+ AppBottomStatusBar（row 2, Visible=false） | 对话框、无底部状态 |

### 双击/拖动机制

- **双击标题栏** → 最大化/还原切换：AppTitleBar 内部 `OnMouseDoubleClick` → `TryToggleWindowStateFromTitleBar` 处理，无需窗体参与
- **拖动标题栏** → 窗体移动：AppTitleBar 内部 `StartDrag()` 通过 `ReleaseCapture + SendMessage(WM_NCLBUTTONDOWN, HTCAPTION)` 直接操作 Form 句柄，与控件层级无关
- **右键标题栏** → 系统菜单：AppTitleBar 触发 `ShowSystemMenuRequested` 事件，AppForm 接收并显示系统菜单

---

## §2 占位符字典

| 占位符 | 含义 | 示例 |
|--------|------|------|
| `{{窗体名}}` | 窗体类名（PascalCase） | MainForm / SettingsDialog / DashboardForm |
| `{{窗体标题}}` | 标题栏显示文本 | Common Server / 设置 / 仪表盘 |
| `{{窗体宽}}` | 初始 ClientSize 宽度 | 800 |
| `{{窗体高}}` | 初始 ClientSize 高度 | 450 |
| `{{内容区控件}}` | 内容区子控件声明和初始化 | 具体控件代码 |

---

## §3 三段式窗口创建步骤

三段式布局 = rootTableLayoutPanel（Row 0: AppTitleBar + Row 1: 内容区 + Row 2: AppBottomStatusBar）。

### 3.1 窗体逻辑文件（*.cs）

```csharp
using {{PROJECT_NAME}}.Components.Atomic.Theming;
using {{PROJECT_NAME}}.Components.Composite;

namespace {{PROJECT_NAME}};

public partial class {{窗体名}} : AppForm
{
    public {{窗体名}}()
    {
        InitializeComponent();
        SetupRootLayout(rootTableLayoutPanel);
        StartPosition = FormStartPosition.CenterScreen;
        AppThemeManager.ThemeChanged += OnThemeChanged;
        Disposed += OnDisposed;
    }

    private void OnThemeChanged(object? sender, AppThemeChangedEventArgs e)
    {
        // 主题切换时更新内容区颜色/文本等
    }

    private void OnDisposed(object? sender, EventArgs e)
    {
        AppThemeManager.ThemeChanged -= OnThemeChanged;
        Disposed -= OnDisposed;
    }
}
```

**要点：**
- 继承 `AppForm`，不直接继承 `Form`（B3 约束）
- `InitializeComponent()` 之后必须调用 `SetupRootLayout(rootTableLayoutPanel)` 将 AppBottomStatusBar 添加到 row 2
- 手写逻辑放在非 Designer partial 类（C1 约束）
- 主题订阅/注销成对出现：`Disposed` 事件中注销。`Dispose(bool)` 由 Designer.cs 管理（`components.Dispose()`），不能在 *.cs 中重复定义
- AppForm 已在自身 `Dispose(bool)` 中注销 `AppThemeManager.ThemeChanged -= OnAppFormThemeChanged`，子类注销的是子类自己的 handler

### 3.2 窗体设计器文件（*.Designer.cs）

三段式 Designer.cs 骨架：

```csharp
namespace {{PROJECT_NAME}};

partial class {{窗体名}}
{
    /// <summary>
    ///  Required designer variable.
    /// </summary>
    private System.ComponentModel.IContainer components = null;

    /// <summary>
    ///  Clean up any resources being used.
    /// </summary>
    /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
        {
            components.Dispose();
        }
        base.Dispose(disposing);
    }

    #region Windows Form Designer generated code

    /// <summary>
    ///  Required method for Designer support - do not modify
    ///  the contents of this method with the code editor.
    /// </summary>
    private void InitializeComponent()
    {
        rootTableLayoutPanel = new System.Windows.Forms.TableLayoutPanel();
        appTitleBar1 = new {{PROJECT_NAME}}.Components.Composite.AppTitleBar();
        {{内容区控件 new 声明（全限定名）}}
        rootTableLayoutPanel.SuspendLayout();
        SuspendLayout();
        //
        // rootTableLayoutPanel
        //
        rootTableLayoutPanel.ColumnCount = 1;
        rootTableLayoutPanel.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
        rootTableLayoutPanel.Controls.Add(appTitleBar1, 0, 0);
        rootTableLayoutPanel.Controls.Add({{内容区控件}}, 0, 1);
        rootTableLayoutPanel.Dock = System.Windows.Forms.DockStyle.Fill;
        rootTableLayoutPanel.Location = new System.Drawing.Point(0, 0);
        rootTableLayoutPanel.Name = "rootTableLayoutPanel";
        rootTableLayoutPanel.RowCount = 3;
        rootTableLayoutPanel.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.AutoSize));
        rootTableLayoutPanel.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 100F));
        rootTableLayoutPanel.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.AutoSize));
        rootTableLayoutPanel.Size = new System.Drawing.Size({{窗体宽}}, {{窗体高}});
        rootTableLayoutPanel.TabIndex = 3;
        //
        // appTitleBar1
        //
        appTitleBar1.BackColor = System.Drawing.Color.Transparent;
        appTitleBar1.Dock = System.Windows.Forms.DockStyle.Fill;
        appTitleBar1.Font = new System.Drawing.Font("Microsoft YaHei UI", 11.2F);
        appTitleBar1.Location = new System.Drawing.Point(3, 3);
        appTitleBar1.MinimumSize = new System.Drawing.Size(0, 32);
        appTitleBar1.Name = "appTitleBar1";
        appTitleBar1.Size = new System.Drawing.Size({{窗体宽_minus_padding}}, 32);
        appTitleBar1.TabIndex = 3;
        appTitleBar1.TabStop = false;
        appTitleBar1.TitleText = "{{窗体标题}}";
        //
        // {{内容区控件属性赋值（全限定名）}}
        //  注意：内容区控件 Dock 必须为 Fill
        //
        //
        // {{窗体名}}
        //
        AutoScaleDimensions = new System.Drawing.SizeF(7F, 17F);
        AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
        ClientSize = new System.Drawing.Size({{窗体宽}}, {{窗体高}});
        Controls.Add(rootTableLayoutPanel);
        // FormBorderStyle 不在此处设置 — AppForm 的 new setter 强制 None，且标 [Browsable(false)] 设计器不序列化
        Text = "{{窗体名}}";
        Controls.SetChildIndex(rootTableLayoutPanel, 0);
        rootTableLayoutPanel.ResumeLayout(false);
        ResumeLayout(false);
    }

    private System.Windows.Forms.TableLayoutPanel rootTableLayoutPanel;
    private {{PROJECT_NAME}}.Components.Composite.AppTitleBar appTitleBar1;
    {{内容区控件字段声明（全限定名）}}

    #endregion
}
```

**设计器兼容性规则（必须遵守）：**

| 规则 | 说明 | 违反后果 |
|------|------|---------|
| #region 成对 | `#region Windows Form Designer generated code` / `#endregion` 必须包裹字段声明 + InitializeComponent | 缺少 #region → 设计器无法识别生成区域 |
| 字段全限定名 | `private {{PROJECT_NAME}}.Components.Composite.AppTitleBar appTitleBar1;` | 短名 → 设计器重序列化用全限定名，产生 diff 冲突 |
| 属性全限定名 | `System.Windows.Forms.DockStyle.Fill` / `System.Drawing.Size` / `System.Drawing.SizeF` | 短名 → 设计器重序列化会改写，产生不必要 diff |
| BackColor=Transparent | AppTitleBar 必须设 `BackColor = System.Drawing.Color.Transparent` | 缺少 → 设计器中标题栏显示不透明默认色 |
| AppTitleBar Dock=Fill | 在 TableLayoutPanel cell 中必须 Dock=Fill，不是 Dock=Top | Dock=Top → cell 内高度不匹配，鼠标事件区域错误 |
| MinimumSize | `appTitleBar1.MinimumSize = new System.Drawing.Size(0, 32)` — AutoSize 行高由此决定 | 缺少 → 标题栏行高不确定 |
| RowStyle 顺序 | Row 0 AutoSize / Row 1 Percent 100% / Row 2 AutoSize | 错误顺序 → 布局异常 |
| ColumnStyle | `SizeType.Percent, 100F`，单列 | 错误 → 列宽不填满 |
| SetChildIndex 连续 0 | `Controls.SetChildIndex(rootTableLayoutPanel, 0)` | 99 → 设计器改写产生 diff |
| TabIndex 与真实一致 | AppTitleBar `TabIndex = 2`（TabStop=false 时无功能意义，但设计器重序列化会改写） | 99 → 设计器改写产生 diff |
| XML 注释 | `components` 字段和 `InitializeComponent` 方法必须有标准 `///` 注释 | 缺少 → 设计器可能警告 |
| Location + Font | 即使 Dock=Fill 时 Location 无意义，设计器序列化仍会生成 | 不写 → 设计器自动补回 |

**关键布局规则：**
- **AppBottomStatusBar 不在 Designer.cs 中声明** — 由 `AppForm.SetupRootLayout(rootTableLayoutPanel)` 在 *.cs 构造函数中添加到 row 2
- rootTableLayoutPanel 是 Form.Controls 的**唯一直接子控件**
- AppTitleBar 和内容区控件是 rootTableLayoutPanel 的子控件
- `FormBorderStyle = None` 由 AppForm new setter 强制，**不要在 Designer.cs 中显式写**
- `StartPosition` 推荐在 *.cs 构造函数中设置

### 3.3 AppBottomStatusBar 配置

AppForm 的 `AppBottomStatusBar` 属性提供以下常用配置：

```csharp
// 在窗体构造函数中（InitializeComponent + SetupRootLayout 之后）
AppBottomStatusBar.SplitterRatio = 0.33;           // 分隔条位置比例
AppBottomStatusBar.TopLeftRadius = 8;               // 左上圆角
AppBottomStatusBar.TopRightRadius = 8;              // 右上圆角
AppBottomStatusBar.BottomLeftRadius = 8;             // 左下圆角（与窗体圆角同步）
AppBottomStatusBar.BottomRightRadius = 8;            // 右下圆角（与窗体圆角同步）
AppBottomStatusBar.LeftContent = statusLeftPanel;    // 左区域内容
AppBottomStatusBar.RightContent = statusRightPanel;  // 右区域内容
```

**圆角同步：** AppForm 自动通过 `SyncStatusBarCornerRadius()` 将窗体底部圆角同步到 AppBottomStatusBar，最大化时自动变为直角。通常不需要手动设置 BottomLeftRadius/BottomRightRadius。

### 3.4 完整示例（Form1 三段式）

参考现有 `Form1.cs` + `Form1.Designer.cs`：
- rootTableLayoutPanel 3 行（AutoSize / Percent 100% / AutoSize）
- AppTitleBar 在 row 0，Dock=Fill
- appTabPane1 在 row 1，Dock=Fill
- AppBottomStatusBar 由 `SetupRootLayout(rootTableLayoutPanel)` 添加到 row 2
- Form1.cs 中订阅 ThemeChanged 和 Disposed

---

## §4 两段式窗口创建步骤

两段式布局 = rootTableLayoutPanel（Row 0: AppTitleBar + Row 1: 内容区 + Row 2: AppBottomStatusBar Visible=false）。

### 4.1 隐藏 AppBottomStatusBar

AppForm 构造函数创建 AppBottomStatusBar，`SetupRootLayout` 将其添加到 row 2。两段式窗口通过设置 `Visible = false` 隐藏它：

```csharp
public {{窗体名}}()
{
    InitializeComponent();
    SetupRootLayout(rootTableLayoutPanel);
    // AppForm 构造函数先执行 → AppBottomStatusBar 已在 rootTableLayoutPanel row 2 中
    // 用 Visible=false 隐藏（不用 Controls.Remove）：
    //   1. 控件仍在 Controls 中，Form 自动 Dispose → 无泄漏
    //   2. AppForm.SyncStatusBarCornerRadius() 在 Resize 时仍被调用 → 设属性安全
    //   3. 若用 Controls.Remove + Dispose，_appBottomStatusBar 字段非 null 但 IsDisposed=true，
    //      SyncStatusBarCornerRadius 访问已 Dispose 控件属性 → ObjectDisposedException
    AppBottomStatusBar.Visible = false;
    AppThemeManager.ThemeChanged += OnThemeChanged;
    Disposed += OnDisposed;
}
```

**为什么不能用 Controls.Remove + Dispose：**

AppForm 的 `SyncStatusBarCornerRadius()` 在每次 OnResize → UpdateRegion 时被调用：
```csharp
private void SyncStatusBarCornerRadius()
{
    if (_appBottomStatusBar == null) return;  // ≠ IsDisposed 检查！
    _appBottomStatusBar.BottomLeftRadius = ...;  // 已 Dispose → ObjectDisposedException
}
```
`_appBottomStatusBar` 是 AppForm 的 private 字段，Dispose 后不是 null，只是 `IsDisposed=true`。两段式窗口 Resize 时必崩。

**Visible=false 方案优势：**
- 零侵入，不需要改 AppForm
- 控件留在 Controls 中，Form 自动 Dispose，无泄漏
- SyncStatusBarCornerRadius 设属性安全（控件未 Dispose）
- row 2 AutoSize 行在 AppBottomStatusBar 隐藏后自动收缩为 0 高度
- 内容区（row 1 Percent 100%）自动扩展占满

### 4.2 窗体设计器文件

两段式 Designer.cs 与三段式完全相同（rootTableLayoutPanel 仍然是 3 行），区别仅在于：
- *.cs 构造函数中 `AppBottomStatusBar.Visible = false`
- 内容区占满除标题栏外的全部空间（row 2 AutoSize 收缩为 0）

```csharp
namespace {{PROJECT_NAME}};

partial class {{窗体名}}
{
    /// <summary>
    ///  Required designer variable.
    /// </summary>
    private System.ComponentModel.IContainer components = null;

    /// <summary>
    ///  Clean up any resources being used.
    /// </summary>
    /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
        {
            components.Dispose();
        }
        base.Dispose(disposing);
    }

    #region Windows Form Designer generated code

    /// <summary>
    ///  Required method for Designer support - do not modify
    ///  the contents of this method with the code editor.
    /// </summary>
    private void InitializeComponent()
    {
        rootTableLayoutPanel = new System.Windows.Forms.TableLayoutPanel();
        appTitleBar1 = new {{PROJECT_NAME}}.Components.Composite.AppTitleBar();
        {{内容区控件 new 声明（全限定名）}}
        rootTableLayoutPanel.SuspendLayout();
        SuspendLayout();
        //
        // rootTableLayoutPanel
        //
        rootTableLayoutPanel.ColumnCount = 1;
        rootTableLayoutPanel.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
        rootTableLayoutPanel.Controls.Add(appTitleBar1, 0, 0);
        rootTableLayoutPanel.Controls.Add({{内容区控件}}, 0, 1);
        rootTableLayoutPanel.Dock = System.Windows.Forms.DockStyle.Fill;
        rootTableLayoutPanel.Location = new System.Drawing.Point(0, 0);
        rootTableLayoutPanel.Name = "rootTableLayoutPanel";
        rootTableLayoutPanel.RowCount = 3;
        rootTableLayoutPanel.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.AutoSize));
        rootTableLayoutPanel.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 100F));
        rootTableLayoutPanel.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.AutoSize));
        rootTableLayoutPanel.Size = new System.Drawing.Size({{窗体宽}}, {{窗体高}});
        rootTableLayoutPanel.TabIndex = 3;
        //
        // appTitleBar1
        //
        appTitleBar1.BackColor = System.Drawing.Color.Transparent;
        appTitleBar1.Dock = System.Windows.Forms.DockStyle.Fill;
        appTitleBar1.Font = new System.Drawing.Font("Microsoft YaHei UI", 11.2F);
        appTitleBar1.Location = new System.Drawing.Point(3, 3);
        appTitleBar1.MinimumSize = new System.Drawing.Size(0, 32);
        appTitleBar1.Name = "appTitleBar1";
        appTitleBar1.Size = new System.Drawing.Size({{窗体宽_minus_padding}}, 32);
        appTitleBar1.TabIndex = 3;
        appTitleBar1.TabStop = false;
        appTitleBar1.TitleText = "{{窗体标题}}";
        //
        // {{内容区控件属性赋值（全限定名）}}
        //  注意：内容区控件 Dock 必须为 Fill
        //
        //
        // {{窗体名}}
        //
        AutoScaleDimensions = new System.Drawing.SizeF(7F, 17F);
        AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
        ClientSize = new System.Drawing.Size({{窗体宽}}, {{窗体高}});
        Controls.Add(rootTableLayoutPanel);
        Text = "{{窗体名}}";
        Controls.SetChildIndex(rootTableLayoutPanel, 0);
        rootTableLayoutPanel.ResumeLayout(false);
        ResumeLayout(false);
    }

    private System.Windows.Forms.TableLayoutPanel rootTableLayoutPanel;
    private {{PROJECT_NAME}}.Components.Composite.AppTitleBar appTitleBar1;
    {{内容区控件字段声明（全限定名）}}

    #endregion
}
```

---

## §5 四段式窗口创建步骤

四段式布局 = rootTableLayoutPanel（Row 0: AppTitleBar + Row 1: AppMenuStrip + Row 2: 内容区 + Row 3: AppBottomStatusBar）。

### 5.1 窗体逻辑文件（*.cs）

```csharp
using {{PROJECT_NAME}}.Components.Atomic.Theming;
using {{PROJECT_NAME}}.Components.Composite;

namespace {{PROJECT_NAME}};

public partial class {{窗体名}} : AppForm
{
    public {{窗体名}}()
    {
        InitializeComponent();
        SetupRootLayout(rootTableLayoutPanel, 3);
        StartPosition = FormStartPosition.CenterScreen;
        AppThemeManager.ThemeChanged += OnThemeChanged;
        Disposed += OnDisposed;
    }

    private void OnThemeChanged(object? sender, AppThemeChangedEventArgs e)
    {
    }

    private void OnDisposed(object? sender, EventArgs e)
    {
        AppThemeManager.ThemeChanged -= OnThemeChanged;
        Disposed -= OnDisposed;
    }
}
```

**与三段式的关键差异：**
- `SetupRootLayout(rootTableLayoutPanel, 3)` — 第二个参数 **必须传 3**，表示 AppBottomStatusBar 在 row 3
- rootTableLayoutPanel 为 **4 行**（RowCount=4）

### 5.2 窗体设计器文件（*.Designer.cs）

四段式 Designer.cs 骨架：

```csharp
namespace {{PROJECT_NAME}};

partial class {{窗体名}}
{
    /// <summary>
    ///  Required designer variable.
    /// </summary>
    private System.ComponentModel.IContainer components = null;

    /// <summary>
    ///  Clean up any resources being used.
    /// </summary>
    /// <param name="disposing">true if managed resources should be disposed; otherwise, false.</param>
    protected override void Dispose(bool disposing)
    {
        if (disposing && (components != null))
        {
            components.Dispose();
        }
        base.Dispose(disposing);
    }

    #region Windows Form Designer generated code

    /// <summary>
    ///  Required method for Designer support - do not modify
    ///  the contents of this method with the code editor.
    /// </summary>
    private void InitializeComponent()
    {
        rootTableLayoutPanel = new System.Windows.Forms.TableLayoutPanel();
        appTitleBar1 = new {{PROJECT_NAME}}.Components.Composite.AppTitleBar();
        appMenuStrip1 = new {{PROJECT_NAME}}.Components.Composite.AppMenuStrip();
        {{内容区控件 new 声明（全限定名）}}
        rootTableLayoutPanel.SuspendLayout();
        SuspendLayout();
        //
        // rootTableLayoutPanel
        //
        rootTableLayoutPanel.ColumnCount = 1;
        rootTableLayoutPanel.ColumnStyles.Add(new System.Windows.Forms.ColumnStyle(System.Windows.Forms.SizeType.Percent, 100F));
        rootTableLayoutPanel.Controls.Add(appTitleBar1, 0, 0);
        rootTableLayoutPanel.Controls.Add(appMenuStrip1, 0, 1);
        rootTableLayoutPanel.Controls.Add({{内容区控件}}, 0, 2);
        rootTableLayoutPanel.Dock = System.Windows.Forms.DockStyle.Fill;
        rootTableLayoutPanel.Location = new System.Drawing.Point(0, 0);
        rootTableLayoutPanel.Name = "rootTableLayoutPanel";
        rootTableLayoutPanel.RowCount = 4;
        rootTableLayoutPanel.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.AutoSize));
        rootTableLayoutPanel.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.AutoSize));
        rootTableLayoutPanel.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.Percent, 100F));
        rootTableLayoutPanel.RowStyles.Add(new System.Windows.Forms.RowStyle(System.Windows.Forms.SizeType.AutoSize));
        rootTableLayoutPanel.Size = new System.Drawing.Size({{窗体宽}}, {{窗体高}});
        rootTableLayoutPanel.TabIndex = 3;
        //
        // appTitleBar1
        //
        appTitleBar1.BackColor = System.Drawing.Color.Transparent;
        appTitleBar1.Dock = System.Windows.Forms.DockStyle.Fill;
        appTitleBar1.Font = new System.Drawing.Font("Microsoft YaHei UI", 11.2F);
        appTitleBar1.Location = new System.Drawing.Point(3, 3);
        appTitleBar1.MinimumSize = new System.Drawing.Size(0, 32);
        appTitleBar1.Name = "appTitleBar1";
        appTitleBar1.Size = new System.Drawing.Size({{窗体宽_minus_padding}}, 32);
        appTitleBar1.TabIndex = 3;
        appTitleBar1.TabStop = false;
        appTitleBar1.TitleText = "{{窗体标题}}";
        //
        // appMenuStrip1
        //
        appMenuStrip1.Dock = System.Windows.Forms.DockStyle.Fill;
        appMenuStrip1.Font = new System.Drawing.Font("Microsoft YaHei UI", 9F);
        appMenuStrip1.Location = new System.Drawing.Point(0, 35);
        appMenuStrip1.Name = "appMenuStrip1";
        appMenuStrip1.Size = new System.Drawing.Size({{窗体宽}}, 24);
        appMenuStrip1.TabIndex = 4;
        //
        // {{内容区控件属性赋值（全限定名）}}
        //  注意：内容区控件 Dock 必须为 Fill
        //
        //
        // {{窗体名}}
        //
        AutoScaleDimensions = new System.Drawing.SizeF(7F, 17F);
        AutoScaleMode = System.Windows.Forms.AutoScaleMode.Font;
        ClientSize = new System.Drawing.Size({{窗体宽}}, {{窗体高}});
        Controls.Add(rootTableLayoutPanel);
        Text = "{{窗体名}}";
        Controls.SetChildIndex(rootTableLayoutPanel, 0);
        rootTableLayoutPanel.ResumeLayout(false);
        ResumeLayout(false);
    }

    private System.Windows.Forms.TableLayoutPanel rootTableLayoutPanel;
    private {{PROJECT_NAME}}.Components.Composite.AppTitleBar appTitleBar1;
    private {{PROJECT_NAME}}.Components.Composite.AppMenuStrip appMenuStrip1;
    {{内容区控件字段声明（全限定名）}}

    #endregion
}
```

**四段式与三段式的 Designer.cs 差异清单：**

| # | 差异项 | 三段式 | 四段式 |
|---|--------|--------|--------|
| 1 | RowCount | 3 | **4** |
| 2 | RowStyles | AutoSize / Percent 100% / AutoSize | AutoSize / **AutoSize** / Percent 100% / AutoSize |
| 3 | Controls.Add | appTitleBar1→row0, 内容区→row1 | appTitleBar1→row0, **appMenuStrip1→row1**, 内容区→**row2** |
| 4 | 字段声明 | 无 appMenuStrip1 | **有 appMenuStrip1** |
| 5 | SetupRootLayout | `SetupRootLayout(rootTableLayoutPanel)` | **`SetupRootLayout(rootTableLayoutPanel, 3)`** |

---

## §6 约束自检清单

创建窗体时必须逐项确认：

| # | 自检项 | ✅ 通过条件 | 常见违反 |
|---|--------|------------|---------|
| 1 | 继承关系 | 继承 `AppForm`，不直接继承 `Form` | 直接继承 Form → 主题失效 |
| 2 | 命名空间 | `namespace {{PROJECT_NAME}};`（窗体放项目根目录） | 命名空间不匹配 → 构建失败 |
| 3 | 主题集成 | 订阅 `ThemeChanged` + `Disposed` 中注销 | 不订阅或只订阅不注销 → 生命周期泄漏 |
| 4 | SetupRootLayout | `InitializeComponent()` 后调用 `SetupRootLayout(rootTableLayoutPanel)`，四段式传 `row: 3` | 未调用或行号错 → AppBottomStatusBar 错位 |
| 5 | rootTableLayoutPanel 行数 | 三段式/两段式=3行（AutoSize/Percent/AutoSize），四段式=4行（AutoSize/AutoSize/Percent/AutoSize） | 行数或 RowStyle 错误 → 布局异常 |
| 6 | AppTitleBar Dock=Fill | 在 TableLayoutPanel cell 中 Dock=Fill（不是 Dock=Top） | Dock=Top → cell 高度不匹配，鼠标事件区域错误 |
| 7 | Designer 安全 | 手写逻辑不在 `*.Designer.cs` 中 | 写入 Designer.cs → 设计器重生成丢失 |
| 8 | 设计器全限定名 | 字段声明和属性赋值全部使用全限定名 | 短名 → 设计器重序列化 diff 冲突 |
| 9 | #region 成对 | `#region Windows Form Designer generated code` / `#endregion` | 缺少 → 设计器无法识别 |
| 10 | AppTitleBar 完整属性 | BackColor=Transparent + MinimumSize + Location + Font + Dock=Fill | 缺少 → 设计器补回或视觉破损 |
| 11 | SetChildIndex 模式 | `Controls.SetChildIndex(rootTableLayoutPanel, 0)` | 99 → 设计器改写产生 diff |
| 12 | 颜色合规 | 所有颜色用 `AppThemePalette` 语义色，禁止 `Color.FromArgb()` 硬编码 | 硬编码颜色 → 主题切换破损 |
| 13 | 两段式泄漏 | `AppBottomStatusBar.Visible = false`（不 Remove 不 Dispose） | Controls.Remove+Dispose → Resize 时 ObjectDisposedException |
| 14 | 底部状态栏 | 三段式保留、两段式 `AppBottomStatusBar.Visible = false` | 不隐藏 → 底部空白条 |
| 15 | 双击/拖动 | AppTitleBar 在 row 0 Dock=Fill + MinimumSize ≥ 32 | Dock=Top 或 MinimumSize 缺失 → 标题栏交互失效 |

---

## §6 三种模式对比速查

| 项 | 三段式 | 四段式 | 两段式 |
|----|--------|--------|--------|
| 继承 | `AppForm` | `AppForm` | `AppForm` |
| 根容器 | rootTableLayoutPanel（3行） | rootTableLayoutPanel（4行） | rootTableLayoutPanel（3行） |
| Row 0 | AppTitleBar（Dock=Fill, AutoSize） | AppTitleBar（Dock=Fill, AutoSize） | AppTitleBar（Dock=Fill, AutoSize） |
| Row 1 | 内容区（Dock=Fill, Percent 100%） | AppMenuStrip（Dock=Fill, AutoSize） | 内容区（Dock=Fill, Percent 100%） |
| Row 2 | AppBottomStatusBar（Dock=Fill, AutoSize） | 内容区（Dock=Fill, Percent 100%） | AppBottomStatusBar.Visible = false |
| Row 3 | — | AppBottomStatusBar（Dock=Fill, AutoSize） | — |
| SetupRootLayout | `SetupRootLayout(rootTableLayoutPanel)` | `SetupRootLayout(rootTableLayoutPanel, 3)` | `SetupRootLayout(rootTableLayoutPanel)` + `AppBottomStatusBar.Visible = false` |
| 菜单栏 | 无 | AppMenuStrip | 无 |
| 双击/拖动/右键标题栏 | 同 | 同 | 同 |
| 适用场景 | 无菜单的简单窗口 | 有菜单的完整窗口 | 对话框 |

---

## §7 验证清单

| # | 检查项 | 验证方式 |
|---|--------|---------|
| 1 | 代码可编译 | `rtk dotnet build .\{{PROJECT_NAME}}.sln` |
| 2 | 继承 AppForm | 类声明 `: AppForm` |
| 3 | SetupRootLayout 已调用 | 构造函数中 `SetupRootLayout(rootTableLayoutPanel)` 在 InitializeComponent 之后；四段式传 `row: 3` |
| 4 | rootTableLayoutPanel 行数 | 三段式/两段式 RowCount=3（AutoSize/Percent/AutoSize）；四段式 RowCount=4（AutoSize/AutoSize/Percent/AutoSize） |
| 5 | AppTitleBar Dock=Fill | 在 cell 中 Dock=Fill，不是 Dock=Top |
| 6 | AppTitleBar MinimumSize | `MinimumSize = new Size(0, 32)` |
| 7 | 主题订阅/注销成对 | ThemeChanged += / -= 成对，在 Disposed 事件中注销 |
| 8 | 两段式隐藏状态栏 | `AppBottomStatusBar.Visible = false` 在 SetupRootLayout 之后 |
| 9 | 三段式状态栏可见 | AppBottomStatusBar 在 row 2，SplitterRatio/LeftContent/RightContent 已配置 |
| 10 | 无硬编码颜色 | grep `Color.FromArgb` / `Color.Xxx` 无结果 |
| 11 | Designer.cs 无手写逻辑 | 手写逻辑仅在 *.cs 中 |
| 12 | 全限定名一致 | 字段声明和属性赋值均用全限定名，设计器重序列化无 diff |
| 13 | 无 FormBorderStyle 行 | Designer.cs 中不写 FormBorderStyle |
| 14 | 双击标题栏 | 双击标题栏非按钮区域 → 最大化/还原切换 |
| 15 | 拖动标题栏 | 左键拖动标题栏非按钮区域 → 窗体移动 |

---

## §8 参考：深层文档指针

| 内容 | 唯一来源 |
|------|---------|
| AppForm 完整架构（WndProc/Region/圆角/阴影/系统菜单/SetupRootLayout） | `.ai/agents/MEMORY.md` 技术决策记录 |
| AppTitleBar 自绘标题栏规范 | `.ai/agents/MEMORY.md` AppTitleBar 条目 |
| AppBottomStatusBar 控件规范 | `Components/Composite/AppBottomStatusBar.cs` |
| AppMenuStrip 自绘菜单栏规范 | `Components/Composite/AppMenuStrip.cs` |
| 主题系统架构 | `.ai/agents/theming.md` |
| 组件创建/修改流程 | `.ai/agents/component-guide.md` |
| 调色板 16 语义颜色 | `.ai/agents/theming.md` §4 |
| 自绘控件完整模板 | `.ai/agents/component-guide.md` §2.3 |
