# Quick Checklist

Before approving any UI work:

## Theming Compliance
- [ ] New form inherits `AppThemedForm` (not `Form`)
- [ ] Colors use `AppThemePalette` semantic colors (no hardcoded `Color.FromArgb(...)` / `Color.Xxx`)
- [ ] Self-drawn controls subscribe `ThemeChanged` and repaint (not `ApplySingle BackColor/ForeColor`)
- [ ] Light + Dark themes both tested and working
- [ ] Palette changes synchronized in both `AppThemePalette` Light and Dark sections

## Aesthetic Quality
- [ ] Clear conceptual direction
- [ ] Distinctive typography hierarchy (size + weight)
- [ ] Cohesive visual design via `AppThemePalette` semantic colors
- [ ] Visual interest through layout composition
- [ ] Implementation complexity matches vision

## Frictionless
- [ ] Core task completable efficiently
- [ ] Single clear primary action per view

## Quality Craft
- [ ] Uses project components (`AppButton`, `AppTabPane`, `AppThemedForm`)
- [ ] Self-drawn controls follow `OnPaint` + `ThemeChanged` pattern
- [ ] DPI-aware: `ScaleInt`/`ScaleFloat` with `DeviceDpi > 0 ? DeviceDpi : 96f` guard
- [ ] Accessible: keyboard navigation, focus indicators
- [ ] Tested at 100%, 150%, 200% DPI scaling
- [ ] Tested in Light and Dark themes

## Trustworthy
- [ ] AI-generated content has disclaimer
- [ ] Error messages are actionable
- [ ] Persistence failure triggers UI rollback (not silent acceptance)
