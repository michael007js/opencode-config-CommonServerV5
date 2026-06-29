# module-site Skill

## §1 概述与触发条件

本 Skill 用于按统一模式快速产出新的常规模块 site（后端 HttpModule + 前端 Shell 页面 + 配置注册 + Program.SiteHost 接入）。

### 触发条件

- 用户要求"新建模块""新增站点模块""添加一个 xxx 模块"
- 需要创建新的 Api/{{模块名}}/ + Site/{{模块名}}/ 目录

### 适用范围

- 常规模块：HttpModule 构造函数仅注入 Options 或 0-1 个辅助依赖
- 极简型（ApiDocs）：仅三件套
- 标准型（AlbumPreview/FileOnlinePlayer）：三件套 + LibraryScanner 或 Models
- CRUD 型（QuicklyNavigation）：三件套 + DataStore + Normalizer（Phase 2 暂缓）

### 不适用场景

- 复杂型模块：HttpModule 构造函数需注入 >1 个非 Options 依赖（如 KuGouMusic）
- 独立 ApiHostRuntime 模式（如 KuGouMusic 的 ApiHost）
- SmartTask 等有独立 ConfigurationLoader 的特殊模块

---

## §2 占位符字典

| 占位符 | 含义 | 示例 |
|--------|------|------|
| `{{{{模块名}}}}` | 模块目录名（PascalCase） | QuicklyNavigation / FileOnlinePlayer / M3U8StreamGetter |
| `{{{{模块名kebab}}}}` | 模块 URL 路径名（kebab-case） | quickly-navigation / file-online-player / m3u8-stream-getter |
| `{{{{模块名小驼峰}}}}` | 变量名（camelCase） | quicklyNavigation / fileOnlinePlayer / m3u8StreamGetter |
| `{{{{模块名大写}}}}` | 环境变量前缀（全大写，去非字母数字字符） | QUICKLYNAVIGATION / FILEONLINEPLAYER / M3U8STREAMGETTER |
| `{{{{模块中文名}}}}` | 模块中文显示名 | 快捷导航 / 文件在线播放 / M3U8流获取 |
| `{{{{模块中文描述}}}}` | 模块中文描述 | 常用网址导航与拖拽排序工作台 |
| `{{{{模块分组}}}}` | 门户导航分组 | 效率工具 / 媒体 / 监控 |
| `{{{{模块排序}}}}` | 门户导航排序值 | 130 |
| `{{{{模块标签}}}}` | 门户导航标签文本 | 快捷 / 媒体 / Beta |
| `{{{{ModelName}}}}` | 数据模型类名（PascalCase） | QuicklyNavigationWebsiteItem |

**{{模块名大写}} 转换规则：** PascalCase 模块名去掉非字母数字字符后全大写。例如 `M3U8StreamGetter` → `M3U8STREAMGETTER`，`QuicklyNavigation` → `QUICKLYNAVIGATION`。

**命名转换速查：**

| PascalCase | kebab-case | camelCase | UPPER |
|-----------|-----------|----------|-------|
| QuicklyNavigation | quickly-navigation | quicklyNavigation | QUICKLYNAVIGATION |
| FileOnlinePlayer | file-online-player | fileOnlinePlayer | FILEONLINEPLAYER |
| M3U8StreamGetter | m3u8-stream-getter | m3u8StreamGetter | M3U8STREAMGETTER |
| AlbumPreview | album-preview | albumPreview | ALBUMPREVIEW |

---

## §3 必选三件套代码模板

### 3.1 HttpModule.cs

使用模板文件：[templates/backend/HttpModule.cs.tpl](templates/backend/HttpModule.cs.tpl)

**骨架要点：**

