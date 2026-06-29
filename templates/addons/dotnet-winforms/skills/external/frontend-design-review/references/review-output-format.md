# Review Output Format

```md
## Frontend Design Review: [Component/Feature Name]

### Context
- **Purpose**: What problem does this solve? Who uses it?
- **Aesthetic Direction**: [If new design: describe the bold conceptual direction]
- **User Task**: What is the user trying to accomplish?

### Summary
[Pass/Needs Work/Blocked] - [One-line assessment]

### Theming Compliance (if applicable)
- [ ] New form inherits `AppThemedForm`
- [ ] Colors use `AppThemePalette` semantic colors (no hardcoded values)
- [ ] Self-drawn controls subscribe `ThemeChanged`
- [ ] Light + Dark themes both working
- [ ] Palette changes synchronized in both themes

### Aesthetic Quality (especially for new designs)
- [ ] Clear conceptual direction (not generic AI aesthetic)
- [ ] Distinctive typography hierarchy
- [ ] Cohesive visual design via `AppThemePalette`
- [ ] Spatial composition creates visual interest
- [ ] Implementation complexity matches vision

### Pillar Assessment

| Pillar | Status | Notes |
|--------|--------|-------|
| Frictionless | Pass / Needs attention / Blocking issue | Task completion efficient, primary action clear |
| Quality Craft | Pass / Needs attention / Blocking issue | Theming compliant, aesthetic distinctive, accessible, DPI-aware |
| Trustworthy | Pass / Needs attention / Blocking issue | AI disclaimers present, errors actionable |

### Design Critique
**Verdict:** [Pass / Needs work / Reach out for more support]

**Rationale:** [Brief explanation based on pillar assessment, theming compliance, and aesthetic direction]

### Issues

**Blocking (must fix before merge):**
1. [Pillar/Theming/Aesthetic] Issue description + recommendation

**Major (should fix):**
1. [Pillar/Theming/Aesthetic] Issue description + pattern suggestion

**Minor (consider for refinement):**
1. [Pillar/Theming/Aesthetic] Issue description + optional improvement

### Recommendations
- [Project component to use (AppButton, AppTabPane, AppThemedForm)]
- [AppThemePalette semantic color to use]
- [DPI scaling fix with ScaleInt/ScaleFloat guard]
- [Theme testing instructions]
```
