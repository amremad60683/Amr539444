# Masrofy (مصروفي)

Flutter app (iOS first, Android too) that keeps a person's daily spending between a
target and a limit. Arabic (RTL, masculine/feminine wording) and English. All data stays
on the phone (`shared_preferences`); no backend.

## Commands

```bash
flutter pub get
flutter analyze                     # must be clean
flutter test test                   # logic + widget tests
flutter test tool/screenshots_test.dart --update-goldens   # re-render docs/screenshots
flutter build web --release --no-web-resources-cdn          # browser build for Playwright checks
bash tool/install_claude_skills.sh  # installs the design skills below into .claude/skills
```

iOS builds run on Codemagic (`codemagic.yaml`) or GitHub Actions and are sideloaded.

## Layout

- `lib/services/budget_engine.dart` — daily rules (pure, tested): overspending carries to
  next days; allowance never below the target; outing days have their own budget.
- `lib/services/month_plan.dart` — cycle payday→payday (or calendar month), end-of-cycle
  projection, safe daily spend above the safety balance.
- `lib/state/app_state.dart` — all state, auto installments and salary, reminders.
- `lib/l10n/strings.dart` — every user-facing string, `_en`, `_ar`, `_arF` (feminine
  overrides for any Arabic string that addresses the user).
- `lib/theme.dart` — design tokens (`context.tk`), type scale (`AppType`).
- `lib/widgets/common.dart` — Panel, Group/Line (grouped lists), Figure/FigureStrip,
  Reveal/Bone (first-load skeleton), sheets and inputs.

## Design rules (from the impeccable, taste-skill and web-interface-guidelines skills)

Mode: **Operate** app screen, native iOS conventions.

- True neutral dark by default (`#0A0A0B` ground, `#141416` surfaces, 1px `#26262A`
  lines); light theme mirrors it. No navy/slate, no gradients, glass or glows.
- Colour lives on data: green = money left / on track, amber = past target, red = over
  the limit. Chrome is neutral. Primary action is inverted ink, never a brand fill.
- The screen's answer ("left for today") is the biggest figure (40px); other figures 22px.
  No KPI tiles with icons in circles, no sparklines, no progress rings.
- One authored motion: on launch the splash mark settles, the home layout shows with flat
  bones (no shimmer) at final sizes, then values land and the today meter fills. Respect
  Reduce Motion (`MediaQuery.disableAnimations`). Nothing shifts when values land.
- No emoji in UI copy. CupertinoIcons only, 16–20px, grey unless they carry status.
- Every string goes through `S.t()`; add the feminine Arabic variant to `_arF` when the
  string addresses the user. Dates and money use Western digits.
- Touch targets ≥ 44px; empty states keep their frame with one sentence and an action.
- Verify by looking: re-render screenshots (dark ar/en, light ar feminine) and, for
  motion, run the web build through Playwright and sample frames.

## Tools

- Skills (after `tool/install_claude_skills.sh`): `impeccable`, `taste-skill`,
  `web-interface-guidelines`. Impeccable's launcher downloads a binary: don't run it
  without the owner's OK; read its `reference/*.md` directly instead.
- MCP (`.mcp.json`): `playwright` for browser checks of the web build, `figma` for design
  files.