- 实现 `IHttpSiteModule` 接口，提供 Name / BasePath / GetRoutes() / GetStaticAssetMounts() / GetNavigationEntries()
- 构造函数：`public {{模块名}}HttpModule({{模块名}}HttpModuleOptions? options = null)` → `_startupOptions = options ?? new()`
- BasePath 必须用 `HttpSitePathUtility.NormalizePath()` 包裹
- Name 属性值 = 类名去掉 `HttpModule` 后缀，必须与 `Site/` 下的目录名完全一致
- 三种方法守卫模式：
  - `GetRoutes()` / `GetStaticAssetMounts()`：`if (!Enabled) → Array.Empty()`
  - `GetNavigationEntries()`：`if (!Enabled || !ShowInNavigation) → Array.Empty()`（双重守卫）
- `GetStaticAssetMounts()` 注册规则：
  - BasePath → `Site/{{模块名}}` — 始终注册，DefaultDocument = "index.html"
  - `/static` → SharedStaticDirectory — 仅当非空时条件注册
- 私有辅助方法：
  - `CreateGetRoute` / `CreatePostRoute`（private static，极简型无路由可省略）
  - `ResolveDashboardDirectory`（先检查 DashboardDirectory 非空，否则 fallback 到 `HttpSiteRuntimePathResolver.ResolveDefaultModuleHtmlDirectory(Name)`）
- 业务路由处理标记为 `{{业务路由处理}}` 占位
- 路由元数据 Description / Returns 不可为空（ApiDocs 自动收录）
- 导航项：`GetNavigationEntries()` 返回恰好 1 个导航项

### 3.2 HttpModuleOptions.cs

使用模板文件：[templates/backend/HttpModuleOptions.cs.tpl](templates/backend/HttpModuleOptions.cs.tpl)

6 个通用字段 + `{{模块特定字段}}` 占位：

| 字段 | 类型 | 推荐默认值 | 说明 |
|------|------|-----------|------|
| Description | string | `"{{模块功能一句话中文描述}}"` | 模块描述（可选） |
| Enabled | bool | false | 模块启用开关 |
| ShowInNavigation | bool | true | 是否显示在门户导航页 |
| BasePath | string | `"/{{模块名kebab}}"` | URL 路径前缀 |
| DashboardDirectory | string | "" | 仪表盘目录 |
| SharedStaticDirectory | string | "" | 共享静态资源目录 |

- 属性默认 `{ get; set; }`，纯启动快照模块可改为 `{ get; init; }`
- 在 SettingsFile 中属性名 = `{{模块名}}`（类型为 `{{模块名}}HttpModuleOptions`）

### 3.3 RuntimeSettingsLoader.cs

使用模板文件：[templates/backend/RuntimeSettingsLoader.cs.tpl](templates/backend/RuntimeSettingsLoader.cs.tpl)

- 默认形态：单 Bundle（`RuntimeSettingsBundle` 只含一个 `HttpModule` 属性）
- `Load(string? settingsFilePath = null)` → `RuntimeSettingsBundle`
- `IsHttpModuleUsable(RuntimeSettingsBundle bundle)` → `bool`（默认 `return bundle.HttpModule.Enabled;`）
- `ReadString` / `ReadBoolean` 辅助方法默认包含；`ReadInt32` 仅当模块有整数配置项时添加
- ReadString 统一用非空 `string fallback`
- `LocalSettingsRoot` 私有类：直接用 `{{模块名}}HttpModuleOptions` 类型 + `= new()` 默认值
- 环境变量前缀：`{{PROJECT_NAME}}_{{模块名大写}}_`

### 3.4 script.js 模板（内联）

前端 JS 文件固定放 `Site/{{模块名}}/js/script.js`（与 `index.html.tpl` 中 `script.src = path + "js/script.js"` 路径对应）。目录不存在时需创建。

默认使用全局变量模式（变体A）：

```javascript
(function () {
    var basePath = window.__{{模块名大写}}_BASE_PATH__
        || (function () {
            var p = window.location.pathname || "/{{模块名kebab}}";
            if (p.endsWith("/index.html")) { p = p.substring(0, p.length - "/index.html".length); }
            if (!p.endsWith("/")) { p += "/"; }
            return p;
        })();
    var API_BASE = basePath.replace(/\/$/, "");
    // {{业务逻辑}}
})();
```

