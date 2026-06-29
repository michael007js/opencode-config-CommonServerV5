# 皮肤系统（Theming）架构文档

本文档供 AI 助手阅读。描述 {{PROJECT_NAME}} 的皮肤/主题系统的完整架构、API 约定和扩展约束。

---

## 1. 系统定位

皮肤系统是一个**自研的 WinForms 主题基础设施**，不依赖任何第三方 UI 库。它提供：

- Light / Dark 双主题切换
- 语义化调色板（Semantic Palette），而非硬编码颜色
- 主题偏好的本地持久化（`%LOCALAPPDATA%/{{PROJECT_NAME}}/theme.json`）
- 控件树自动递归着色
- 设计时（Design-Time）安全，不干扰 Visual Studio 窗体设计器

---

## 2. 文件清单与职责

完整项目目录树见 [directory-tree.md](directory-tree.md)。本节仅列出 Theming 相关文件。

所有文件位于 `{{PROJECT_NAME}}/Components/Atomic/Theming/` 命名空间 `{{PROJECT_NAME}}.Components.Atomic.Theming` 下。

| 文件 | 类型 | 职责 |
|---|---|---|
| `AppThemeKind.cs` | `enum` | 主题类型枚举：`Light` / `Dark` |
| `AppThemePalette.cs` | `sealed class` | 不可变调色板，封装 12 个语义颜色，通过 `Create(AppThemeKind)` 工厂获取 |
| `AppThemeManager.cs` | `static class` | 全局主题管理器：状态维护、根控件注册/注销、递归着色、事件广播 |
| `AppThemeChangedEventArgs.cs` | `sealed class : EventArgs` | 主题切换事件参数，携带 `PreviousTheme` / `CurrentTheme` |
| `AppThemeSettingsStore.cs` | `internal static class` | 主题偏好持久化（JSON 读写），仅 `AppThemeManager` 内部使用 |
| `AppThemedForm.cs` | `class : Form` | 自动主题感知的窗体基类，生命周期内自动注册/注销/着色 |

关联文件（非 Theming 目录但与主题系统紧密耦合）：

| 文件 | 职责 |
|---|---|
| `Components/Composite/AppButton.cs` | 自绘按钮，订阅 `ThemeChanged` 事件自行重绘，不依赖 `ApplyRecursive` 的 BackColor/ForeColor 赋值 |
| `Components/Composite/AppLabel.cs` | 自绘标签，订阅 `ThemeChanged` 事件自行重绘，LabelStyle 决定 Text/MutedText/Accent 语义颜色 |
| `Components/Composite/AppSliderBar.cs` | 自绘滑块条，订阅 `ThemeChanged` 事件自行重绘，轨道/填充/圆钮均用语义颜色 |
| `Components/Composite/AppTabPane.cs` | 自绘 Tab 容器，订阅 `ThemeChanged` 事件自行重绘，ThemeChanged 回调恢复 Content Panel BackColor 为 ElevatedBackground |

---

## 3. 核心数据流

```
用户操作（ToggleTheme / SetTheme）
       │
       ▼
  AppThemeManager.SetTheme(theme)
       │
       ├─ 1. lock(Sync) 更新 _currentTheme（线程安全）
       ├─ 2. AppThemeSettingsStore.Save(theme) → 持久化到 theme.json
       ├─ 3. ApplyToRegisteredRoots()
       │      └─ 对每个已注册根控件调用 Apply(root)
       │           └─ ApplyRecursive(control, CurrentPalette)
       │                └─ ApplySingle(control, palette)  ← 按控件类型 switch 着色
       └─ 4. ThemeChanged?.Invoke(null, args) → 通知自绘控件（如 AppButton）
```

---

## 4. 调色板语义颜色体系

`AppThemePalette` 定义 16 个语义颜色，每个颜色都有明确的使用场景。**新增控件着色时，必须从这些语义颜色中选择，禁止硬编码 `Color.FromArgb(...)` 或 `Color.Xxx`。**

