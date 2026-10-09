# Layout & Spacing

Master the responsive layout engine and spacing tokens of `shadcn_flutter`.

## Adaptive Scaling

The layout system distinguishes between **Mobile** and **Desktop** scaling defaults to ensure optimal legibility across devices.

- **Desktop**: 1.0x scaling (standard).
- **Mobile**: 1.25x scaling (larger touch targets and text).

You can override this globally in `ShadcnApp`:

```dart
ShadcnApp(
  scaling: AdaptiveScaling(1.1), // Custom uniform scaling
  // or
  scaling: AdaptiveScaling.only(textScaling: 1.2, sizeScaling: 1.0),
)
```

## Spacing Tokens

Use the semantic spacing helpers to maintain consistency.

### Gaps
Space children of a `Column` or `Row` with a `SizedBox` on the main axis.
shadcn_flutter used to re-export `Gap` from `package:gap`; it no longer does, so
name the axis explicitly.

| Size (unscaled) | In a `Column` | In a `Row` |
| :--- | :--- | :--- |
| 4 | `const SizedBox(height: 4)` | `const SizedBox(width: 4)` |
| 8 | `const SizedBox(height: 8)` | `const SizedBox(width: 8)` |
| 12 | `const SizedBox(height: 12)` | `const SizedBox(width: 12)` |
| 16 | `const SizedBox(height: 16)` | `const SizedBox(width: 16)` |
| 24 | `const SizedBox(height: 24)` | `const SizedBox(width: 24)` |
| 32 | `const SizedBox(height: 32)` | `const SizedBox(width: 32)` |

To space every child at once, `Column(...).gap(8)` and `Row(...).gap(8)` insert
the separator for you. `DensityGap(gapLg)` scales with the theme's density and
takes a `direction` (vertical by default).

### Padding
Access theme-aware padding via `Theme.of(context)`:

- `theme.paddingSm`: Small padding.
- `theme.paddingMd`: Medium padding.
- `theme.paddingLg`: Large padding.

## Border Radius

`shadcn_flutter` uses a base `radius` multiplier (default: 0.5) to calculate all corner roundness.

| Token | Calculation | Description |
| :--- | :--- | :--- |
| `radiusXs` | `radius * 4` | Extra small corners. |
| `radiusSm` | `radius * 8` | Small corners (default for many components). |
| `radiusMd` | `radius * 12` | Medium corners. |
| `radiusLg` | `radius * 16` | Large corners. |
| `radiusXl` | `radius * 20` | Extra large corners. |
| `radiusXxl` | `radius * 24` | 2X large corners. |

### Usage
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: theme.borderRadiusMd, // Returns a BorderRadius
    // or
    borderRadius: BorderRadius.circular(theme.radiusMd),
  ),
)
```

## Responsive Helpers

Use `Flexible`, `Expanded`, and `Flex` for fluid layouts. Additionally, `ShadcnApp` provides `Density` control to adjust how compact the UI should be on different screen sizes.
