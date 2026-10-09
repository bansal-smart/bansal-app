# Select

A customizable dropdown selection widget for single-value selection.

## Usage

### Select Example
```dart
import 'package:docs/pages/docs/components/select/select_example_1.dart';
import 'package:docs/pages/docs/components/select/select_example_2.dart';
import 'package:docs/pages/docs/components/select/select_example_3.dart';
import 'package:docs/pages/docs/components/select/select_example_4.dart';
import 'package:docs/pages/docs/components/select/select_example_5.dart';
import 'package:docs/pages/docs/components/select/select_example_6.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_usage_example.dart';
import '../component_page.dart';

class SelectExample extends StatelessWidget {
  const SelectExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComponentPage(
      name: 'select',
      description: 'A select component that allows you to select an item from a list of items.',
      displayName: 'Select',
      children: [
        WidgetUsageExample(
          title: 'Example',
          path: 'lib/pages/docs/components/select/select_example_1.dart',
          child: SelectExample1(),
        ),
        WidgetUsageExample(
          title: 'Example with search',
          path: 'lib/pages/docs/components/select/select_example_2.dart',
          child: SelectExample2(),
        ),
        WidgetUsageExample(
          title: 'Asynchronous infinite example',
          path: 'lib/pages/docs/components/select/select_example_3.dart',
          child: SelectExample3(),
        ),
        WidgetUsageExample(
          title: 'Example with no virtualization',
          path: 'lib/pages/docs/components/select/select_example_4.dart',
          child: SelectExample4(),
        ),
        WidgetUsageExample(
          title: 'Example with custom colors',
          path: 'lib/pages/docs/components/select/select_example_5.dart',
          child: SelectExample5(),
        ),
        WidgetUsageExample(
          title: 'Example with create new item',
          path: 'lib/pages/docs/components/select/select_example_6.dart',
          child: SelectExample6(),
        ),
      ],
    );
  }
}

```

### Select Example 1
```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

class SelectExample1 extends StatefulWidget {
  const SelectExample1({super.key});

  @override
  State<SelectExample1> createState() => _SelectExample1State();
}

class _SelectExample1State extends State<SelectExample1> {
  String? selectedValue;
  @override
  Widget build(BuildContext context) {
    return Select<String>(
      // How to render each selected item as text in the field.
      itemBuilder: (context, item) {
        return Text(item);
      },
      // Limit the popup size so it doesn't grow too large in the docs view.
      popupConstraints: const BoxConstraints(maxHeight: 300, maxWidth: 200),
      onChanged: (value) {
        setState(() {
          // Save the currently selected value (or null to clear).
          selectedValue = value;
        });
      },
      // The current selection bound to this field.
      value: selectedValue,
      placeholder: const Text('Select a fruit'),
      popup: const SelectPopup(
        items: SelectItemList(
          children: [
            // A simple static list of options.
            SelectItemButton(value: 'Apple', child: Text('Apple')),
            SelectItemButton(value: 'Banana', child: Text('Banana')),
            SelectItemButton(value: 'Cherry', child: Text('Cherry')),
          ],
        ),
      ),
    );
  }
}

```

### Select Example 2
```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

class SelectExample2 extends StatefulWidget {
  const SelectExample2({super.key});

  @override
  State<SelectExample2> createState() => _SelectExample2State();
}

class _SelectExample2State extends State<SelectExample2> {
  final Map<String, List<String>> fruits = {
    'Apple': ['Red Apple', 'Green Apple'],
    'Banana': ['Yellow Banana', 'Brown Banana'],
    'Lemon': ['Yellow Lemon', 'Green Lemon'],
    'Tomato': ['Red', 'Green', 'Yellow', 'Brown'],
  };
  String? selectedValue;

  Iterable<MapEntry<String, List<String>>> _filteredFruits(
    String searchQuery,
  ) sync* {
    // Yield entries whose key or children match the current search query.
    for (final entry in fruits.entries) {
      final filteredValues = entry.value
          .where((value) => _filterName(value, searchQuery))
          .toList();
      if (filteredValues.isNotEmpty) {
        yield MapEntry(entry.key, filteredValues);
      } else if (_filterName(entry.key, searchQuery)) {
        yield entry;
      }
    }
  }

  bool _filterName(String name, String searchQuery) {
    // Case-insensitive substring filter.
    return name.toLowerCase().contains(searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Select<String>(
      itemBuilder: (context, item) {
        return Text(item);
      },
      popup: SelectPopup.builder(
        // Provide a search field inside the popup.
        searchPlaceholder: const Text('Search fruit'),
        builder: (context, searchQuery) {
          // Filter entries by the user's search.
          final filteredFruits = searchQuery == null
              ? fruits.entries
              : _filteredFruits(searchQuery);
          return SelectItemList(
            children: [
              for (final entry in filteredFruits)
                SelectGroup(
                  // Group by category (e.g., Apple, Banana) with a header label.
                  headers: [SelectLabel(child: Text(entry.key))],
                  children: [
                    for (final value in entry.value)
                      SelectItemButton(value: value, child: Text(value)),
                  ],
                ),
            ],
          );
        },
      ),
      onChanged: (value) {
        setState(() {
          selectedValue = value;
        });
      },
      constraints: const BoxConstraints(minWidth: 200),
      value: selectedValue,
      placeholder: const Text('Select a fruit'),
    );
  }
}

```

