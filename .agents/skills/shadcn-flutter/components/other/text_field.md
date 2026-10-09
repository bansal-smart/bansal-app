# TextField

A highly customizable single-line text input widget with extensive feature support.

## Usage

### Basic Example
```dart
TextField(
  hintText: 'Enter your email',
  keyboardType: TextInputType.emailAddress,
  features: [
    InputClearFeature(),
    InputRevalidateFeature(),
  ],
  onChanged: (text) => _handleTextChange(text),
);
```



## Features
- Responsive design
- Customizable styling
- Accessibility support

## Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `onDragSelectionStart` | `ValueChanged<TapDragStartDetails>?` | Called when a drag-to-select gesture starts inside this field.  Mirrors [TextSelectionGestureDetectorBuilder.onDragSelectionStart] so callers composing several [TextField]s together (e.g. [FormattedInput]) can track a drag that may continue outside this field's own bounds. This does not replace the field's own default drag-selection handling. |
| `onDragSelectionUpdate` | `ValueChanged<TapDragUpdateDetails>?` | Called on every update of a drag-to-select gesture started in this field.  See [onDragSelectionStart]. |
| `onDragSelectionEnd` | `ValueChanged<TapDragEndDetails>?` | Called when a drag-to-select gesture started in this field ends.  See [onDragSelectionStart]. |
| `theme` | `TextFieldTheme?` | Styling for this widget alone. Takes precedence over any `T` an ancestor [ComponentTheme] provides: when this is non-null the ancestor is not consulted at all, so a field left null here falls back to the component's built-in default rather than to the ancestor's value. To adjust an ancestor theme instead of replacing it, read it with [ComponentTheme.maybeOf] and `copyWith` the result. Prefer this over the per-property constructor arguments, which are deprecated. |
