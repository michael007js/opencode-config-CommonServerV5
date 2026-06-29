---
name: rtk
description: "{{PROJECT_NAME}} 的 RTK 公共前置技能。所有代理协作时的默认命令入口。"
metadata:
  audience: maintainers
  project: "{{PROJECT_NAME}}"
---

# RTK 公共前置技能

> 适用范围：本文描述的是 **{{PROJECT_NAME}} 项目使用 RTK 的落地规则**，默认面向 AI 代理协作场景。

---

## 零、绝对禁止：`rtk proxy`

- **`rtk proxy` 在本项目中是禁止命令，不是兜底方案。**
- 任何代理都不得自行执行 `rtk proxy ...`。
- 当 RTK 原生命令无法表达当前任务时，必须先停止，向用户说明原因，等待确认后再决定下一步。

---

## 一、黄金法则

- **所有可执行命令默认先写 `rtk`。**
- 如果 RTK 有专用过滤器，就使用专用过滤器。
- 如果 RTK 没有专用过滤器，就使用 `rtk <command>` 形式交给 RTK 执行。

---

## 二、默认执行顺序

1. 先找是否存在 RTK 原生命令。
2. 如果已经写了 raw 命令但不确定是否支持，先试 `rtk rewrite <raw command>`。
3. 如果没有原生命令，尝试 `rtk <command>` 形式。
4. 如果任务目标必须保留完整原始输出，或 RTK 明确不支持，先停止并说明原因。

---

## 三、平台规则

### 3.1 Windows / PowerShell

- 优先"一行一条命令"
- **不要依赖 `&&`**，Windows PowerShell 5.1 不支持
- 手里已有 raw 命令但不确定能否转成 RTK 时，先试 `rtk rewrite <raw command>`

### 3.2 通用

- 常规文件读取优先 `rtk read <file>` 或 `rtk smart <file>`
- 文件发现优先 `rtk find ...`
- 内容搜索优先 `rtk grep <pattern> <path>`
- Git 命令优先 `rtk git ...`

---

## 四、好坏示例

```powershell
# 反例
git status
Get-Content .\Program.cs
Get-ChildItem -Recurse

# 正例
rtk git status
rtk read .\Program.cs
rtk find * .
```

---

## 五、需要停止说明的场景

- 需要完整原始错误、完整栈、完整日志
- RTK 当前无对应原生命令
- `rtk rewrite` 没有结果
- `rtk grep` 因环境缺少后端无法工作

---

## 六、最小执行版

- **默认先选 RTK 原生命令**
- Git 默认走 `rtk git ...`
- 首轮读长文件优先 `rtk smart`
- 文件发现优先 `rtk find`
- 搜索优先 `rtk grep`
- 不确定时先试 `rtk rewrite`
- 不使用 `rtk proxy`
- 在 Windows 上避免 `&&`

---

## 七、一句话总结

**先写 RTK 原生命令，少写 shell 包装，不使用 proxy，表达不了时先说明。**
