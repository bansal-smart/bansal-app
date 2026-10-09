# MultipleChoice

A widget for single-selection choice scenarios.

## Usage

### Basic Example
```dart
MultipleChoice<String>(
  value: selectedOption,
  onChanged: (value) => setState(() => selectedOption = value),
  child: Wrap(
    children: [
      ChoiceChip(value: 'A', child: Text('Option A')),
      ChoiceChip(value: 'B', child: Text('Option B')),
    ],
  ),
)
```



## Features
- Responsive design
- Customizable styling
- Accessibility support

## Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `child` | `Widget` | The child widget tree containing choice items. |
| `value` | `T?` | The currently selected value. |
| `onChanged` | `ValueChanged<T?>?` | Callback when the selection changes. |
| `enabled` | `bool?` | Whether choices are enabled. |
| `allowUnselect` | `bool?` | Whether the current selection can be unselected. |
| `theme` | `MultipleChoiceTheme?` | Styling for this widget alone. Takes precedence over any `T` an ancestor [ComponentTheme] provides: when this is non-null the ancestor is not consulted at all, so a field left null here falls back to the component's built-in default rather than to the ancestor's value. To adjust an ancestor theme instead of replacing it, read it with [ComponentTheme.maybeOf] and `copyWith` the result. Prefer this over the per-property constructor arguments, which are deprecated. |
