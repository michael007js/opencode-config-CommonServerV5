using System.Text.Json;
using {{PROJECT_NAME}}.Configuration;

namespace {{PROJECT_NAME}}.Api.{{模块名}}.Hosting;

/// <summary>
/// 负责从本地配置与环境变量读取 {{模块中文名}} 运行时配置。
/// </summary>
public static class {{模块名}}RuntimeSettingsLoader
{
    /// <summary>
    /// 读取 {{模块中文名}} 运行时配置。
    /// </summary>
    public static {{模块名}}RuntimeSettingsBundle Load(string? settingsFilePath = null)
    {
        var resolvedSettingsFilePath = string.IsNullOrWhiteSpace(settingsFilePath)
            ? CommonServerSettingsStore.EnsureSettingsFile()
            : settingsFilePath;
        var rootSettings = LoadLocalSettings(resolvedSettingsFilePath);
        var sourceSettings = rootSettings.{{模块名}} ?? new {{模块名}}HttpModuleOptions();

        var normalizedSettings = new {{模块名}}HttpModuleOptions
        {
            Description = ReadString(
                "{{PROJECT_NAME}}_{{模块名大写}}_DESCRIPTION",
                sourceSettings.Description),
            Enabled = ReadBoolean(
                "{{PROJECT_NAME}}_{{模块名大写}}_ENABLED",
                sourceSettings.Enabled),
            ShowInNavigation = ReadBoolean(
                "{{PROJECT_NAME}}_{{模块名大写}}_SHOWINNAVIGATION",
                sourceSettings.ShowInNavigation),
            BasePath = ReadString(
                "{{PROJECT_NAME}}_{{模块名大写}}_BASEPATH",
                sourceSettings.BasePath),
            DashboardDirectory = ReadString(
                "{{PROJECT_NAME}}_{{模块名大写}}_DASHBOARDDIRECTORY",
                sourceSettings.DashboardDirectory),
            SharedStaticDirectory = ReadString(
                "{{PROJECT_NAME}}_{{模块名大写}}_SHAREDSTATICDIRECTORY",
                sourceSettings.SharedStaticDirectory),
            // {{模块特定字段 ReadString/ReadBoolean 调用}}
        };

        return new {{模块名}}RuntimeSettingsBundle
        {
            HttpModule = normalizedSettings,
        };
    }

    /// <summary>
    /// 判断 {{模块中文名}} HttpHosting 模块是否满足挂载条件。
    /// </summary>
    public static bool IsHttpModuleUsable({{模块名}}RuntimeSettingsBundle settings)
    {
        ArgumentNullException.ThrowIfNull(settings);
        return settings.HttpModule.Enabled;
        // 如模块有必填配置字段（如 SourceDirectory），需追加：
        // && !string.IsNullOrWhiteSpace(settings.HttpModule.SourceDirectory);
    }

    private static LocalSettingsRoot LoadLocalSettings(string settingsFilePath)
    {
        if (!File.Exists(settingsFilePath))
        {
            return new LocalSettingsRoot();
        }

        try
        {
            var json = File.ReadAllText(settingsFilePath);
            return JsonSerializer.Deserialize<LocalSettingsRoot>(
                       json,
                       new JsonSerializerOptions
                       {
                           PropertyNameCaseInsensitive = true,
                       }) ??
                   new LocalSettingsRoot();
        }
        catch
        {
            return new LocalSettingsRoot();
        }
    }

    private static string ReadString(string variableName, string fallback)
    {
        var rawValue = Environment.GetEnvironmentVariable(variableName);
        return string.IsNullOrWhiteSpace(rawValue) ? fallback : rawValue.Trim();
    }

    private static bool ReadBoolean(string variableName, bool fallback)
    {
        var rawValue = Environment.GetEnvironmentVariable(variableName);
        return bool.TryParse(rawValue, out var parsedValue) ? parsedValue : fallback;
    }

    // 可选：仅当模块有整数配置项时添加
    // private static int ReadInt32(string variableName, int fallback)
    // {
    //     var rawValue = Environment.GetEnvironmentVariable(variableName);
    //     return int.TryParse(rawValue, out var parsedValue) ? parsedValue : fallback;
    // }

    private sealed class LocalSettingsRoot
    {
        public {{模块名}}HttpModuleOptions? {{模块名}} { get; init; } = new();
    }
}

/// <summary>
/// 表示 {{模块中文名}} 运行时配置包。
/// </summary>
public sealed class {{模块名}}RuntimeSettingsBundle
{
    /// <summary>
    /// 获取 {{模块中文名}} 网页模块配置。
    /// </summary>
    public {{模块名}}HttpModuleOptions HttpModule { get; init; } = new();
}
