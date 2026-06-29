# Pattern Examples

## Creative Frontend (New Interfaces)

### Good: Clear Aesthetic Direction
- Dashboard with industrial theme: monospace data display, `AppThemePalette.Surface` base, `AppThemePalette.Accent` highlights, `TableLayoutPanel` structured grid
- Settings panel with organic theme: rounded self-drawn controls (`AppButton`), earth-tone palette via `AppThemePalette` semantic colors, flowing `TableLayoutPanel` sections

### Bad: Generic AI Aesthetic
- Hardcoded `Color.White` / `Color.Black`, no theme support, centered content with no visual hierarchy

## Theming System Review (Existing Work)

### Good: Frictionless
- Single primary button, clear task completion path

### Good: Quality Craft
- Inherits `AppThemedForm`, uses `AppThemePalette` semantic colors, subscribes `ThemeChanged` in self-drawn controls, keyboard accessible, tested in Light + Dark themes

### Bad: Quality Craft
- Hardcoded `Color.FromArgb(...)`, inherits `Form` instead of `AppThemedForm`, poor contrast in Dark mode, `ScaleInt` without DPI=0 guard