| 语义颜色 | 用途 | 典型应用控件 |
|---|---|---|
| `WindowBackground` | 顶层窗口底色 | `Form.BackColor` |
| `SurfaceBackground` | 容器/面板底色 | `Panel`, `GroupBox`, `UserControl`, `PictureBox` |
| `ElevatedBackground` | 凸起表面（卡片、对话框）底色 | `AppButton(Secondary)` 背景 |
| `InputBackground` | 输入区域底色 | `TextBox`, `ComboBox`, `NumericUpDown` |
| `Text` | 主要文字颜色 | 所有 `Enabled=true` 控件的 `ForeColor` |
| `MutedText` | 辅助/提示文字颜色 | Placeholder、脚注（目前未直接用于标准控件，供自定义控件使用） |
| `DisabledText` | 禁用状态文字颜色 | 所有 `Enabled=false` 控件的 `ForeColor` |
| `Border` | 边框/分割线颜色 | `AppButton(Secondary)` 边框、控件边框 |
| `Accent` | 强调色（品牌主色） | `AppButton(Primary)` 背景、焦点环、选中高亮 |
| `AccentText` | 强调色上的文字 | `AppButton(Primary)` 前景 |
| `SelectionBackground` | 选中项背景色 | 列表选中行、文本选区 |
| `SelectionText` | 选中项文字颜色 | 选中行文字 |
| `CloseButtonHoverBackground` | 关闭按钮悬停背景色 | 标题栏关闭按钮悬停 |
| `CloseButtonPressedBackground` | 关闭按钮按下背景色 | 标题栏关闭按钮按下 |
| `TitleBarButtonHoverBackground` | 标题栏按钮悬停背景色 | 标题栏最小化/最大化按钮悬停 |
| `TitleBarButtonPressedBackground` | 标题栏按钮按下背景色 | 标题栏最小化/最大化按钮按下 |

### 4.1 Light 调色板色值

| 语义颜色 | Hex | 视觉描述 |
|---|---|---|
| `WindowBackground` | `#F5F7FB` | 淡蓝灰 |
| `SurfaceBackground` | `#E9EEF5` | 蓝灰 |
| `ElevatedBackground` | `#F7F9FC` | 淡蓝灰（略亮于窗口） |
| `InputBackground` | `#FFFFFF` | 纯白 |
| `Text` | `#172433` | 深蓝黑 |
| `MutedText` | `#6B788C` | 蓝灰 |
| `DisabledText` | `#A1ABBA` | 浅蓝灰 |
| `Border` | `#D8E0EA` | 淡蓝灰 |
| `Accent` | `#3B82F6` | 蓝色 |
| `AccentText` | `#FFFFFF` | 纯白 |
| `SelectionBackground` | `#DBE9FF` | 淡蓝 |
| `SelectionText` | `#132444` | 深蓝 |
| `CloseButtonHoverBackground` | `#E81123` | 红色警示 |
| `CloseButtonPressedBackground` | `#C42B1C` | 深红按下 |
| `TitleBarButtonHoverBackground` | `#E5E9F0` | 微亮悬停 |
| `TitleBarButtonPressedBackground` | `#CDD4DE` | 按下变深 |

### 4.2 Dark 调色板色值

| 语义颜色 | Hex | 视觉描述 |
|---|---|---|
| `WindowBackground` | `#1F232A` | 深蓝灰 |
| `SurfaceBackground` | `#262B33` | 深灰 |
| `ElevatedBackground` | `#2A3039` | 中深灰 |
| `InputBackground` | `#2D333D` | 深灰蓝 |
| `Text` | `#F3F4F6` | 近白 |
| `MutedText` | `#A1A1AA` | 灰色 |
| `DisabledText` | `#717178` | 深灰 |
| `Border` | `#3A404C` | 深灰蓝 |
| `Accent` | `#60A5FA` | 亮蓝 |
| `AccentText` | `#0F172A` | 深蓝黑 |
| `SelectionBackground` | `#1D4ED8` | 深蓝 |
| `SelectionText` | `#F8FAFC` | 近白 |
| `CloseButtonHoverBackground` | `#C42B1C` | 深红警示 |
| `CloseButtonPressedBackground` | `#A01A1A` | 更深深红按下 |
| `TitleBarButtonHoverBackground` | `#333944` | 微亮悬停 |
| `TitleBarButtonPressedBackground` | `#282D36` | 按下变深 |

---

## 5. 控件着色映射表

`AppThemeManager.ApplySingle` 通过 `switch` 模式匹配为不同控件类型分配语义颜色：

