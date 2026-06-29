## K. 目录归属（放错 = 迁移 + 重构）

| # | 约束 | 违反后果 |
|---|------|---------|
| K1 | SDK 代码放 `Sdk/`，零 UI 依赖，可独立测试 | SDK 混入 UI 依赖 → 无法独立测试，需迁移 |
| K2 | 框架能力放 `Components/Atomic/`（Theming/DesignTime/AppImageCache） | 纯逻辑类型混入 Composite → 归属错误 |
| K3 | 自绘控件放 `Components/Composite/`（AppButton/AppImage/AppTabPane） | 控件散落在项目根目录 → 归属错误 |
| K4 | 命名空间 = 目录路径（`{{PROJECT_NAME}}.` + 目录路径斜杠换点） | 命名空间不匹配 → 构建失败 |
| K5 | 依赖方向不可逆：上层 → 下层；禁止下层引用上层 | 反向依赖 → 循环依赖，需提取公共层或用事件反转 |

## L. UI / 主题（硬编码 = 违反调色板规则）

| # | 约束 | 违反后果 |
|---|------|---------|
| L1 | 禁止 `Color.FromArgb(...)` / `Color.Xxx` 硬编码颜色 | 必须用 `AppThemePalette` 语义颜色 |
| L2 | 自绘控件走 `OnPaint` + 订阅 `ThemeChanged` | 走 ApplySingle BackColor/ForeColor → 主题切换失效 |
| L3 | 新窗体继承 `AppThemedForm`，不直接继承 `Form` | 直接继承 Form → 主题不生效，生命周期不安全 |
| L4 | 修改调色板必须同步 Light + Dark | 只改一个 → 另一主题下视觉破损 |
| L5 | 自绘控件圆角用离屏位图，Region 赋值前先 Dispose 旧值 | 直接 SetClip 产生 1px 黑边；不释放旧 Region → GDI 泄漏 |

## M. 代码规范扩展（违反 = 构建失败或设计器崩溃）

| # | 约束 | 违反后果 |
|---|------|---------|
| M1 | 手写逻辑放非 Designer partial 类，不写进 `*.Designer.cs` | Designer.cs 被污染 → 设计器重生成时丢失 |
| M2 | 非可视化数据模型用普通类 + public Dispose()，不继承 Component | 继承 Component → 设计器容器托管异常 |
| M3 | `switch` 新分支放 `default` 之前 | 放在 default 之后 → 永远不命中 |
| M4 | ScaleInt/ScaleFloat 加 DPI=0 兜底（`DeviceDpi > 0 ? DeviceDpi : 96f`） | 构造函数期间 DeviceDpi=0 → 返回 0，控件不可见 |
| M5 | 自检6项不通过不得跳过（目录/命名空间/依赖/主题/Designer/最小改动） | 跳过自检 → 约束违反 |

## N. 文档同步扩展（违反 = 文档与代码不一致）

| # | 约束 | 违反后果 |
|---|------|---------|
| N1 | 修改主题系统后更新 `theming.md` | 主题文档过期 → AI 违反调色板规则 |
| N2 | 修改组件规范后更新 `component-guide.md` | 组件文档过期 → AI 创建控件流程错误 |
| N3 | 不主动引入 WPF/MAUI/Avalonia/ASP.NET/第三方 UI 框架 | 引入 → 与项目定位冲突 |

## O. 测试规范（违反 = 测试失效或归属错误）

| # | 约束 | 违反后果 |
|---|------|---------|
| O1 | 测试文件放 `Tests/` 目录，由测试项目 `<Compile Include>` 引用 | 测试散落主项目根目录 → 归属错误 |
| O2 | 测试四重隔离：`[Collection]` 串行 + `ResetForTesting` + `Dispose` + Guid Key | 无隔离 → 测试状态残留，断言失败 |
| O3 | MySqlSdk 测试连接字符串用环境变量 `MYSQLSDK_TEST_CONNSTR`，禁止硬编码 | 硬编码连接字符串 → 不可移植 |
| O4 | 测试命名空间避免与类型同名（用 `AppImageTests` 后缀） | `Tests.AppImage` 与 `AppImage` 类冲突 |