**其他 BasePath 推导变体：**

- **变体B（pathname 自推算）**：从 `location.pathname` 推导，不依赖全局变量
- **变体C（硬编码路径）**：`var API_BASE = "/{{模块名kebab}}"`，适用于路径固定不变的模块

### 3.5 module.css 模板（内联）

模块 CSS 统一放 `Site/{{模块名}}/css/{{模块名kebab}}.css`：

```css
.{{模块名kebab}}-page {
    padding: 0;
}
```

新模块 CSS 只扩展，`Resources/static/css/` 仅存放全局共享样式（base.css / shell.css），新模块不得新增文件到此目录。

**创建步骤：** 新建模块时必须创建 `Site/{{模块名}}/css/` 目录及 `Site/{{模块名}}/css/{{模块名kebab}}.css` 文件（与 `index.html.tpl` 中动态加载路径对应）。目录不存在时需手动创建。

### 3.6 前端 Shell 公共依赖

所有模块前端页面依赖以下共享资源（`Resources/static/` 目录），新模块只引用不新增：

| 资源 | 路径 | 说明 |
|------|------|------|
| base.css | `/static/css/base.css` | CSS 变量声明、主题色、字体、基础重置 |
| shell.css | `/static/css/shell.css` | Shell 布局（header/footer/main 间距、响应式） |
| page-shell.js | `/static/js/page-shell.js` | 公共 Shell 渲染（header/footer 插入、滚动状态、主题切换） |
| header.html | `/static/fragments/header.html` | Shell 头部模板（由 page-shell.js 加载） |
| footer.html | `/static/fragments/footer.html` | Shell 页脚模板（由 page-shell.js 加载） |

---

## §4 可选扩展清单

### 4.1 Models（标准型：数据模型场景）

使用模板文件：[templates/backend/Models.cs.tpl](templates/backend/Models.cs.tpl)

- 推荐使用 `record` 类型，只有需要可变状态时才用 class
- 复杂 DTO 放 `Api/{{模块名}}/Models/` 目录
- 简单 DTO 可内联在 HttpModule 文件底部（仅适用于极简 CRUD 场景）

### 4.2 LibraryScanner（标准型：文件扫描场景）

- 参考现有模块：AlbumPreviewLibraryScanner / FileOnlinePlayerLibraryScanner
- 放 `Api/{{模块名}}/Hosting/` 目录
- Options 中通常需要 `SourceDirectory` 字段
- IsHttpModuleUsable 需追加非空检查：`!string.IsNullOrWhiteSpace(settings.HttpModule.SourceDirectory)`

### 4.3 DataStore（CRUD 型 / Phase 2 暂缓）

- 模式要点：`lock(SyncRoot)` + 快照释放锁；每次 CRUD 操作重新 `Load()`；写入前调用模块专属 Normalizer
- **风险标注：** "先写再 load"两步操作存在数据不一致风险，load 失败需回滚写入
- 暂不提供 .tpl 模板文件，待 Phase 2 实施

### 4.4 内联 DTO 规则

- 简单请求/响应 DTO（<=2 属性）可内联在 HttpModule 文件底部
- 内联 DTO 使用 `internal sealed` 修饰
- 复杂 DTO（>2 属性或被多处引用）应放 Models/ 目录

---

## §5 配置注册步骤

### 5.1 SettingsFile.cs 五步修改

详细步骤见：[templates/config/SettingsFile.cs.steps.md](templates/config/SettingsFile.cs.steps.md)

**五步摘要：**

