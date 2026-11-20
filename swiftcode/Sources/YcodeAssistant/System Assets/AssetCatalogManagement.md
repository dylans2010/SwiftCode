<!-- system-index-depends: SwiftUIArchitecture.md -->
# Asset Catalog Management (.xcassets) & Resource Optimization

Best practices for structuring, updating, and optimizing image sets, color sets, symbols, and app icons in Apple Asset Catalogs.

---

## 1. Anatomy of an `.xcassets` Catalog
An Asset Catalog is a directory containing JSON metadata files (`Contents.json`) and media assets:
```
Assets.xcassets/
├── Contents.json
├── AccentColor.colorset/
│   └── Contents.json
├── AppIcon.appiconset/
│   ├── Contents.json
│   └── icon_512x512@2x.png
└── ToolbarBuild.imageset/
    ├── Contents.json
    └── build_icon.pdf
```

---

## 2. Vector Assets vs Bitmaps
- **Vector PDFs / SVGs:** Always prefer vector assets for UI icons. Check "Preserve Vector Data" in Xcode for dynamic resolution scaling.
- **Single Scale:** With vector assets, specify a single vector file instead of legacy `@1x`, `@2x`, `@3x` bitmaps.

---

## 3. Dynamic Color Sets
Define dark and light mode color variations in `.colorset/Contents.json`:
```json
{
  "colors": [
    {
      "idiom": "universal",
      "color": { "color-space": "srgb", "components": { "red": "0.1", "green": "0.1", "blue": "0.1", "alpha": "1.0" } }
    },
    {
      "idiom": "universal",
      "appearances": [{ "appearance": "luminosity", "value": "dark" }],
      "color": { "color-space": "srgb", "components": { "red": "0.9", "green": "0.9", "blue": "0.9", "alpha": "1.0" } }
    }
  ]
}
```
