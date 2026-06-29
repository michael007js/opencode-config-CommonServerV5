namespace {{PROJECT_NAME}}.Api.{{模块名}}.Models;

/// <summary>
/// 表示 {{模块中文名}} 数据条目。
/// </summary>
public sealed record {{ModelName}}
{
    public string Id { get; init; } = string.Empty;
    public string Title { get; init; } = string.Empty;

    // {{模块特定字段}}
}
