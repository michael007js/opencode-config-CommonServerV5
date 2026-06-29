# 组件创建与更新指南

本文档供 AI 助手阅读。规定在 {{PROJECT_NAME}} 中新增或修改 WinForms 组件时必须遵守的规范、步骤和检查清单。

---

## 1. 组件目录结构

完整项目目录树见 [directory-tree.md](directory-tree.md)。以下仅列出 `Components/` 部分：

```
Components/
├── Atomic/          ← 原子级基础设施（无 UI、无控件、纯逻辑/数据/配置）
│   └── Theming/     ← 皮肤系统（AppThemeManager、AppThemePalette 等）
└── Composite/       ← 复合级 UI 控件（可拖入设计器、有自绘逻辑的自定义控件）
    ├── AppButton.cs ← 自绘按钮
    ├── AppImage.cs  ← 自绘图片控件
    ├── AppLabel.cs  ← 自绘标签控件（LabelStyle+圆角背景+主题适配）
    ├── AppSliderBar.cs ← 自绘滑块条控件（轨道+圆钮+拖拽+数值提示+主题适配）
    ├── AppTabPane.cs ← 自绘 Tab 容器控件
    ├── AppTabPage.cs ← Tab 页数据模型
    ├── AppTabPageCollection.cs ← Tab 页集合
    └── AppTitleBar.cs ← 自绘标题栏控件（NativeWindow 子类化拖动）
```

### 1.1 放置规则

| 类型 | 放置位置 | 判断依据 |
|---|---|---|
| 自定义 WinForms 控件（继承 Control / Button / UserControl 等） | `Components/Composite/` | 有 UI 呈现、可拖入设计器、有自绘或样式逻辑 |
| 枚举、数据模型、工具类、静态服务 | `Components/Atomic/` | 无 UI 呈现、纯逻辑、被 Composite 层依赖 |
| 窗体（Form） | 项目根目录或业务目录 | 不放 Components/，窗体是组件的消费者 |

### 1.2 命名空间规则

| 目录 | 命名空间 |
|---|---|
| `Components/Atomic/*` | `{{PROJECT_NAME}}.Components.Atomic.<子目录>` |
| `Components/Composite/*` | `{{PROJECT_NAME}}.Components.Composite` |

> 子目录名用 PascalCase。Composite 下的控件目前平铺，不建子目录，除非同类控件超过 5 个。

### 1.3 文件命名规则

- 一个文件一个公共类型，文件名与类型名相同
- 枚举若仅服务于单个控件，可放在同一文件内（参考 `AppButton.cs` 中的 `AppButtonType` / `AppButtonSize`）
- 枚举若被多个类型共用，独立成文件放到对应的 Atomic 子目录

---

## 2. 新增组件清单

### 2.1 新增 Atomic 类型（枚举 / 工具类 / 静态服务）

**步骤**：

1. 在 `Components/Atomic/` 下创建或进入合适子目录
2. 创建 `.cs` 文件，设置正确命名空间
3. 编写类型，添加 `/// <summary>` XML 文档注释
4. 若涉及主题系统，遵守 [theming.md](theming.md) 中的约束（使用语义颜色、设计时保护等）
5. 构建验证

**检查清单**：

- [ ] 命名空间符合 1.2 规则
- [ ] 公共成员均有 XML 文档注释
- [ ] 若引用 `AppThemeManager` / `AppThemePalette`，颜色来源为语义属性，无硬编码
- [ ] 若有运行时逻辑需要跳过设计时，使用 `AppThemeManager.IsDesignTimeFor()`
- [ ] `internal` 类型仅在 Atomic 或 Composite 内部使用时才设为 internal
- [ ] 构建通过

### 2.2 新增 Composite 控件（标准控件，无自绘）

标准控件指仅通过 `BackColor` / `ForeColor` / `Font` 等属性呈现外观、不 override `OnPaint` 的控件。

**步骤**：

1. 在 `Components/Composite/` 下创建 `.cs` 文件
2. 继承合适的 WinForms 基类（如 `UserControl`）
3. 添加设计器特性：

```csharp
[ToolboxItem(true)]
[DesignerCategory("Code")]
```

4. 编写控件逻辑
5. 若需主题支持，无需订阅 `ThemeChanged`——`AppThemeManager.ApplyRecursive` 会自动设置 `BackColor` / `ForeColor`
6. 若需特殊颜色逻辑（如某个子区域需要 `Accent` 色），从 `AppThemeManager.CurrentPalette` 获取
7. 添加 XML 文档注释
8. 构建验证

**检查清单**：

- [ ] 命名空间为 `{{PROJECT_NAME}}.Components.Composite`
- [ ] 有 `[ToolboxItem(true)]` 和 `[DesignerCategory("Code")]`
- [ ] 公共属性/方法/事件均有 XML 文档注释
- [ ] 颜色来自 `AppThemePalette` 语义属性，无硬编码
- [ ] 构建通过

### 2.3 新增 Composite 控件（自绘控件）

自绘控件指 override `OnPaint` 并通过 `Graphics` 自行绘制外观的控件。**这是最复杂的场景**，须严格遵守以下规范。

