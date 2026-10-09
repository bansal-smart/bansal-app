# Spinner

Abstract base class for all spinner widgets.

## Usage

### Basic Example
```dart
Spinner(
)
```



## Features
- Responsive design
- Customizable styling
- Accessibility support

## Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `color` | `Color?` | Optional color override for the spinner.  If `null`, uses theme's spinner color or default foreground color. |
| `size` | `double?` | Optional size override for the spinner in logical pixels.  If `null`, uses theme's spinner size or a default size. |
| `theme` | `SpinnerTheme?` | Styling for this widget alone. Takes precedence over any `T` an ancestor [ComponentTheme] provides: when this is non-null the ancestor is not consulted at all, so a field left null here falls back to the component's built-in default rather than to the ancestor's value. To adjust an ancestor theme instead of replacing it, read it with [ComponentTheme.maybeOf] and `copyWith` the result. Prefer this over the per-property constructor arguments, which are deprecated. |