1. `CommonServerSettingsFile.cs` 顶部 using 区新增：`using {{PROJECT_NAME}}.Api.{{模块名}}.Hosting;`
2. `CommonServerSettingsFile.cs` 新增属性：`public {{模块名}}HttpModuleOptions {{模块名}} { get; set; } = new();`
3. `CommonServerSettingsStore.cs` 的 `SetKnownSettings()` 中新增：`rootNode["{{模块名}}"] = ToNode(settings.{{模块名}});`
4. `CommonServerSettingsStore.cs` 的 `NormalizeSettings()` 中新增：`settings.{{模块名}} ??= new();`
5. `C:\CommonServerConfig\{{PROJECT_NAME}}.settings.json` 中添加默认配置块

**四处同步约束：** SettingsFile 属性行 + SetKnownSettings 行 + NormalizeSettings 行 + settings.json 默认配置块必须始终保持同步。

**注意：** ApiDocs 虽在 SettingsFile 中有属性行（`ApiDocsHttpModule`）和 NormalizeSettings 行，但其 Options 默认值已足够（Enabled=false），无需在 SetKnownSettings 中写回，也无需 settings.json 默认配置块。新模块不属于此例外，必须完成四步。

### 5.2 SettingsStore 可选保存方法

详细步骤见：[templates/config/SettingsStore.cs.steps.md](templates/config/SettingsStore.cs.steps.md)

仅当模块需要在运行时将配置变更持久化到 settings.json 时，才添加 `Save{{模块名}}Settings()` 方法（包括但不限于 DataStore 场景）。

### 5.3 settings.json 默认配置块

```json
"{{模块名}}": {
    "Description": "{{模块中文描述}}",
    "Enabled": true,
    "ShowInNavigation": true,
    "BasePath": "/{{模块名kebab}}",
    "DashboardDirectory": "",
    "SharedStaticDirectory": ""
}
```

**注意：** settings.json 中 `Enabled: true` 确保首次部署时模块可启动；Options 类默认 `false` 是代码级安全兜底，仅在 settings.json 缺少配置块时生效。二者不矛盾。

---

## §6 Program.SiteHost 接入步骤

详细步骤见：[templates/host/ProgramSiteHost.cs.steps.md](templates/host/ProgramSiteHost.cs.steps.md)

### 6.1 三段式集群插入

新模块代码必须按三段式集群模式插入，保持与现有模块一致的代码结构：

**段1 — RSL.Load 集群**（在现有 RSL.Load 调用之后、canStart 变量集群之前）：

```csharp
var {{模块名小驼峰}}Settings = {{模块名}}RuntimeSettingsLoader.Load();
```

**段2 — canStart 布尔变量集群**（在现有 canStart 变量之后、if(modules.Add) 集群之前）：

```csharp
var canStart{{模块名}}HttpModule = canStartHttpSiteHost &&
                                   {{模块名}}RuntimeSettingsLoader.IsHttpModuleUsable({{模块名小驼峰}}Settings);
```

**段3 — modules.Add 集群**（在现有 modules.Add 调用之后、KuGouMusic ApiHost 判断之前）：

```csharp
if (canStart{{模块名}}HttpModule)
{
    modules.Add(new {{模块名}}HttpModule({{模块名小驼峰}}Settings.HttpModule));
}
```

### 6.2 顶部 using 声明

在 `Program.SiteHost.cs` 顶部 using 区新增：

```csharp
using {{PROJECT_NAME}}.Api.{{模块名}}.Hosting;
```

### 6.3 插入位置锚点

- RSL.Load 集群：在 `M3U8StreamGetterRuntimeSettingsLoader.Load()` 之后
- canStart 变量集群：在 `canStartM3U8StreamGetterHttpModule` 之后
- modules.Add 集群：在 `modules.Add(new M3U8StreamGetterHttpModule(...))` 之后
- **ApiDocs 必须最后加载**，新模块绝不能插入在 ApiDocs 之后

### 6.4 canStartHttpSiteHost 门控

所有 `canStart{{模块名}}HttpModule` 变量必须包含 `canStartHttpSiteHost &&` 前缀门控。

---

## §7 新模块 vs 旧模块维护规则