**步骤**：

1. 在 `Components/Composite/` 下创建 `.cs` 文件
2. 继承合适的 WinForms 基类
3. 构造函数中设置自绘样式：

```csharp
SetStyle(
    ControlStyles.AllPaintingInWmPaint
    | ControlStyles.OptimizedDoubleBuffer
    | ControlStyles.ResizeRedraw
    | ControlStyles.Selectable
    | ControlStyles.UserPaint,
    true);
DoubleBuffered = true;
```

4. 添加设计器特性 `[ToolboxItem(true)]` `[DesignerCategory("Code")]`
5. **接入主题系统**（必须）— 完整模板代码见 [theming.md](theming.md) §7「自绘控件的主题集成模式」，核心要点：

```csharp
// OnHandleCreated → EnsureThemeSubscription()
// OnPaint → AppThemeManager.CurrentPalette 获取颜色
// ThemeChanged 回调 → Invalidate()
// Dispose → 取消事件订阅
// 设计时跳过 → IsDesignTimeFor(this)
```

6. **OnPaint 中读取调色板**：

```csharp
protected override void OnPaint(PaintEventArgs e)
{
    AppThemePalette palette = AppThemeManager.CurrentPalette;
    // 用 palette 的语义颜色绘制，禁止硬编码
}
```

7. **圆角绘制**（若需要）— 参考 `AppButton.CreateRoundedPath`
8. **DPI 缩放**（若需要）— 参考 `AppButton.ScaleInt` / `ScaleFloat`
9. **离屏绘制**（避免圆角黑边）— 参考 `AppButton.OnPaint` 的 surface 位图模式
10. 添加 XML 文档注释
11. 构建验证

**检查清单**：

- [ ] SetStyle 包含 `AllPaintingInWmPaint | OptimizedDoubleBuffer | ResizeRedraw | UserPaint`
- [ ] `DoubleBuffered = true`
- [ ] `OnHandleCreated` 中调用 `EnsureThemeSubscription()`
- [ ] `Dispose` 中取消 `ThemeChanged` 订阅
- [ ] `ThemeChanged` 回调中使用 `InvokeRequired` / `BeginInvoke`
- [ ] `OnPaint` 中通过 `AppThemeManager.CurrentPalette` 获取颜色
- [ ] 所有颜色为语义属性，无 `Color.FromArgb(...)` / `Color.Xxx` 硬编码
- [ ] 设计时检查：`EnsureThemeSubscription` 中跳过设计时
- [ ] 有 `[ToolboxItem(true)]` 和 `[DesignerCategory("Code")]`
- [ ] 公共成员均有 XML 文档注释
- [ ] 构建通过

---

## 3. 修改现有组件

### 3.1 修改 Atomic 类型

| 操作 | 注意事项 |
|---|---|
| 新增公共属性/方法 | 添加 XML 文档注释；若与主题相关，检查 `theming.md` 约束 |
| 修改签名 | 全项目搜索引用，确保所有调用方同步更新 |
| 新增设计时保护 | 使用 `AppThemeManager.IsDesignTimeFor()` |
| 修改调色板色值 | Light 和 Dark 必须成对更新，检查对比度层次关系 |

### 3.2 修改 Composite 控件

| 操作 | 注意事项 |
|---|---|
| 新增颜色相关属性 | 值必须来自 `AppThemePalette` 语义属性，或通过 `UseCustomColors` 模式允许用户覆盖 |
| 新增交互状态 | 在 `OnPaint` → `ResolveColors` 中处理，不要在事件处理中直接设置 BackColor/ForeColor |
| 修改 OnPaint 逻辑 | 确保颜色仍从 `AppThemeManager.CurrentPalette` 获取 |
| 新增子控件 | 若子控件为标准 WinForms 控件，`ApplyRecursive` 会自动着色；若为自绘子控件，需确保其也订阅了 `ThemeChanged` |
| 新增公共属性 | 添加 `[DefaultValue]` 特性；添加 XML 文档注释；在 setter 中调用 `Invalidate()` |

### 3.3 修改 AppThemeManager.ApplySingle

新增控件类型的着色分支时：

1. 在 `switch` 中添加模式匹配分支，**放在 `default` 之前**
2. 选择正确的语义颜色（参考 [theming.md](theming.md) 第 5 节控件着色映射表）
3. `ForeColor` 遵循 `Enabled ? Text : DisabledText` 模式
4. 自绘控件（如 `AppButton`）仅需 `Invalidate()`，不设 BackColor/ForeColor
5. 更新 [theming.md](theming.md) 第 5 节的映射表

### 3.4 修改 AppThemePalette

新增语义颜色属性时：

1. 构造函数加参数
2. 添加只读属性
3. `Light` 静态属性添加色值
4. `Dark` 静态属性添加色值
5. `ApplySingle` 中按需使用新颜色
6. 更新 [theming.md](theming.md) 第 4 节的语义颜色体系表

---

## 4. 主题集成决策树

