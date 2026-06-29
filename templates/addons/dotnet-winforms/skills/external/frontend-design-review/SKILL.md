---
name: frontend-design-review
description: >
  Review and create distinctive, production-grade WinForms frontend interfaces with strong design quality and theming-system compliance.
  Covers PR reviews, design reviews, accessibility audits, theming checks, creative frontend design, component reviews,
  DPI/responsive checks, theme testing, and memorable UI work.
  Avoid for backend API reviews, database schema reviews, infrastructure or DevOps work, pure business logic without UI,
  or any non-frontend code.
version: "1.0.0"
updatedAt: "2026-06-01"
tags: [设计审查, 前端, WinForms, 主题, AppThemePalette, AppThemedForm, 自绘控件, DPI, 无障碍]
acknowledgments: |
  Design review principles and the quality-pillar framework were created by @Quirinevwm
  (https://github.com/Quirinevwm).
  Creative frontend guidance was inspired by Anthropic's frontend-design skill
  (https://github.com/anthropics/skills/tree/main/skills/frontend-design).
---

# Frontend Design Review（WinForms / {{PROJECT_NAME}}）

Use this skill to review UI implementations against theming standards and your design system, or to create distinctive,
production-grade WinForms frontend interfaces from scratch.

调用本技能时，必须同时加载 `rtk` 公共前置技能，不得跳过。

## Two Modes

### Mode 1: Design Review
Evaluate existing UI for theming compliance, the three pillars (Frictionless, Quality Craft, Trustworthy),
accessibility, and code quality.

### Mode 2: Creative Frontend Design
Create distinctive interfaces that avoid generic AI-slop aesthetics, have clear conceptual direction, and execute with precision.

---

## Creative Frontend Design

Before coding, commit to an aesthetic direction:
- Purpose: What problem does this solve? Who uses it?
- Tone: minimal, maximalist, retro-futuristic, organic, luxury, playful, editorial, brutalist, art deco, soft/pastel, industrial, etc.
- Constraints: WinForms framework, DPI awareness, theme system (AppThemePalette), accessibility requirements.
- Differentiation: what makes this distinctive and context-appropriate?

### Aesthetics Guidelines (WinForms Context)

- Typography: WinForms 字体选择受限于系统字体；优先使用 `Segoe UI`（Windows 默认），搭配 `Consolas` 等宽字体做数据展示。通过字号层级和字重（Regular/Bold）建立视觉层级。
- Color and theme: 必须使用 `AppThemePalette` 12 语义颜色，禁止硬编码 `Color.FromArgb(...)` / `Color.Xxx`。Light/Dark 双主题必须同步适配。
- Motion: WinForms 动效受限；优先用 `Opacity` 渐变、`Timer` 驱动的简单过渡，不做复杂 CSS 式动画。
- Spatial composition: 使用 `TableLayoutPanel`、`Dock`、`Anchor` 建立布局层级。自绘控件通过离屏位图和 `Region` 裁剪实现圆角等效果。
- Backgrounds: 通过 `AppThemePalette` 语义颜色实现主题感知背景；自绘控件可使用渐变画刷（`LinearGradientBrush`）增加视觉层次。

Avoid overused patterns, hardcoded colors, single-theme-only implementations, and cookie-cutter layouts without context-specific character.

Match implementation complexity to vision. Maximalist means elaborate OnPaint code. Minimalist means restraint and precision.

---

## Design Review

### Theming System Workflow

Before implementing:
1. Review the component in `Components/Composite/` or `Components/Atomic/Theming/` for API and usage.
2. Check `AppThemePalette` for available semantic colors.
3. Implement using `AppThemedForm` base class and `AppThemePalette` semantic colors.

During review:
1. Compare implementation to the design intent.
2. Verify `AppThemePalette` semantic colors are used instead of hardcoded `Color.FromArgb(...)` / `Color.Xxx`.
3. Check that Light/Dark themes are both implemented correctly.
4. Flag deviations and require review.

If the component does not exist:
1. Check whether an existing component can be adapted.
2. Create a new self-drawn component in `Components/Composite/`.
3. Document the exception and rationale in code.

### Review Process

1. Identify the user task.
2. Check the theming system for matching patterns.
3. Evaluate aesthetic direction.
4. Identify scope: component, feature, or flow.
5. Evaluate each pillar.
6. Prioritize issues.
7. Provide recommendations with examples.

### Core Principles

- Task completion: minimum clicks. Every screen should answer "What can I do?" and "What happens next?"
- Action hierarchy: 1-2 primary actions per view. Use progressive disclosure for secondary actions.
- Onboarding: explain features on introduction. Prefer smart defaults over configuration.
- Navigation: clear entry and exit points. Back and cancel should always be available.

---

## Quality Pillars

### 1. Frictionless Insight to Action

Evaluate whether the task can be completed in 3 interactions or fewer, and whether the primary action is obvious and singular.

Red flags: excessive clicks, multiple competing primary buttons, buried actions, dead ends.

### 2. Quality is Craft

Evaluate:
- Theming compliance: uses `AppThemePalette` semantic colors, inherits `AppThemedForm`, subscribes `ThemeChanged`
- Aesthetic direction: distinctive typography hierarchy, cohesive theme colors, intentional layout
- Accessibility: keyboard navigation, screen reader compatibility, high-contrast mode support
- DPI awareness: `ScaleInt`/`ScaleFloat` with DPI=0 guard, correct scaling at 100%/150%/200%

Red flags: hardcoded colors, `Form` instead of `AppThemedForm`, generic layouts, broken DPI scaling, missing focus indicators, only Light theme tested.

### 3. Trustworthy Building

Evaluate:
- AI transparency: disclaimer on AI-generated content
- Error transparency: actionable error messages with UI rollback on persistence failure

Red flags: missing AI disclaimers, opaque errors without guidance.

---

## Review Output Format

See [references/review-output-format.md](references/review-output-format.md) for the full review template.

## Review Type Modifiers

See [references/review-type-modifiers.md](references/review-type-modifiers.md) for context-specific review focus areas.

## Quick Checklist

See [references/quick-checklist.md](references/quick-checklist.md) for the pre-approval checklist.

## Pattern Examples

See [references/pattern-examples.md](references/pattern-examples.md) for good and bad examples.

---

## Acknowledgments

Creative frontend principles were inspired by [Anthropic's frontend-design skill](https://github.com/anthropics/skills/tree/main/skills/frontend-design).
Design review principles and the quality-pillar framework were created by [@Quirinevwm](https://github.com/Quirinevwm).