- 模板定义的是**新模块规范**（如 `{{模块名}}HttpModuleOptions` 命名、SettingsFile 属性名 = `{{模块名}}`）
- **现有模块保持不变**，修改时沿用该模块的现有命名，不强制统一到新规范
- 新模块不再使用旧模块的不一致命名（如 `CommonServerXxxSettings` 而非 `XxxHttpModuleOptions`）
- 混合场景：同一 PR 中既有旧模块修改又有新模块新增时，旧模块用旧命名，新模块用新命名

**旧模块命名对照表：**

| 旧模块 | SettingsFile 属性类型（旧命名） | 新模板属性类型 | 说明 |
|--------|-------------------------------|---------------|------|
| FileOnlinePlayer | `CommonServerFileOnlinePlayerSettings` | `{{模块名}}HttpModuleOptions` | 旧类型含 SourceDirectory 等业务字段 |
| AlbumPreview | `CommonServerAlbumPreviewSettings` | `{{模块名}}HttpModuleOptions` | 旧类型含 SourceDirectory |
| KuGouMusicHttpModule | `CommonServerKuGouMusicHttpModuleSettings` | `{{模块名}}HttpModuleOptions` | 旧类型含 BootstrapCookie |
| SmartTaskHttpModule | `CommonServerSmartTaskHttpModuleSettings` | `{{模块名}}HttpModuleOptions` | 旧类型含调度器字段 |
| Iptv | `IptvHttpModuleOptions` | `{{模块名}}HttpModuleOptions` | 已与新规范一致 |
| QuicklyNavigation | `QuicklyNavigationHttpModuleOptions` | `{{模块名}}HttpModuleOptions` | 已与新规范一致 |
| ApiDocs | `ApiDocsHttpModuleOptions` | `{{模块名}}HttpModuleOptions` | 已与新规范一致 |
- SmartTask 和 KuGouMusic 属于特殊模块，有独立 ConfigurationLoader 或 ApiHostRuntime，不在本 Skill 覆盖范围
- M3U8StreamGetter 未在 CommonServerSettingsFile.cs 中注册属性，属于例外；**新模块必须在 SettingsFile 中注册**

---

## §8 验证清单

### 8.1 Skill 交付时自动验证（静态检查）

| # | 检查项 | 验证方式 |
|---|--------|---------|
| 1 | 所有模板文件存在 | 目录检查 |
| 2 | 模板占位符与 §2 字典一致 | grep 占位符名称 |
| 3 | SKILL.md 引用所有 .tpl 文件路径 | 路径匹配 |
| 4 | 目录结构完整 | tree 命令 |

### 8.2 Skill 使用时由执行 Agent 验证

| # | 检查项 | 验证方式 |
|---|--------|---------|
| 1 | 代码可编译 | `rtk dotnet build .\{{PROJECT_NAME}}.sln` |
| 2 | csproj 包含性 | `rtk dotnet publish -c Release -o ./publish-test` 后检查 Site/ 文件是否在输出中 |
| 3 | SettingsFile 四处同步 | 属性行 + SetKnownSettings 行 + NormalizeSettings 行 + settings.json 配置块 |
| 4 | Program.SiteHost 三段式完整 | RSL.Load + canStart 变量 + modules.Add 三行均存在 |
| 5 | ApiDocs 自动收录 | 每个路由的 Description / Returns 不可为空 |
| 6 | 前端 Shell 骨架完整 | data-common-header / data-common-footer / data-page-title / data-page-key 存在 |

### 8.3 目录结构

```
.ai/skills/domain/module-site/
├── SKILL.md
└── templates/
    ├── backend/
    │   ├── HttpModule.cs.tpl
    │   ├── HttpModuleOptions.cs.tpl
    │   ├── RuntimeSettingsLoader.cs.tpl
    │   └── Models.cs.tpl          # 可选
    ├── frontend/
    │   └── index.html.tpl
    ├── config/
    │   ├── SettingsFile.cs.steps.md
    │   └── SettingsStore.cs.steps.md
    └── host/
        └── ProgramSiteHost.cs.steps.md
```




