# TabContainer

Container widget for managing multiple tabs.

## Usage

### Basic Example
```dart
TabContainer(
  selected: null, // TODO: Provide selected
  onSelect: null, // TODO: Provide onSelect
  children: null, // TODO: Provide children
)
```



## Features
- Responsive design
- Customizable styling
- Accessibility support

## Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `selected` | `int` | Currently selected tab index. |
| `onSelect` | `ValueChanged<int>?` | Callback when tab selection changes. |
| `children` | `List<TabChild>` | List of tab children to display. |
| `builder` | `TabBuilder?` | Optional custom tab layout builder. |
| `childBuilder` | `TabChildBuilder?` | Optional custom child widget builder. |
| `theme` | `TabContainerTheme?` | Styling for this widget alone. Takes precedence over any `T` an ancestor [ComponentTheme] provides: when this is non-null the ancestor is not consulted at all, so a field left null here falls back to the component's built-in default rather than to the ancestor's value. To adjust an ancestor theme instead of replacing it, read it with [ComponentTheme.maybeOf] and `copyWith` the result. Prefer this over the per-property constructor arguments, which are deprecated. |