| 控件类型 | BackColor | ForeColor | 特殊处理 |
|---|---|---|---|
| `AppLabel` | — | — | 仅 `Invalidate()`，颜色由自绘逻辑处理；LabelStyle 决定语义颜色 |
| `AppSliderBar` | — | — | 仅 `Invalidate()`，颜色由自绘逻辑处理；轨道/填充/圆钮均用语义颜色 |
| `AppButton` | — | — | 仅 `Invalidate()`，颜色由自绘逻辑处理 |
| `AppTabPane` | — | — | 仅 `Invalidate()`，颜色由自绘逻辑处理；ThemeChanged 回调恢复 Content Panel BackColor |
| `AppTitleBar` | — | — | 仅 `Invalidate()`，颜色由自绘逻辑处理；自绘标题栏用语义调色板 |
| `Form` | `WindowBackground` | `Text` | — |
| `GroupBox` | `SurfaceBackground` | `Text` | — |
| `Panel` | `SurfaceBackground` | `Text` | — |
| `UserControl` | `SurfaceBackground` | `Text` | — |
| `TextBoxBase` | `InputBackground` | `Text` / `DisabledText` | — |
| `ComboBox` | `InputBackground` | `Text` / `DisabledText` | `FlatStyle = Flat` |
| `NumericUpDown` | `InputBackground` | `Text` / `DisabledText` | — |
| `CheckBox` | `SurfaceBackground` | `Text` / `DisabledText` | — |
| `RadioButton` | `SurfaceBackground` | `Text` / `DisabledText` | — |
| `Label` | `Color.Transparent` | `Text` / `DisabledText` | — |
| `PictureBox` | `SurfaceBackground` | — | 不设 ForeColor |
| 其他（default） | `SurfaceBackground` | `Text` / `DisabledText` | 兜底策略 |

> **规则**：`ForeColor` 根据控件 `Enabled` 属性选择 `Text`（启用）或 `DisabledText`（禁用）。

---

## 6. 主题根控件机制

### 6.1 注册流程

```
AppThemedForm.OnHandleCreated
    → AppThemeManager.RegisterRoot(this)
        → PruneRoots_NoLock()          // 清理失效弱引用
        → 去重检查（ReferenceEquals）    // 同一控件不重复添加
        → Roots.Add(WeakReference)      // 弱引用存储，不阻止 GC
        → Apply(root)                   // 立即着色一次
```

### 6.2 注销流程

两个触发点（互为兜底）：

1. **`OnHandleDestroyed`** — 句柄永久销毁时（排除 `RecreatingHandle`，避免窗口重建时丢失注册）
2. **`Dispose(bool)`** — 窗体释放时

### 6.3 弱引用与清理

- `Roots` 列表使用 `WeakReference<Control>`，不阻止窗体被 GC 回收
- `PruneRoots_NoLock()` 在 `RegisterRoot` 和 `ApplyToRegisteredRoots` 时自动调用
- 清理条件：`!TryGetTarget(out _)` 或 `target.IsDisposed`

---

## 7. 自绘控件的主题集成模式

`AppButton` 是当前唯一的自绘控件，它**不走 `ApplySingle` 的 BackColor/ForeColor 赋值路径**，而是采用以下模式：

```
OnHandleCreated
    → EnsureThemeSubscription()
        → AppThemeManager.ThemeChanged += AppThemeManager_ThemeChanged
        → AppThemeManager.Initialize()

OnPaint
    → ResolveColors(AppThemeManager.CurrentPalette)   // 每次绘制读取当前调色板
    → 根据 ButtonType 映射语义颜色
    → 状态计算（hover/pressed/disabled）
    → 自绘

ThemeChanged 事件回调
    → Invalidate()  // 触发重绘，OnPaint 自然拿到新 palette
```

### 7.1 AppButton 的颜色映射

| ButtonType | Background | Foreground | Border |
|---|---|---|---|
| `Primary` | `Accent` | `AccentText` | `Accent` |
| `Secondary` | `ElevatedBackground` | `Text` | `Border` |
| `Ghost` | `Transparent` | `Text` | `Transparent` |

交互状态的颜色调整通过 `Blend()` 方法在基础色上叠加：

