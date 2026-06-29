# SettingsFile.cs 注册步骤

## 前置条件

已完成后端三件套代码文件的创建（HttpModule / HttpModuleOptions / RuntimeSettingsLoader）。

---

## 步骤 1：添加 using 声明

**文件：** {{PROJECT_NAME}}/Configuration/CommonServerSettingsFile.cs

**位置：** 顶部 using 区

**操作：** 新增一行

```csharp
using {{PROJECT_NAME}}.Api.{{模块名}}.Hosting;
```

**定位锚点：** 按字母序插入到 `using {{PROJECT_NAME}}.Api.*` 区域。当前末行为 `using {{PROJECT_NAME}}.Api.QuicklyNavigation.Hosting;`，若新模块名字母序在 Iptv 与 QuicklyNavigation 之间，应插入在 `using {{PROJECT_NAME}}.Api.Iptv.Models;` 之后。

---

## 步骤 2：新增 SettingsFile 属性

**文件：** {{PROJECT_NAME}}/Configuration/CommonServerSettingsFile.cs

**位置：** CommonServerSettingsFile 类内部

**操作：** 新增属性

```csharp
public {{模块名}}HttpModuleOptions {{模块名}} { get; set; } = new();
```

**定位锚点：** 在 public IptvHttpModuleOptions Iptv { get; set; } 属性之后、public ApiDocsHttpModuleOptions ApiDocsHttpModule { get; set; } 属性之前添加。

---

## 步骤 3：SetKnownSettings 新增行

**文件：** {{PROJECT_NAME}}/Configuration/CommonServerSettingsStore.cs

**位置：** SetKnownSettings() 方法内部

**操作：** 新增一行

```csharp
rootNode["{{模块名}}"] = ToNode(settings.{{模块名}});
```

**定位锚点：** 在 
rootNode["Iptv"] = ToNode(settings.Iptv); 之后添加。

---

## 步骤 4：NormalizeSettings 新增行

**文件：** {{PROJECT_NAME}}/Configuration/CommonServerSettingsStore.cs

**位置：** NormalizeSettings() 方法内部

**操作：** 新增一行

```csharp
settings.{{模块名}} ??= new();
```

**定位锚点：** 在 settings.Iptv ??= new(); 之后添加。如模块有子集合需额外初始化（如 Providers），在 ??= new() 之后追加。

---

## 步骤 5：settings.json 添加默认配置块

**文件：** C:\CommonServerConfig\{{PROJECT_NAME}}.settings.json

**位置：** JSON 根对象内

**操作：** 添加以下配置块（确保上一行末尾有逗号）

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

**定位锚点：** 在 "Iptv": { ... } 块之后添加。

---

## 四处同步约束

以下四处必须始终保持同步，任一处遗漏将导致配置不可用：

1. SettingsFile 属性行（步骤 2）
2. SetKnownSettings 行（步骤 3）
3. NormalizeSettings 行（步骤 4）
4. settings.json 默认配置块（步骤 5）


