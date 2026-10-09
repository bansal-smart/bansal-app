# Scrollbar

A customizable scrollbar widget for shadcn_flutter.

## Usage

### Basic Example
```dart
Scrollbar(
  controller: scrollController,
  thumbVisibility: true,
  thickness: 8,
  child: ListView.builder(
    controller: scrollController,
    itemCount: 100,
    itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
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
| `theme` | `ScrollbarTheme?` | Styling for this widget alone. Takes precedence over any `T` an ancestor [ComponentTheme] provides: when this is non-null the ancestor is not consulted at all, so a field left null here falls back to the component's built-in default rather than to the ancestor's value. To adjust an ancestor theme instead of replacing it, read it with [ComponentTheme.maybeOf] and `copyWith` the result. Prefer this over the per-property constructor arguments, which are deprecated. |
| `child` | `Widget` | The scrollable widget to attach the scrollbar to. |
| `controller` | `ScrollController?` | Optional scroll controller for the scrollable content.  If not provided, the scrollbar will use the nearest [Scrollable]'s controller. |
| `thumbVisibility` | `bool?` | Whether the scrollbar thumb is always visible.  When `true`, the thumb remains visible even when not scrolling. When `false` or `null`, the thumb fades out after scrolling stops. |
| `trackVisibility` | `bool?` | Whether the scrollbar track is always visible.  When `true`, the track (background) remains visible. When `false` or `null`, only the thumb is shown. |
| `thickness` | `double?` | The thickness of the scrollbar in logical pixels. |
| `radius` | `Radius?` | The border radius of the scrollbar thumb. |
| `color` | `Color?` | The color of the scrollbar thumb. |
| `interactive` | `bool?` | Whether the scrollbar can be dragged to scroll.  When `true`, users can click and drag the scrollbar thumb to scroll. |
| `notificationPredicate` | `ScrollNotificationPredicate?` | Predicate to determine which scroll notifications trigger scrollbar updates. |
| `scrollbarOrientation` | `ScrollbarOrientation?` | The orientation of the scrollbar (vertical or horizontal). |