### Select Example 3
```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

class SelectExample3 extends StatefulWidget {
  const SelectExample3({super.key});

  @override
  State<SelectExample3> createState() => _SelectExample3State();
}

class _SelectExample3State extends State<SelectExample3> {
  final Map<String, List<String>> fruits = {
    'Apple': ['Red Apple', 'Green Apple'],
    'Banana': ['Yellow Banana', 'Brown Banana'],
    'Lemon': ['Yellow Lemon', 'Green Lemon'],
    'Tomato': ['Red', 'Green', 'Yellow', 'Brown'],
  };
  String? selectedValue;

  Iterable<MapEntry<String, List<String>>> _filteredFruits(
    String searchQuery,
  ) sync* {
    for (final entry in fruits.entries) {
      final filteredValues = entry.value
          .where((value) => _filterName(value, searchQuery))
          .toList();
      if (filteredValues.isNotEmpty) {
        yield MapEntry(entry.key, filteredValues);
      } else if (_filterName(entry.key, searchQuery)) {
        yield entry;
      }
    }
  }

  bool _filterName(String name, String searchQuery) {
    return name.toLowerCase().contains(searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    return Select<String>(
      itemBuilder: (context, item) {
        return Text(item);
      },
      popup: SelectPopup.builder(
        // Popup with async data loading and custom empty/loading UI.
        searchPlaceholder: const Text('Search fruit'),
        emptyBuilder: (context) {
          return const Center(child: Text('No fruit found'));
        },
        loadingBuilder: (context) {
          return const Center(child: CircularProgressIndicator());
        },
        builder: (context, searchQuery) async {
          final filteredFruits = searchQuery == null
              ? fruits.entries.toList()
              : _filteredFruits(searchQuery).toList();
          // Simulate a delay for loading
          // In a real-world scenario, you would fetch data from an API or database
          await Future.delayed(const Duration(milliseconds: 500));
          return SelectItemBuilder(
            // When 0, the popup renders the emptyBuilder; otherwise the builder lazily builds rows.
            childCount: filteredFruits.isEmpty ? 0 : null,
            builder: (context, index) {
              final entry = filteredFruits[index % filteredFruits.length];
              return SelectGroup(
                headers: [SelectLabel(child: Text(entry.key))],
                children: [
                  for (final value in entry.value)
                    SelectItemButton(value: value, child: Text(value)),
                ],
              );
            },
          );
        },
      ),
      onChanged: (value) {
        setState(() {
          selectedValue = value;
        });
      },
      constraints: const BoxConstraints(minWidth: 200),
      value: selectedValue,
      placeholder: const Text('Select a fruit'),
    );
  }
}

```

### Select Example 4
```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

class SelectExample4 extends StatefulWidget {
  const SelectExample4({super.key});

  @override
  State<SelectExample4> createState() => _SelectExample4State();
}

class _SelectExample4State extends State<SelectExample4> {
  String? selectedValue;
  @override
  Widget build(BuildContext context) {
    return Select<String>(
      itemBuilder: (context, item) {
        return Text(item);
      },
      popupConstraints: const BoxConstraints(maxHeight: 300, maxWidth: 200),
      onChanged: (value) {
        setState(() {
          selectedValue = value;
        });
      },
      value: selectedValue,
      placeholder: const Text('Select a fruit'),
      // Constrain popup width to its intrinsic content size (no virtualization in this variant).
      overlayConfiguration: const PopoverConfiguration(
        widthConstraint: PopoverConstraint.intrinsic,
        alignment: Alignment.topCenter,
      ),
      // Use a simple non-virtualized popup; suitable for small lists.
      popup: const SelectPopup.noVirtualization(
        items: SelectItemList(
          children: [
            SelectItemButton(value: 'Apple', child: Text('Apple')),
            SelectItemButton(value: 'Banana', child: Text('Banana')),
            SelectItemButton(value: 'Cherry', child: Text('Cherry')),
          ],
        ),
      ),
    );
  }
}

```