| 状态 | Primary 背景 | Secondary 背景 | Ghost 背景 |
|---|---|---|---|
| Hover | `Blend(Accent, White, 0.10)` | `Blend(Elevated, Input, 0.55)` | `Accent @ 30% alpha` |
| Pressed | `Blend(Accent, Black, 0.12)` | `Blend(Elevated, Surface, 0.65)` | `Accent @ 52% alpha` |
| Disabled | `Blend(Back, Canvas, 0.35)` | 同左 | `Transparent` |

---

## 8. 设计时安全策略

`AppThemeManager.IsDesignTimeContext()` 采用四重检测，确保在 Visual Studio 设计器中不触发运行时逻辑：

1. **LicenseManager.UsageMode** — 检测 `LicenseUsageMode.Designtime`
2. **ISite.DesignMode** — 沿控件父级链向上检查
3. **进程名** — 检测 `devenv` / `designtoolsserver` / `xdesproc`
4. **AppDomain.FriendlyName** — 检测 `DesignToolsServer`（.NET 5+ 进程外设计器）

受保护的入口点：

- `SetTheme` — 设计时直接 return
- `RegisterRoot` — 设计时跳过注册
- `Apply` — 设计时跳过着色
- `EnsureInitialized` — 设计时跳过文件读取
- `AppButton.EnsureThemeSubscription` — 设计时跳过事件订阅

---

## 9. 线程安全设计

| 共享状态 | 保护方式 | 说明 |
|---|---|---|
| `_currentTheme` | `lock(Sync)` 读写 | 双重检查锁定模式 |
| `Roots` 列表 | `lock(Sync)` 读写 | 快照+释放锁模式避免 UI 死锁 |
| `_initialized` | 双重检查锁定 | 确保只初始化一次 |

`ApplyToRegisteredRoots` 的关键设计：在 `lock(Sync)` 内复制存活根控件到本地列表，**释放锁后再遍历执行 `Apply`**，避免在持有锁时触发控件 UI 操作导致死锁。

---

## 10. 持久化细节

- 路径：`%LOCALAPPDATA%/{{PROJECT_NAME}}/theme.json`
- 格式：`{ "Theme": "Light" }` 或 `{ "Theme": "Dark" }`
- 序列化：`System.Text.Json`，`WriteIndented = true`
- 容错：`Load()` 任何异常均回退到 `AppThemeKind.Light`；`Save()` 异常静默忽略
- 首次运行无文件时默认 `Light`

---

## 11. 给 AI 的工作约束

### 11.1 必须遵守

- **禁止硬编码颜色**：新增控件的着色必须使用 `AppThemePalette` 的语义颜色属性，不得使用 `Color.FromArgb(...)` 或系统预定义色
- **自绘控件必须订阅 `ThemeChanged`**：自绘控件（override `OnPaint`）不走 `ApplySingle` 路径，必须自行订阅 `AppThemeManager.ThemeChanged` 并在回调中 `Invalidate()`
- **新增顶层窗体必须继承 `AppThemedForm`**：而非直接继承 `Form`，否则不会自动获得主题支持
- **新增 `ApplySingle` 分支放在 `default` 之前**：`switch` 模式匹配从上到下，更具体的类型必须在更通用的类型之前
- **设计时检查不可省略**：任何新增加的运行时主题逻辑都须通过 `IsDesignTimeFor` 保护
- **修改调色板色值须同时更新 Light 和 Dark**：两个调色板是成对的，修改其中一个时必须同步考虑另一个的对比度和层次关系

### 11.2 推荐做法

- 新增自定义控件放到 `Components/Composite/` 目录
- 自绘控件的颜色映射逻辑参考 `AppButton.ResolveColors` 的模式：基础色 → 状态叠加 → 一次性返回颜色集合
- 新增语义颜色属性时，需同步更新 `AppThemePalette` 的构造函数、`Light`/`Dark` 静态属性、以及 `ApplySingle` 中对应的控件着色分支
- 需要主题感知的非控件代码（如打印、导出图片）应订阅 `AppThemeManager.ThemeChanged` 事件，而非轮询 `CurrentTheme`

### 11.3 扩展场景速查

