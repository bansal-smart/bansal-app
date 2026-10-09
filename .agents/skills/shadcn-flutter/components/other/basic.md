# Basic

A versatile layout widget for arranging leading, title, subtitle, content, and trailing elements.

## Usage

### Basic Example
```dart
Basic(
  leading: Icon(LucideIcons.user),
  title: Text('John Doe'),
  subtitle: Text('john@example.com'),
  trailing: Icon(LucideIcons.chevronRight),
)
```



## Features
- Responsive design
- Customizable styling
- Accessibility support

## Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `leading` | `Widget?` | Leading widget, typically an icon or avatar. |
| `title` | `Widget?` | Primary title widget. |
| `subtitle` | `Widget?` | Secondary subtitle widget, displayed below title. |
| `content` | `Widget?` | Main content widget, displayed below title/subtitle. |
| `trailing` | `Widget?` | Trailing widget, typically an icon or action button. |
| `leadingAlignment` | `AlignmentGeometry?` | Alignment for the [leading] widget. |
| `trailingAlignment` | `AlignmentGeometry?` | Alignment for the [trailing] widget. |
| `titleAlignment` | `AlignmentGeometry?` | Alignment for the [title] widget. |
| `subtitleAlignment` | `AlignmentGeometry?` | Alignment for the [subtitle] widget. |
| `contentAlignment` | `AlignmentGeometry?` | Alignment for the [content] widget. |
| `contentSpacing` | `double?` | Spacing between content elements (default: 16). |
| `titleSpacing` | `double?` | Spacing between title and subtitle (default: 4). |
| `mainAxisAlignment` | `MainAxisAlignment?` | Main axis alignment for the overall layout. |
| `padding` | `EdgeInsetsGeometry?` | Padding around the entire widget. |
| `theme` | `BasicTheme?` | Styling for this widget alone. Takes precedence over any `T` an ancestor [ComponentTheme] provides: when this is non-null the ancestor is not consulted at all, so a field left null here falls back to the component's built-in default rather than to the ancestor's value. To adjust an ancestor theme instead of replacing it, read it with [ComponentTheme.maybeOf] and `copyWith` the result. Prefer this over the per-property constructor arguments, which are deprecated. |
