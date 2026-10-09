# StageContainer

A responsive container that adapts to screen size using breakpoints.

## Usage

### Basic Example
```dart
StageContainer(
  breakpoint: StageBreakpoint.defaultBreakpoints,
  padding: EdgeInsets.symmetric(horizontal: 24),
  builder: (context, padding) {
    return Container(
      padding: padding,
      child: Text('Responsive content'),
    );
  },
)
```



## Features
- Responsive design
- Customizable styling
- Accessibility support

## Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `breakpoint` | `StageBreakpoint` | The breakpoint strategy for determining container width.  Defaults to [StageBreakpoint.defaultBreakpoints]. |
| `builder` | `Widget Function(BuildContext context, EdgeInsets padding)` | Builder function that receives context and calculated padding.  The padding parameter accounts for responsive adjustments. |
| `padding` | `EdgeInsets` | Base padding for the container.  Defaults to `EdgeInsets.symmetric(horizontal: 72)`. |
| `theme` | `StageContainerTheme?` | Styling for this widget alone. Takes precedence over any `T` an ancestor [ComponentTheme] provides: when this is non-null the ancestor is not consulted at all, so a field left null here falls back to the component's built-in default rather than to the ancestor's value. To adjust an ancestor theme instead of replacing it, read it with [ComponentTheme.maybeOf] and `copyWith` the result. Prefer this over the per-property constructor arguments, which are deprecated. |