| 扩展需求 | 操作步骤 |
|---|---|
| 新增第三种主题 | 1. `AppThemeKind` 添加枚举值<br>2. `AppThemePalette` 添加静态属性<br>3. `AppThemePalette.Create` 添加分支<br>4. `AppButton.GetDefaultColors` 等自绘逻辑按需适配 |
| 新增语义颜色 | 1. `AppThemePalette` 构造函数加参数<br>2. 添加属性<br>3. `Light`/`Dark` 静态属性添加色值<br>4. `ApplySingle` 中按需使用 |
| 新增标准控件着色 | 1. 在 `ApplySingle` 的 `switch` 中添加模式匹配分支（放在 `default` 之前）<br>2. 选择合适的语义颜色 |
| 新增自绘控件 | 1. 参考 `AppButton` 实现<br>2. `OnHandleCreated` 中 `EnsureThemeSubscription`<br>3. `OnPaint` 中通过 `AppThemeManager.CurrentPalette` 获取颜色<br>4. `Dispose` 中取消事件订阅 |
| 让现有 Form 支持主题 | 改为继承 `AppThemedForm`，或手动调用 `AppThemeManager.RegisterRoot(this)` / `UnregisterRoot(this)` |

---

## 12. 函数表

列举 `{{PROJECT_NAME}}.Components.Atomic.Theming` 命名空间下所有类型的全部公共及内部成员，以及关联的 `AppButton` 主题相关成员。

### 12.1 AppThemeKind（enum）

| 成员 | 值 | 说明 |
|---|---|---|
| `Light` | `0` | 浅色主题 |
| `Dark` | `1` | 深色主题 |

### 12.2 AppThemePalette（sealed class）

**构造函数**

| 签名 | 访问级 | 说明 |
|---|---|---|
| `AppThemePalette(Color windowBackground, Color surfaceBackground, Color elevatedBackground, Color inputBackground, Color text, Color mutedText, Color disabledText, Color border, Color accent, Color accentText, Color selectionBackground, Color selectionText, Color closeButtonHoverBackground, Color closeButtonPressedBackground, Color titleBarButtonHoverBackground, Color titleBarButtonPressedBackground)` | `private` | 不可外部构造，通过工厂或静态属性获取 |

**实例属性**

| 签名 | 类型 | 访问 | 说明 |
|---|---|---|---|
| `WindowBackground` | `Color` | `get` | 顶层窗口背景色 |
| `SurfaceBackground` | `Color` | `get` | 容器面板背景色 |
| `ElevatedBackground` | `Color` | `get` | 凸起表面背景色 |
| `InputBackground` | `Color` | `get` | 输入控件背景色 |
| `Text` | `Color` | `get` | 主要文本颜色 |
| `MutedText` | `Color` | `get` | 辅助文本颜色 |
| `DisabledText` | `Color` | `get` | 禁用态文本颜色 |
| `Border` | `Color` | `get` | 边框颜色 |
| `Accent` | `Color` | `get` | 强调色 |
| `AccentText` | `Color` | `get` | 强调色上的文字颜色 |
| `SelectionBackground` | `Color` | `get` | 选中项背景色 |
| `SelectionText` | `Color` | `get` | 选中项文字颜色 |
| `CloseButtonHoverBackground` | `Color` | `get` | 关闭按钮悬停背景色 |
| `CloseButtonPressedBackground` | `Color` | `get` | 关闭按钮按下背景色 |
| `TitleBarButtonHoverBackground` | `Color` | `get` | 标题栏按钮悬停背景色 |
| `TitleBarButtonPressedBackground` | `Color` | `get` | 标题栏按钮按下背景色 |

**静态属性**

| 签名 | 类型 | 说明 |
|---|---|---|
| `Light` | `AppThemePalette` | 浅色主题预定义调色板单例 |
| `Dark` | `AppThemePalette` | 深色主题预定义调色板单例 |

**静态方法**

| 签名 | 返回类型 | 说明 |
|---|---|---|
| `Create(AppThemeKind themeKind)` | `AppThemePalette` | 工厂方法，按主题类型返回对应调色板 |

### 12.3 AppThemeManager（static class）

**静态事件**

| 签名 | 类型 | 说明 |
|---|---|---|
| `ThemeChanged` | `EventHandler<AppThemeChangedEventArgs>?` | 主题切换后触发，sender 为 null |

**静态属性**

