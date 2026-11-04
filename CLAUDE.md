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

## Design rules

Direction chosen by the owner from two banking-app references (navy hero cards, orange
action, white rounded cards). The owner's brief wins over generic skill defaults.

- Light by default (`#F2F3F8` ground, white cards radius 22 with a soft navy shadow);
  dark mode keeps the navy family (`#0D0C22` ground, `#17163A` cards, 1px lines).
- Navy gradient (`#1E1B5E` → `#3B35B2`) only on hero surfaces: home header, month
  projection, profile header, login, splash. Orange `#F2763A` is the main action (centre
  + button, sign-up CTA) and highlights; never decoration.
- Status colour is meaning: green on track, amber past target, red over the limit (on navy
  use `Tokens.heroGood/heroWarn/heroDanger`). Each category has its own hue for its icon
  tile and bar (`CategoryDef.color`).
- The screen's answer is the biggest figure (44px). Figures inside a hero use a divided
  translucent strip, not separate tiles.
- Motion: splash mark settles → home layout shows with flat bones at final sizes → values
  land and the today meter fills. Respect Reduce Motion. Nothing shifts when values land.
- No emoji in UI copy. CupertinoIcons only. Choices in settings open a sheet
  (`pickOption`) instead of squeezing segmented controls into rows — that overflowed in
  English before.
- Every string goes through `S.t()`; add the feminine Arabic variant to `_arF` when the
  string addresses the user. Dates and money use Western digits.
- Touch targets ≥ 44px; empty states keep their frame with one sentence and an action.
- Verify by looking: `flutter test tool/screenshots_test.dart --update-goldens` renders
  every screen (Arabic light, English light, Arabic feminine dark, sign-up, login, bank).

## Bank messages (read-only)

No bank login or credentials, ever. Banks text the user on every transaction; an iPhone
Shortcut (Message automation → URL Encode → Open URLs `masrofy://bank?text=…`) hands the
text to the app, or the user pastes it. `lib/services/bank_sms.dart` parses amount,
debit/credit, merchant, available balance and a category guess; tests in
`test/bank_sms_test.dart`. When adding formats, add a test with made-up card digits.

## Tools

- Skills (after `tool/install_claude_skills.sh`): `impeccable`, `taste-skill`,
  `web-interface-guidelines`. Impeccable's launcher downloads a binary: don't run it
  without the owner's OK; read its `reference/*.md` directly instead.
- MCP (`.mcp.json`): `playwright` for browser checks of the web build, `figma` for design
  files.
