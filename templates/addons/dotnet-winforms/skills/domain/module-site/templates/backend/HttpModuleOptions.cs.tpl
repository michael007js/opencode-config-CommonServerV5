namespace {{PROJECT_NAME}}.Api.{{模块名}}.Hosting;

/// <summary>
/// 表示 {{模块中文名}} 网页模块的运行选项。
/// </summary>
public sealed class {{模块名}}HttpModuleOptions
{
    /// <summary>
    /// 获取或设置模块说明文本。
    /// </summary>
    public string Description { get; set; } = "{{模块中文描述}}";

    /// <summary>
    /// 获取或设置是否启用 {{模块名}} HttpHosting 模块。
    /// </summary>
    public bool Enabled { get; set; }

    /// <summary>
    /// 获取或设置是否在门户首页显示导航项。
    /// </summary>
    public bool ShowInNavigation { get; set; } = true;

    /// <summary>
    /// 获取或设置模块主入口路径。
    /// </summary>
    public string BasePath { get; set; } = "/{{模块名kebab}}";

    /// <summary>
    /// 获取或设置页面目录；为空时使用默认 <c>Site/{{模块名}}</c>。
    /// </summary>
    public string DashboardDirectory { get; set; } = string.Empty;

    /// <summary>
    /// 获取或设置附加共享静态资源目录。
    /// </summary>
    public string SharedStaticDirectory { get; set; } = string.Empty;

    // {{模块特定字段}}
    // 示例（文件扫描场景）：
    // /// <summary>
    // /// 获取或设置扫描源目录。
    // /// </summary>
    // public string SourceDirectory { get; set; } = string.Empty;
}