| 签名 | 类型 | 访问 | 说明 |
|---|---|---|---|
| `IsDesignTime` | `bool` | `get` | 当前是否处于设计时模式（无参版本） |
| `CurrentTheme` | `AppThemeKind` | `get` | 当前生效的主题类型，首次访问触发懒初始化 |
| `CurrentPalette` | `AppThemePalette` | `get` | 当前主题对应的调色板实例 |

**静态方法**

| 签名 | 返回类型 | 访问 | 说明 |
|---|---|---|---|
| `IsDesignTimeFor(Control? control)` | `bool` | `public` | 检测指定控件是否处于设计时模式（含父级链站点检测） |
| `Initialize()` | `void` | `public` | 显式初始化，幂等，通常无需手动调用 |
| `SetTheme(AppThemeKind theme)` | `void` | `public` | 切换到指定主题：更新状态→持久化→着色→广播事件 |
| `ToggleTheme()` | `void` | `public` | 在 Light/Dark 之间切换 |
| `RegisterRoot(Control root)` | `void` | `public` | 注册主题根控件（弱引用+去重），注册后立即 Apply 一次 |
| `UnregisterRoot(Control root)` | `void` | `public` | 注销主题根控件，同时清理失效弱引用 |
| `Apply(Control control)` | `void` | `public` | 对控件及其子树递归应用当前调色板颜色 |
| `EnsureInitialized()` | `void` | `private` | 双重检查锁定初始化，从 SettingsStore 加载偏好 |
| `ApplyToRegisteredRoots()` | `void` | `private` | 快照根控件列表后释放锁，逐个调用 Apply |
| `ApplyRecursive(Control control, AppThemePalette palette)` | `void` | `private` | 递归遍历控件树，SuspendLayout/ResumeLayout 批量着色 |
| `ApplySingle(Control control, AppThemePalette palette)` | `void` | `private` | 按控件类型 switch 匹配分配语义颜色 |
| `PruneRoots_NoLock()` | `void` | `private` | 清理已 GC 或已释放的弱引用，须在 lock(Sync) 内调用 |
| `IsDesignTimeContext(Control? control = null)` | `bool` | `private` | 四重设计时检测：LicenseManager→Site链→进程名→AppDomain |

**私有静态字段**

| 签名 | 类型 | 说明 |
|---|---|---|
| `Sync` | `object` | 线程同步锁对象 |
| `Roots` | `List<WeakReference<Control>>` | 已注册根控件弱引用列表 |
| `_initialized` | `bool` | 初始化完成标志 |
| `_currentTheme` | `AppThemeKind` | 当前主题状态，默认 Light |

### 12.4 AppThemeChangedEventArgs（sealed class : EventArgs）

**构造函数**

| 签名 | 访问级 | 说明 |
|---|---|---|
| `AppThemeChangedEventArgs(AppThemeKind previousTheme, AppThemeKind currentTheme)` | `public` | 初始化事件参数，不可变 |

**属性**

| 签名 | 类型 | 访问 | 说明 |
|---|---|---|---|
| `PreviousTheme` | `AppThemeKind` | `get` | 切换前的主题类型 |
| `CurrentTheme` | `AppThemeKind` | `get` | 切换后的新主题类型 |

### 12.5 AppThemeSettingsStore（internal static class）

**方法**

| 签名 | 返回类型 | 访问 | 说明 |
|---|---|---|---|
| `Load()` | `AppThemeKind` | `internal` | 从 theme.json 读取主题偏好，失败回退 Light |
| `Save(AppThemeKind theme)` | `void` | `internal` | 将主题偏好序列化写入 theme.json，失败静默 |
| `GetSettingsPath()` | `string` | `private` | 返回 `%LOCALAPPDATA%/{{PROJECT_NAME}}/theme.json` |

**私有类型**

| 签名 | 访问 | 说明 |
|---|---|---|
| `ThemeSettings` | `private sealed` | JSON 数据模型，仅 `Theme` 字符串属性 |

**私有常量**

| 签名 | 值 | 说明 |
|---|---|---|
| `FileName` | `"theme.json"` | 设置文件名 |
| `AppDirectory` | `"{{PROJECT_NAME}}"` | LocalApplicationData 下的子目录名 |

### 12.6 AppThemedForm（class : Form）

**特性**

| 特性 | 值 | 说明 |
|---|---|---|
| `DesignerCategory` | `"Form"` | 设计器分类 |
| `ToolboxItem` | `false` | 不出现在工具箱中 |

