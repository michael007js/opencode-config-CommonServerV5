# Plan 创建提示词模板

> 用于指导 AI 创建开发 Plan。

---

## 快速提示词

### 场景 1：全新功能模块

```text
请为新功能「{{功能描述}}」创建开发 Plan：
- 功能类型：{{页面 / API / SDK / 配置 / 文档 / 其他}}
- 核心功能：{{列出主要功能点}}
- 相关代码：{{文件路径，如适用}}

请按照 Plan 模板格式输出。
```

### 场景 2：改造现有功能

```text
请为「{{现有功能}}」改造创建 Plan：
- 改造目标：{{改造说明}}
- 现有代码：{{文件路径}}
```

---

## AI 执行指南

### 1. 分析需求
- 理解功能目标
- 确认技术要点
- 确定需要的 Skills

### 2. 创建 Plan

**章节优先级：**
1. ✅ Summary（必填）
2. ✅ Key Changes（必填）
3. ✅ Supplementary Requirements
4. ✅ Phased Implementation（必填）
5. ✅ Test Plan（必填）
6. ✅ Assumptions（必填）

### 3. 验证 Plan
- 所有占位符已替换
- Task 依赖关系正确
- 验收检查点完整
- 相关 Skills 已列出

---

## 输出文件位置

```
plans/
├── plan-{功能名}-v{版本}.md     # Plan 文件
└── research/
    └── research-{功能名}.md     # 调研文档
```
