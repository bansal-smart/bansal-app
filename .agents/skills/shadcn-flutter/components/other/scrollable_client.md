# ScrollableClient

A customizable scrollable widget with two-axis scrolling support.

## Usage

### Basic Example
```dart
ScrollableClient(
  mainAxis: Axis.vertical,
  verticalDetails: ScrollableDetails.vertical(),
  builder: (context, offset, viewportSize, child) {
    return CustomPaint(
      painter: MyPainter(offset),
      child: child,
    );
  },
  child: MyContent(),
)
```



## Features
- Responsive design
- Customizable styling
- Accessibility support

## Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `primary` | `bool?` | Whether this is the primary scrollable in the widget tree. |
| `mainAxis` | `Axis` | Primary scrolling axis. |
| `verticalDetails` | `ScrollableDetails` | Scroll configuration for vertical axis. |
| `horizontalDetails` | `ScrollableDetails` | Scroll configuration for horizontal axis. |
| `builder` | `ScrollableBuilder` | Builder for creating content with viewport info. |
| `child` | `Widget?` | Optional child widget. |
| `diagonalDragBehavior` | `DiagonalDragBehavior?` | Behavior for diagonal drag gestures. |
| `dragStartBehavior` | `DragStartBehavior?` | When drag gestures should start. |
| `keyboardDismissBehavior` | `ScrollViewKeyboardDismissBehavior?` | How keyboard dismissal should behave. |
| `clipBehavior` | `Clip?` | How to clip content. |
| `hitTestBehavior` | `HitTestBehavior?` | Hit test behavior. |
| `overscroll` | `bool?` | Whether overscroll effects are enabled. |
| `theme` | `ScrollableClientTheme?` | Styling for this widget alone. Takes precedence over any `T` an ancestor [ComponentTheme] provides: when this is non-null the ancestor is not consulted at all, so a field left null here falls back to the component's built-in default rather than to the ancestor's value. To adjust an ancestor theme instead of replacing it, read it with [ComponentTheme.maybeOf] and `copyWith` the result. Prefer this over the per-property constructor arguments, which are deprecated. |