```
新组件需要颜色吗？
├─ 否 → 不需要主题集成，正常编写
└─ 是 → 控件是自绘的吗？
    ├─ 否（标准控件）→
    │   ├─ 作为 Form 子控件自动被 ApplyRecursive 着色？
    │   │   ├─ 是 → 无需额外代码
    │   │   └─ 否 → 手动调用 AppThemeManager.Apply(control)
    │   └─ 需要特定语义颜色（如 Accent）？
    │       └─ 从 AppThemeManager.CurrentPalette 读取
    └─ 是（自绘控件）→
        ├─ OnHandleCreated → EnsureThemeSubscription()
        ├─ OnPaint → AppThemeManager.CurrentPalette 获取颜色
        ├─ ThemeChanged 回调 → Invalidate()
        ├─ Dispose → 取消事件订阅
        └─ 参见 2.3 完整模板
```

---

## 5. 注释规范

### 5.1 必须注释

| 目标 | 格式 |
|---|---|
| 所有公共类型 | `/// <summary>` 描述职责 |
| 所有公共属性 | `/// <summary>` 描述语义，`<param>` 描述构造参数 |
| 所有公共方法 | `/// <summary>` 描述行为，`<param>` 描述参数，`<returns>` 描述返回值 |
| 枚举成员 | `/// <summary>` 描述含义 |
| 受保护的 override 方法 | `/// <summary>` 描述重写意图和关键逻辑 |

### 5.2 推荐注释

| 目标 | 格式 |
|---|---|
| 私有字段 | `/// <summary>` 简述用途 |
| 私有方法 | `/// <summary>` 简述算法/逻辑 |
| 复杂逻辑块 | 行内 `//` 注释解释"为什么"而非"做什么" |
| 魔术数字 | `private const` 提取为命名常量 + `/// <summary>` |

### 5.3 禁止

- 无意义的重复注释（如 `/// 获取或设置 Text` 对应 `public string Text`）
- 注释中出现错别字或中英混杂的生硬表述
- 把注释当版本控制（如 `// 2024-01-01 by xxx 修改`）

---

## 6. 设计器兼容规范

### 6.1 必须遵守

- 自绘控件构造函数中**不要**访问 `AppThemeManager.CurrentPalette`（设计时 `CurrentTheme` 返回默认值即可）
- 不要在构造函数中调用 `AppThemeManager.RegisterRoot()` 或订阅 `ThemeChanged`
- 所有设计时跳过逻辑通过 `AppThemeManager.IsDesignTimeFor(this)` 判断
- `[ToolboxItem(true)]` 的控件才能出现在工具箱
- `[ToolboxItem(false)]` 仅用于基类（如 `AppThemedForm`）

### 6.2 推荐做法

- 公共属性加 `[DefaultValue]` 特性，让设计器知道默认值
- 自定义属性加 `[Browsable(true/false)]` 控制是否在属性面板显示
- 枚举属性加 `[DefaultValue]` 指向默认枚举值
- 控件默认尺寸通过 `DefaultSize` 属性提供

---

## 7. 构建验证

每次新增或修改组件后，**必须**执行构建验证：

```bash
rtk dotnet build .\{{PROJECT_NAME}}.sln
```

若构建失败，优先检查：
1. 命名空间是否正确
2. 是否缺少 `using` 指令
3. 是否引用了不存在的类型
4. 可空引用类型是否正确标注

---

## 8. 常见错误速查

| 错误现象 | 原因 | 修复 |
|---|---|---|
| 控件运行时颜色正确，设计器中报错 | 未做设计时保护 | 加 `IsDesignTimeFor` 检查 |
| 主题切换后控件颜色不更新 | 未订阅 `ThemeChanged` 或未 `Invalidate` | 自绘控件必须订阅事件 |
| 主题切换后标准控件不更新 | 窗体未继承 `AppThemedForm`，或未 `RegisterRoot` | 改为继承 `AppThemedForm` |
| 圆角出现黑边 | 直接在控件表面绘制圆角，透明像素被合成黑底 | 使用离屏位图 + canvas 底色绘制，参考 `AppButton.OnPaint` |
| DPI 缩放后控件尺寸异常 | 使用硬编码像素值 | 使用 `ScaleInt` / `ScaleFloat` 按 DPI 缩放 |
| 内存泄漏 | `ThemeChanged` 事件未取消订阅 | 在 `Dispose` 中 `-=` 取消订阅 |
| 弱引用列表无限增长 | 未定期 `PruneRoots_NoLock` | 已在 `RegisterRoot` 和 `ApplyToRegisteredRoots` 中自动清理 |

---

## 9. 一句话摘要

新增控件放 `{{PROJECT_NAME}}/Components/Composite/`，新增基础设施放 `{{PROJECT_NAME}}/Components/Atomic/`；新增组件后必须同步更新 [directory-tree.md](directory-tree.md)并保证目录树中的中文注释 、本文档 [1. 组件目录结构](#1-组件目录结构) 的目录树和 [SKILL.md](../skills/core/winforms-components/SKILL.md)；自绘控件必须订阅 `ThemeChanged` + `OnPaint` 读 `CurrentPalette` + `Dispose` 取消订阅；颜色只从 `AppThemePalette` 语义属性取，禁止硬编码；设计时必须跳过运行时逻辑；每次改动后构建验证。
