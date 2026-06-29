<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>{{模块中文名}}</title>
    <link rel="stylesheet" href="/static/css/base.css">
    <link rel="stylesheet" href="/static/css/shell.css">

    <script>
        (function () {
            var path = window.location.pathname || "/{{模块名kebab}}";
            if (path.endsWith("/index.html")) {
                path = path.substring(0, path.length - "/index.html".length);
            }
            if (!path.endsWith("/")) { path += "/"; }
            window.__{{模块名大写}}_BASE_PATH__ = path;
        })();
    </script>

    <script>
        (function () {
            var basePath = window.__{{模块名大写}}_BASE_PATH__;
            ["css/{{模块名kebab}}.css"].forEach(function (relativePath) {
                var link = document.createElement("link");
                link.rel = "stylesheet";
                link.href = basePath + relativePath;
                document.head.appendChild(link);
            });
        })();
    </script>
</head>
<body
    data-page-title="{{模块中文名}}"
    data-page-subtitle="{{模块中文描述}}"
    data-page-key="{{模块名kebab}}">
<div class="app-shell">
    <div data-common-header></div>

    <main class="app-main {{模块名kebab}}-page">
        <!-- 模块内容 -->
    </main>

    <div data-common-footer></div>
</div>

<!-- 如需元信息徽章: <template data-shell-meta>...</template> -->
<!-- 如需操作按钮: <template data-shell-actions>...</template> -->

<template data-shell-footer-extra>
    <span>{{模块中文名}} · {{模块中文描述}}</span>
</template>

<script src="/static/js/page-shell.js"></script>
<script>
    (function () {
        var path = window.__{{模块名大写}}_BASE_PATH__
            || (function () {
                var p = window.location.pathname || "/{{模块名kebab}}";
                if (p.endsWith("/index.html")) { p = p.substring(0, p.length - "/index.html".length); }
                if (!p.endsWith("/")) { p += "/"; }
                return p;
            })();
        var script = document.createElement("script");
        script.src = path + "js/script.js";
        document.body.appendChild(script);
    })();
</script>
</body>
</html>
