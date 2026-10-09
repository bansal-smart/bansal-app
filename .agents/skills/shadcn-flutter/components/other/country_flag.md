# CountryFlag

Displays the flag of a country.

## Usage

### Basic Example
```dart
CountryFlag.fromCountryCode(
  'US',
  height: 18,
  width: 24,
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
);
```



## Features
- Responsive design
- Customizable styling
- Accessibility support

## Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `country` | `Country?` | The country to draw, or null if the lookup found nothing.  A null country renders as an empty box of the requested size, so a bad country code leaves the surrounding layout intact instead of throwing. |
| `width` | `double?` | Width of the flag; falls back to [CountryFlagTheme.width], then to 24 scaled by the theme. |
| `height` | `double?` | Height of the flag; falls back to [CountryFlagTheme.height], then to 18 scaled by the theme. |
| `shape` | `ShapeBorder?` | Shape the flag is clipped to.  Falls back to [CountryFlagTheme.shape], then to no clipping. |
| `theme` | `CountryFlagTheme?` | Styling for this widget alone. Takes precedence over any `T` an ancestor [ComponentTheme] provides: when this is non-null the ancestor is not consulted at all, so a field left null here falls back to the component's built-in default rather than to the ancestor's value. To adjust an ancestor theme instead of replacing it, read it with [ComponentTheme.maybeOf] and `copyWith` the result. Prefer this over the per-property constructor arguments, which are deprecated. |
