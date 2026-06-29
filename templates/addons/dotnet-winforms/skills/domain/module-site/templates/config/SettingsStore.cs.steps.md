# SettingsStore.cs 可选保存方法

## 适用条件

仅当模块需要在运行时将配置变更持久化到 settings.json 时，才新增此方法。

典型场景：
- CRUD 型模块的 DataStore 写入后需持久化
- 模块有用户可修改的配置项需即时保存

如果模块是纯启动快照（运行时不可变），则**不需要**添加保存方法。

---

## 步骤：添加 Save 方法

**文件：** {{PROJECT_NAME}}/Configuration/CommonServerSettingsStore.cs

**位置：** SaveQuicklyNavigationSettings 方法之后

**操作：** 添加两个重载方法

```csharp
public static void Save{{模块名}}Settings({{模块名}}HttpModuleOptions {{模块名小驼峰}}Settings)
{
    Save{{模块名}}Settings({{模块名小驼峰}}Settings, SettingsFilePath);
}

public static void Save{{模块名}}Settings(
    {{模块名}}HttpModuleOptions {{模块名小驼峰}}Settings,
    string settingsFilePath)
{
    ArgumentNullException.ThrowIfNull({{模块名小驼峰}}Settings);
    ArgumentException.ThrowIfNullOrWhiteSpace(settingsFilePath);

    var rootSettings = Load(settingsFilePath);
    rootSettings.{{模块名}} = {{模块名小驼峰}}Settings;
    Save(rootSettings, settingsFilePath);
}
```

**定位锚点：** 在 SaveQuicklyNavigationSettings 方法之后、CreateJsonOptions 方法之前添加。

---

## 注意事项

- 保存方法遵循 Load → 修改 → Save 模式，保证不丢失其他配置项
- 如需在保存前做数据规范化（如 QuicklyNavigationWebsiteNormalizer），在 rootSettings.{{模块名}} = ... 赋值前调用



