using System.Net;
using {{PROJECT_NAME}}.HttpHosting;

namespace {{PROJECT_NAME}}.Api.{{模块名}}.Hosting;

/// <summary>
/// 提供挂载到通用站点宿主中的 {{模块中文名}} 页面与同域接口。
/// </summary>
public sealed class {{模块名}}HttpModule : IHttpSiteModule
{
    /// <summary>
    /// 启动时快照配置。
    /// </summary>
    private readonly {{模块名}}HttpModuleOptions _startupOptions;

    /// <summary>
    /// 初始化 {{模块名}} 模块实例。
    /// </summary>
    public {{模块名}}HttpModule({{模块名}}HttpModuleOptions? options = null)
    {
        _startupOptions = options ?? new {{模块名}}HttpModuleOptions();
    }

    /// <inheritdoc />
    public string Name => "{{模块名}}";

    /// <inheritdoc />
    public string BasePath => HttpSitePathUtility.NormalizePath(_startupOptions.BasePath);

    /// <inheritdoc />
    public IEnumerable<HttpRouteDefinition> GetRoutes()
    {
        if (!_startupOptions.Enabled)
        {
            return Array.Empty<HttpRouteDefinition>();
        }

        return
        [
            // {{业务路由处理}}
            // 示例：QuicklyNavigation 式路由注册
            // CreateGetRoute($"{BasePath}/list", HandleGetListAsync,
            //     "返回当前列表",
            //     returns: "{{ModelName}}[]",
            //     returnsDescription: "条目数组"),
            // CreatePostRoute($"{BasePath}/addOrUpdate", HandleAddOrUpdateAsync,
            //     "新增或更新条目",
            //     [
            //         new() { Name = "Id", Source = "Body", Type = "string", Required = false, Description = "条目标识" },
            //         new() { Name = "Title", Source = "Body", Type = "string", Required = true, Description = "标题" },
            //     ],
            //     returns: "{ status: string }",
            //     returnsDescription: "固定返回 { status: \"ok\" }"),
        ];
    }

    /// <inheritdoc />
    public IEnumerable<HttpStaticAssetMount> GetStaticAssetMounts()
    {
        if (!_startupOptions.Enabled)
        {
            return Array.Empty<HttpStaticAssetMount>();
        }

        List<HttpStaticAssetMount> mounts =
        [
            new HttpStaticAssetMount
            {
                RequestPathPrefix = BasePath,
                RootDirectory = ResolveDashboardDirectory(),
                DefaultDocument = "index.html",
            }
        ];

        if (!string.IsNullOrWhiteSpace(_startupOptions.SharedStaticDirectory))
        {
            mounts.Add(
                new HttpStaticAssetMount
                {
                    RequestPathPrefix = "/static",
                    RootDirectory = _startupOptions.SharedStaticDirectory,
                    DefaultDocument = "index.html",
                });
        }

        return mounts;
    }

    /// <inheritdoc />
    public IEnumerable<HttpNavigationEntry> GetNavigationEntries()
    {
        if (!_startupOptions.Enabled || !_startupOptions.ShowInNavigation)
        {
            return Array.Empty<HttpNavigationEntry>();
        }

        return
        [
            new HttpNavigationEntry
            {
                Title = "{{模块中文名}}",
                Path = BasePath,
                Description = "{{模块中文描述}}",
                Group = "{{模块分组}}",
                Order = {{模块排序}},
                TagText = "{{模块标签}}",
            }
        ];
    }

    // {{业务路由处理器}}
    // 示例：
    // private async Task HandleGetListAsync(HttpRequestContext context, CancellationToken cancellationToken)
    // {
    //     await context.WriteJsonAsync(/* 数据 */, cancellationToken: cancellationToken);
    // }
    //
    // private async Task HandleAddOrUpdateAsync(HttpRequestContext context, CancellationToken cancellationToken)
    // {
    //     try
    //     {
    //         var item = await context.ReadJsonAsync<{{ModelName}}>(cancellationToken);
    //         // 业务处理
    //         await context.WriteJsonAsync(new { status = "ok" }, cancellationToken: cancellationToken);
    //     }
    //     catch (Exception exception)
    //     {
    //         await WriteFailureAsync(context, exception, cancellationToken);
    //     }
    // }

    /// <summary>
    /// 统一写出错误响应。
    /// </summary>
    private static async Task WriteFailureAsync(
        HttpRequestContext context,
        Exception exception,
        CancellationToken cancellationToken)
    {
        await context.WriteJsonAsync(
            new
            {
                status = "error",
                msg = exception.Message,
            },
            (int)HttpStatusCode.InternalServerError,
            cancellationToken);
    }

    /// <summary>
    /// 创建 GET 路由定义。
    /// </summary>
    private static HttpRouteDefinition CreateGetRoute(
        string path,
        Func<HttpRequestContext, CancellationToken, Task> handler,
        string description = "",
        IReadOnlyList<HttpRouteParameterInfo>? parameters = null,
        string returns = "",
        string returnsDescription = "",
        IReadOnlyList<HttpRouteReturnFieldInfo>? returnFields = null)
    {
        return new HttpRouteDefinition
        {
            Method = "GET",
            Path = path,
            Handler = handler,
            Description = description,
            Parameters = parameters ?? Array.Empty<HttpRouteParameterInfo>(),
            Returns = returns,
            ReturnsDescription = returnsDescription,
            ReturnFields = returnFields ?? Array.Empty<HttpRouteReturnFieldInfo>(),
        };
    }

    /// <summary>
    /// 创建 POST 路由定义。
    /// </summary>
    private static HttpRouteDefinition CreatePostRoute(
        string path,
        Func<HttpRequestContext, CancellationToken, Task> handler,
        string description = "",
        IReadOnlyList<HttpRouteParameterInfo>? parameters = null,
        string returns = "",
        string returnsDescription = "",
        IReadOnlyList<HttpRouteReturnFieldInfo>? returnFields = null)
    {
        return new HttpRouteDefinition
        {
            Method = "POST",
            Path = path,
            Handler = handler,
            Description = description,
            Parameters = parameters ?? Array.Empty<HttpRouteParameterInfo>(),
            Returns = returns,
            ReturnsDescription = returnsDescription,
            ReturnFields = returnFields ?? Array.Empty<HttpRouteReturnFieldInfo>(),
        };
    }

    /// <summary>
    /// 解析页面目录。
    /// </summary>
    private string ResolveDashboardDirectory()
    {
        if (!string.IsNullOrWhiteSpace(_startupOptions.DashboardDirectory))
        {
            return _startupOptions.DashboardDirectory;
        }

        return HttpSiteRuntimePathResolver.ResolveDefaultModuleHtmlDirectory(Name);
    }
}