### Select Example 5
```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

// Demonstrates Select.decoration: a WidgetStatePropertyDelegate<Decoration>
// that overrides the trigger's appearance per state. One delegate covers the
// idle border, the focused border, the background and the hover color, so
// restyling a Select no longer means wrapping it in a Theme scope that would
// also restyle everything else nested inside.
//
// The same delegate can be set on SelectTheme to apply it to every Select in
// a subtree.

class SelectExample5 extends StatefulWidget {
  const SelectExample5({super.key});

  @override
  State<SelectExample5> createState() => _SelectExample5State();
}

class _SelectExample5State extends State<SelectExample5> {
  String? perInstance;
  String? fromTheme;

  static const _popup = SelectPopup<String>(
    items: SelectItemList(
      children: [
        SelectItemButton(value: 'Apple', child: Text('Apple')),
        SelectItemButton(value: 'Banana', child: Text('Banana')),
        SelectItemButton(value: 'Cherry', child: Text('Cherry')),
      ],
    ),
  );

  // Receives the decoration the Select resolved on its own, so it can adjust
  // one facet and leave the rest alone.
  Decoration _decorate(
    BuildContext context,
    Set<WidgetState> states,
    Decoration value,
  ) {
    final theme = Theme.of(context);
    final Color border;
    if (states.focused) {
      border = theme.colorScheme.primary;
    } else if (states.hovered) {
      border = theme.colorScheme.primary.scaleAlpha(0.5);
    } else {
      border = theme.colorScheme.border;
    }
    // Blended into the card colour rather than laid over it as a translucent
    // fill, so the trigger stays opaque and only its tint changes on hover.
    return (value as BoxDecoration).copyWith(
      color: states.hovered
          ? Color.alphaBlend(
              theme.colorScheme.primary.scaleAlpha(0.08),
              theme.colorScheme.card,
            )
          : theme.colorScheme.card,
      border: Border.all(color: border, width: 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 24,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            const Text('Per instance').muted().small(),
            Select<String>(
              itemBuilder: (context, item) => Text(item),
              value: perInstance,
              placeholder: const Text('Select a fruit'),
              // Fixed width, so the trigger does not resize around whichever
              // value is selected.
              constraints: const BoxConstraints.tightFor(width: 200),
              onChanged: (value) => setState(() => perInstance = value),
              decoration: _decorate,
              popup: _popup.call,
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            const Text('From SelectTheme').muted().small(),
            // Scoped to Select only — sibling widgets keep the app theme.
            ComponentTheme(
              data: SelectTheme(decoration: _decorate),
              child: Select<String>(
                itemBuilder: (context, item) => Text(item),
                value: fromTheme,
                placeholder: const Text('Select a fruit'),
                constraints: const BoxConstraints.tightFor(width: 200),
                onChanged: (value) => setState(() => fromTheme = value),
                popup: _popup.call,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

```

### Select Example 6
```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

// Demonstrates creating an option inline, without leaving the select.
//
// The popup's own search field doubles as the input: whatever the user typed
// and did not find becomes the name of the new item, so there is no dialog and
// no navigation. Two pieces make it work:
//
//  - SelectPopup.builder(shrinkWrap: true) sizes the popup to its content, so
//    the create row sits directly under the last match instead of at the
//    bottom of a fixed-height list.
//  - SelectPopupHandle.close() lets that row dismiss the popup on its own
//    terms. It is not an item, so nothing would otherwise close the popup for
//    it — autoClose only fires as a side effect of a selection.
//
// The row is an ordinary widget in the list, so the caller decides whether to
// include it at all — which is what permission-gated creation needs.

class SelectExample6 extends StatefulWidget {
  const SelectExample6({super.key});

  @override
  State<SelectExample6> createState() => _SelectExample6State();
}

class _SelectExample6State extends State<SelectExample6> {
  final List<String> _fruits = ['Apple', 'Banana', 'Cherry'];
  String? _selected;

  // Flip to false to drop the create row without touching anything else.
  final bool _canCreate = true;

  void _create(String name) {
    setState(() {
      _fruits.add(name);
      // Selected straight away: creating it inline is only worth doing if the
      // user does not then have to find it in the list.
      _selected = name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Select<String>(
      itemBuilder: (context, item) => Text(item),
      value: _selected,
      placeholder: const Text('Select a fruit'),
      // Fixed width, so the trigger does not resize around whichever value is
      // selected or newly created.
      constraints: const BoxConstraints.tightFor(width: 260),
      onChanged: (value) => setState(() => _selected = value),
      popupConstraints: const BoxConstraints(maxHeight: 300, maxWidth: 260),
      popup: SelectPopup<String>.builder(
        searchPlaceholder: const Text('Search or type a new fruit'),
        // Without this the list claims the full constrained height and the
        // create row floats below empty space.
        shrinkWrap: true,
        builder: (context, searchQuery) {
          final query = searchQuery?.trim() ?? '';
          final matches = _fruits
              .where(
                (fruit) =>
                    query.isEmpty ||
                    fruit.toLowerCase().contains(query.toLowerCase()),
              )
              .toList();
          // Nothing to create from an empty box, and no point offering to
          // create something that already exists.
          final canCreate =
              _canCreate &&
              query.isNotEmpty &&
              !_fruits.any(
                (fruit) => fruit.toLowerCase() == query.toLowerCase(),
              );
          return SelectItemList(
            children: [
              for (final fruit in matches)
                SelectItemButton(value: fruit, child: Text(fruit)),
              if (matches.isEmpty && !canCreate)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: const Text('No fruits found').muted().small(),
                ),
              if (canCreate) ...[
                if (matches.isNotEmpty) const Divider(),
                Builder(
                  builder: (context) {
                    // Resolved here so the handle belongs to the popup that is
                    // actually on screen.
                    final handle = SelectPopupHandle.of(context);
                    return GhostButton(
                      leading: const Icon(LucideIcons.plus),
                      alignment: AlignmentDirectional.centerStart,
                      onPressed: () {
                        _create(query);
                        handle.close();
                      },
                      child: Text('Create "$query"'),
                    );
                  },
                ),
              ],
            ],
          );
        },
      ).call,
    );
  }
}

```

