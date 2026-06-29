---
name: "winforms-components"
description: "项目自定义 WinForms 组件库使用指南，包含 AppButton、AppThemedForm、AppThemePalette 等。创建按钮、窗体、自绘控件、主题集成时触发。"
version: "1.1.0"
updatedAt: "2026-05-28"
tags: [组件, 按钮, 窗体, 主题, 自绘, Theming, AppButton, AppThemedForm, 调色板]
---

# WinForms 组件库 Skill

项目自定义 WinForms 组件库使用指南。

---

## 触发条件

**关键词触发：**
- 按钮类：AppButton、AppButtonType、AppButtonSize
- 窗体类：AppThemedForm、Form
- 主题类：AppThemeManager、AppThemePalette、AppThemeKind、ThemeChanged
- 枚举：AppButtonType(Primary/Secondary/Ghost)、AppButtonSize(Small/Medium/Large)、AppThemeKind(Light/Dark)
- 场景词：按钮、窗体、自绘控件、主题、调色板、圆角、DPI 缩放、离屏绘制、设计器安全

**场景触发：**
- 创建 UI 界面
- 新增自定义控件
- 按钮样式配置
- 主题/颜色集成
- 自绘控件开发
- 窗体创建

---

## 导入方式

```csharp
using {{PROJECT_NAME}}.Components.Composite;        // AppButton
using {{PROJECT_NAME}}.Components.Atomic.Theming;   // AppThemeManager, AppThemePalette, AppThemeKind, AppThemedForm
```

---

## 组件快速索引

### 基础组件

| 组件 | 用途 | 核心参数 |
|------|------|---------|
| **AppButton** | 自绘按钮 | ButtonType(Primary/Secondary/Ghost)、ButtonSize(Small/Medium/Large)、IsLoading、GlyphText、GlyphFont、GlyphSize、CornerRadius、ShowBorder、UseCustomColors |
| **AppImage** | 自绘图片控件 | Source(本地/网络)、AspectRatio(7种)、CornerRadius、EnableCache |
| **AppThemedForm** | 主题感知窗体基类 | 自动 RegisterRoot/UnregisterRoot、自动 Apply 递归着色 |

### 主题基础设施

| 组件 | 用途 | 核心成员 |
|------|------|---------|
| **AppThemeManager** | 全局主题管理器 | SetTheme()、ToggleTheme()、CurrentPalette、CurrentTheme、ThemeChanged、Apply()、RegisterRoot() |
| **AppThemePalette** | 不可变语义调色板 | 12 语义颜色属性、Light/Dark 静态属性、Create(AppThemeKind) |
| **AppThemeKind** | 主题类型枚举 | Light、Dark |

---

## 常见场景推荐

| 场景 | 推荐方案 | 说明 |
|------|---------|------|
| 创建新窗体 | 继承 `AppThemedForm` | 自动获得主题支持，不要直接继承 `Form` |
| 主操作按钮 | `AppButton` + `ButtonType.Primary` | 强调色背景 |
| 次要操作按钮 | `AppButton` + `ButtonType.Secondary` | 凸起表面背景 + 描边 |
| 幽灵/文字按钮 | `AppButton` + `ButtonType.Ghost` | 透明背景 |
| 异步提交 | `AppButton.IsLoading = true` | 自动显示 spinner，禁用交互 |
| 图标按钮 | `AppButton.GlyphText` + `GlyphFont` | 字形图标（如 Segoe Fluent Icons） |
| 切换主题 | `AppThemeManager.ToggleTheme()` | Light ↔ Dark |
| 设置主题 | `AppThemeManager.SetTheme(AppThemeKind.Dark)` | 指定主题 |
| 读取当前颜色 | `AppThemeManager.CurrentPalette` | 获取语义调色板 |
| 自绘控件集成主题 | 订阅 `ThemeChanged` + `Invalidate()` | → 自绘控件模板见 [component-guide.md](../../../agents/component-guide.md) §2.3 |

---

## AppButton 自绘按钮

完全自绘的现代化按钮，圆角、图标、加载动画、交互状态一应俱全。

### 基础使用

```csharp
var button = new AppButton
{
    Text = "确认",
    ButtonType = AppButtonType.Primary,
    ButtonSize = AppButtonSize.Medium
};
button.Click += (s, e) => { /* 处理点击 */ };
```

### 按钮类型与颜色映射

| ButtonType | 背景 | 前景 | 边框 | 典型场景 |
|---|---|---|---|---|
| `Primary` | Accent | AccentText | Accent | 主操作、提交、确认 |
| `Secondary` | ElevatedBackground | Text | Border | 次要操作、取消 |
| `Ghost` | Transparent | Text | Transparent | 文字按钮、链接式操作 |

> 交互状态（Hover/Pressed/Disabled/Focused）的颜色叠加规则 → 见 [theming.md](../../../agents/theming.md) §7.1

### 尺寸规格

| ButtonSize | 高度(px) | 水平内边距 | 垂直内边距 | 图标尺寸 |
|---|---|---|---|---|
| `Small` | 32 | 12 | 6 | 16 |
| `Medium` | 36 | 14 | 7 | 18 |
| `Large` | 42 | 16 | 8 | 20 |

