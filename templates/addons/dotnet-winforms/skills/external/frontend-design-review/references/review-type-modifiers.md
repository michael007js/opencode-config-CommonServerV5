# Review Type Modifiers

Adjust focus based on review context:

## PR Review
- **Focus**: code implementation, theming component usage, `AppThemePalette` usage, accessibility in code
- **Check**: proper `AppThemedForm` inheritance, `AppThemePalette` semantic colors used, no hardcoded `Color.FromArgb(...)`
- **Verify**: Light + Dark themes both render correctly

## Creative Frontend Review
- **Focus**: aesthetic direction, typography hierarchy, visual distinctiveness, layout composition
- **Check**: clear intent, avoidance of generic AI patterns, cohesive execution via `AppThemePalette`
- **Verify**: implementation complexity matches the vision

## Design Review
- **Focus**: user flows, interaction patterns, visual hierarchy, navigation, theming alignment
- **Check**: task completion path, action hierarchy, progressive disclosure
- **Verify**: all components follow `AppThemedForm` + `AppThemePalette` patterns or have documented exceptions

## Accessibility Audit
- **Focus**: deep dive on the Quality Craft pillar
- **Check**: keyboard testing, high-contrast theme, focus indicators, `Tab` order, screen reader compatibility
- **Test with**: keyboard only, Dark + Light themes, 200% DPI scaling
- **Verify**: `AppThemePalette` contrast ratios meet accessibility requirements in both themes

## Theming Compliance Audit
- **Focus**: deep dive theming usage
- **Check**: all controls use `AppThemePalette` semantic colors, `AppThemedForm` inheritance, self-drawn controls subscribe `ThemeChanged`, Light + Dark both tested
- **Test**: switch theme at runtime and verify all controls repaint correctly
- **Verify**: no hardcoded colors, no `Form` inheritance, palette changes synchronized in both themes
- **Document**: any deviations with rationale and plan to align