### Select Tile
```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:docs/pages/docs/components_page.dart';
import 'package:gap/gap.dart';

class SelectTile extends StatelessWidget implements IComponentPage {
  const SelectTile({super.key});

  @override
  String get title => 'Select';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ComponentCard(
      name: 'select',
      title: 'Select',
      scale: 1.2,
      example: Card(
        child: Align(
          alignment: Alignment.topLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Select<String>(
                itemBuilder: (context, item) {
                  return Text(item);
                },
                placeholder: const Text('Select a fruit'),
                value: 'Apple',
                enabled: true,
                constraints: const BoxConstraints.tightFor(width: 300),
                popup: const SelectPopup(),
              ),
              Gap(8 * theme.scaling),
              const SizedBox(
                width: 300,
                child: SelectPopup(
                  items: SelectItemList(
                    children: [
                      SelectItemButton(value: 'Apple', child: Text('Apple')),
                      SelectItemButton(value: 'Banana', child: Text('Banana')),
                      SelectItemButton(value: 'Lemon', child: Text('Lemon')),
                      SelectItemButton(value: 'Tomato', child: Text('Tomato')),
                      SelectItemButton(
                        value: 'Cucumber',
                        child: Text('Cucumber'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ).sized(height: 300, width: 200),
    );
  }
}

```



## Features
- Responsive design
- Customizable styling
- Accessibility support

## Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `kDefaultSelectMaxHeight` | `dynamic` | Default maximum height for select popups in logical pixels. |
| `onChanged` | `ValueChanged<T?>?` |  |
| `placeholder` | `Widget?` |  |
| `filled` | `bool` |  |
| `focusNode` | `FocusNode?` |  |
| `constraints` | `BoxConstraints?` |  |
| `popupConstraints` | `BoxConstraints?` |  |
| `overlayConfiguration` | `OverlayConfiguration?` |  |
| `adaptiveOverlay` | `bool?` |  |
| `value` | `T?` | The currently selected value. |
| `borderRadius` | `BorderRadiusGeometry?` |  |
| `padding` | `EdgeInsetsGeometry?` |  |
| `decoration` | `WidgetStatePropertyDelegate<Decoration>?` |  |
| `disableHoverEffect` | `bool` |  |
| `canUnselect` | `bool` |  |
| `autoClosePopover` | `bool?` |  |
| `enabled` | `bool?` | Whether the select is enabled for user interaction. |
| `popup` | `SelectPopupBuilder` |  |
| `itemBuilder` | `SelectValueBuilder<T>` |  |
| `valueSelectionHandler` | `SelectValueSelectionHandler<T>?` |  |
| `valueSelectionPredicate` | `SelectValueSelectionPredicate<T>?` |  |
| `showValuePredicate` | `Predicate<T>?` |  |
| `expandIcon` | `Widget?` |  |
| `theme` | `SelectTheme?` | Styling for this widget alone. Takes precedence over any `T` an ancestor [ComponentTheme] provides: when this is non-null the ancestor is not consulted at all, so a field left null here falls back to the component's built-in default rather than to the ancestor's value. To adjust an ancestor theme instead of replacing it, read it with [ComponentTheme.maybeOf] and `copyWith` the result. Prefer this over the per-property constructor arguments, which are deprecated. |