**受保护方法**

| 签名 | 返回类型 | 说明 |
|---|---|---|
| `OnHandleCreated(EventArgs e)` | `void` | 句柄创建后 RegisterRoot，设计时跳过 |
| `OnControlAdded(ControlEventArgs e)` | `void` | 子控件添加时自动 Apply，设计时跳过 |
| `OnHandleDestroyed(EventArgs e)` | `void` | 句柄永久销毁时 UnregisterRoot（排除 RecreatingHandle），设计时跳过 |
| `Dispose(bool disposing)` | `void` | 释放时兜底 UnregisterRoot，设计时跳过 |

### 12.7 关联：AppButton 中的主题相关成员

位于 `{{PROJECT_NAME}}.Components.Composite`，与主题系统紧密耦合的自绘控件。

**私有方法**

| 签名 | 返回类型 | 说明 |
|---|---|---|
| `EnsureThemeSubscription()` | `void` | OnHandleCreated 中调用，订阅 ThemeChanged 事件 |
| `AppThemeManager_ThemeChanged(object? sender, AppThemeChangedEventArgs e)` | `void` | 事件回调，Invoke 跨线程安全 Invalidate |
| `ResolveColors(AppThemePalette palette)` | `ButtonVisualColors` | 按 ButtonType + 交互状态解析完整颜色集 |
| `GetDefaultColors(AppThemePalette palette)` | `(Color, Color, Color)` | ButtonType → 基础 Back/Fore/Border 三元组 |
| `GetHoverBackground(Color, AppThemePalette)` | `Color` | 悬停态背景色计算 |
| `GetPressedBackground(Color, AppThemePalette)` | `Color` | 按下态背景色计算 |
| `GetHoverBorder(Color, AppThemePalette)` | `Color` | 悬停态边框色计算 |
| `GetPressedBorder(Color, AppThemePalette)` | `Color` | 按下态边框色计算 |
| `ResolveCanvasColor()` | `Color` | 打底背景色：Parent.BackColor ?? SurfaceBackground |
| `Blend(Color baseColor, Color overlayColor, float amount)` | `Color` | 颜色线性插值混合（static） |

**私有字段**

| 签名 | 类型 | 说明 |
|---|---|---|
| `_themeSubscribed` | `bool` | 是否已订阅 ThemeChanged 事件 |

### 12.8 关联：AppTabPane 中的主题相关成员

位于 `{{PROJECT_NAME}}.Components.Composite`，与主题系统紧密耦合的自绘 Tab 容器控件。

**私有方法**

| 签名 | 返回类型 | 说明 |
|---|---|---|
| `EnsureThemeSubscription()` | `void` | OnHandleCreated 中调用，订阅 ThemeChanged 事件 |
| `AppThemeManager_ThemeChanged(object? sender, AppThemeChangedEventArgs e)` | `void` | 事件回调，Invalidate + RestoreContentPanelColors |
| `RestoreContentPanelColors()` | `void` | 恢复所有 Content Panel BackColor 为 ElevatedBackground |
| `ResolveColors(int index, AppThemePalette palette)` | `TabVisualColors` | 按 Tab 索引 + 选中/悬停状态解析颜色集 |
| `ResolveCanvasColor()` | `Color` | 打底背景色：Parent.BackColor ?? SurfaceBackground |
| `Blend(Color baseColor, Color overlayColor, float amount)` | `Color` | 颜色线性插值混合（static） |

**私有字段**

| 签名 | 类型 | 说明 |
|---|---|---|
| `_themeSubscribed` | `bool` | 是否已订阅 ThemeChanged 事件 |
| `_hoveredIndex` | `int` | 鼠标悬停的 Tab 索引，-1 表示无悬停 |
| `_closeHoveredIndex` | `int` | 鼠标悬停在关闭按钮上的 Tab 索引 |

---

## 13. 一句话摘要

{{PROJECT_NAME}} 的皮肤系统是一个**静态管理器 + 语义调色板 + 弱引用根控件树 + 设计时安全**的 WinForms 自研主题基础设施：窗体继承 `AppThemedForm` 即可自动获得 Light/Dark 切换能力，自绘控件订阅 `ThemeChanged` 事件自行重绘，所有颜色必须来自 `AppThemePalette` 的 16 个语义属性，禁止硬编码。
