# App icon

Put the source logo here as **`app_icon.png`**, then regenerate:

```bash
flutter pub get
dart run flutter_launcher_icons
```

That rewrites `android/app/src/main/res/mipmap-*/` and
`ios/Runner/Assets.xcassets/AppIcon.appiconset/` — those generated files are
committed, so the icon ships with a normal build and nobody else has to run
this.

Requirements for the source file:
- square, **1024×1024** PNG
- no transparency (iOS rejects an icon with an alpha channel, and
  `remove_alpha_ios` flattens it onto black rather than something you chose)
- keep important detail away from the very edge — every launcher masks the
  icon to its own shape (circle, squircle, rounded square)