> 所有数值经 `ScaleInt()` 按 DPI 缩放。

### 加载状态

```csharp
async void OnSubmit()
{
    submitButton.IsLoading = true;
    try
    {
        await DoWorkAsync();
    }
    finally
    {
        submitButton.IsLoading = false;
    }
}
```

`IsLoading = true` 时：自动显示旋转 spinner、禁用点击交互、启动 80ms 帧动画。

### 图标按钮

```csharp
var iconButton = new AppButton
{
    GlyphText = "\uE721",              // Segoe Fluent Icons 字形
    GlyphFont = new Font("Segoe Fluent Icons", 12f),
    GlyphSize = 16f,
    ButtonType = AppButtonType.Ghost,
    ButtonSize = AppButtonSize.Small
};
```

内容优先级：`Image > GlyphText > Text`，支持"图标+文字"组合（通过 `TextImageRelation` 控制）。

### 自定义颜色

```csharp
var dangerButton = new AppButton
{
    Text = "删除",
    ButtonType = AppButtonType.Primary,
    UseCustomColors = true,
    CustomBackColor = Color.FromArgb(239, 68, 68),  // 红色
    CustomForeColor = Color.White,
    CustomBorderColor = Color.FromArgb(239, 68, 68)
};
```

> 自定义颜色仍参与 hover/pressed/disabled 状态计算，不会跳过。

### 参数说明

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| ButtonType | AppButtonType | Secondary | 按钮视觉类型 |
| ButtonSize | AppButtonSize | Medium | 尺寸级别 |
| IsLoading | bool | false | 加载状态（显示 spinner，禁用交互） |
| GlyphText | string | "" | 字形图标文本 |
| GlyphFont | Font? | null | 字形图标字体 |
| GlyphSize | float | 0 | 字形图标尺寸（0 时按 ButtonSize 默认） |
| CornerRadius | int | 8 | 圆角半径（DPI 缩放） |
| ShowBorder | bool | Secondary=true, 其他=false | 是否显示边框 |
| UseCustomColors | bool | false | 启用自定义颜色覆盖 |
| CustomBackColor | Color | Empty | 自定义背景色 |
| CustomForeColor | Color | Empty | 自定义前景色 |
| CustomBorderColor | Color | Empty | 自定义边框色 |

---

## AppThemedForm 主题窗体基类

自动主题感知的窗体基类，生命周期内自动管理根控件注册和递归着色。

### 基础使用

```csharp
public class MainForm : AppThemedForm
{
    public MainForm()
    {
        Text = "{{PROJECT_NAME}}";
        ClientSize = new Size(800, 450);
    }
}
```

### 切换主题

```csharp
AppThemeManager.ToggleTheme();                           // Light ↔ Dark
AppThemeManager.SetTheme(AppThemeKind.Dark);             // 指定主题
AppThemeKind current = AppThemeManager.CurrentTheme;     // 读取当前主题
```

主题切换自动：更新状态 → 持久化 → 递归着色所有根控件 → 广播 ThemeChanged 事件。

> AppThemedForm 生命周期行为（RegisterRoot/UnregisterRoot/OnControlAdded 等）→ 见[theming.md](../../../agents/theming.md) §6 + §12.6

---

## 参考：深层文档指针

以下内容在 SKILL 中仅提供指针，详细规范见对应文档：

| 内容 | 唯一来源 | 节 |
|------|---------|-----|
| 语义颜色定义及 Light/Dark Hex 色值 | [theming.md](../../../agents/theming.md) | §4 |
| 控件着色映射表（ApplySingle） | [theming.md](../../../agents/theming.md) | §5 |
| 主题集成决策树 | [component-guide.md](../../../agents/component-guide.md) | §4 |
| 自绘控件完整模板代码及检查清单 | [component-guide.md](../../../agents/component-guide.md) | §2.3 |
| 目录放置与命名空间规则 | [component-guide.md](../../../agents/component-guide.md) | §1 |
| 新增着色分支步骤（ApplySingle） | [component-guide.md](../../../agents/component-guide.md) | §3.3 |
| 新增语义颜色步骤 | [theming.md](../../../agents/theming.md) | §11.3 |
| 修改 AppThemePalette 步骤 | [component-guide.md](../../../agents/component-guide.md) | §3.4 |
| 常见错误及修复 | [component-guide.md](../../../agents/component-guide.md) | §8 |
| 设计器兼容规范 | [component-guide.md](../../../agents/component-guide.md) | §6 |
| 注释规范 | [component-guide.md](../../../agents/component-guide.md) | §5 |
| 完整函数表（API 签名） | [theming.md](../../../agents/theming.md) | §12 |
| 线程安全设计 | [theming.md](../../../agents/theming.md) | §9 |
| 持久化细节 | [theming.md](../../../agents/theming.md) | §10 |
| 设计时安全策略 | [theming.md](../../../agents/theming.md) | §8 |
| 技术栈与外部依赖 | [tech-stack.md](../../../agents/tech-stack.md) | 全文 |
