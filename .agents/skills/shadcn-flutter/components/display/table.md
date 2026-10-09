# Table

A flexible table widget with support for spanning, scrolling, and interactive features.

## Usage

### Table Example
```dart
import 'package:docs/pages/docs/components/table/table_example_1.dart';
import 'package:docs/pages/docs/components/table/table_example_2.dart';
import 'package:docs/pages/docs/components/table/table_example_3.dart';
import 'package:docs/pages/docs/components/table/table_example_4.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../../widget_usage_example.dart';
import '../component_page.dart';

class TableExample extends StatelessWidget {
  const TableExample({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComponentPage(
      name: 'table',
      description: 'A table displays data in a tabular format.',
      displayName: 'Table',
      children: [
        WidgetUsageExample(
          title: 'Example',
          path: 'lib/pages/docs/components/table/table_example_1.dart',
          child: TableExample1(),
        ),
        WidgetUsageExample(
          title: 'Resizable Example',
          path: 'lib/pages/docs/components/table/table_example_2.dart',
          child: TableExample2(),
        ),
        WidgetUsageExample(
          title: 'Scrollable Example',
          path: 'lib/pages/docs/components/table/table_example_3.dart',
          child: TableExample3(),
        ),
        WidgetUsageExample(
          title: 'Right-to-left Example',
          path: 'lib/pages/docs/components/table/table_example_4.dart',
          child: TableExample4(),
        ),
      ],
    );
  }
}

```

### Table Example 1
```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

// Demonstrates a basic Table with a header row and body rows,
// including right-aligned numeric cells for amounts.

class TableExample1 extends StatefulWidget {
  const TableExample1({super.key});

  @override
  State<TableExample1> createState() => _TableExample1State();
}

class _TableExample1State extends State<TableExample1> {
  // Helper to build a header cell with muted, semibold text.
  TableCell buildHeaderCell(String text, [bool alignRight = false]) {
    return TableCell(
      child: Container(
        padding: const EdgeInsets.all(8),
        alignment: alignRight ? Alignment.centerRight : null,
        child: Text(text).muted().semiBold(),
      ),
    );
  }

  // Helper to build a regular body cell with optional right alignment.
  TableCell buildCell(String text, [bool alignRight = false]) {
    return TableCell(
      child: Container(
        padding: const EdgeInsets.all(8),
        alignment: alignRight ? Alignment.centerRight : null,
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Table(
      rows: [
        // Header row: typically use TableHeader, but a TableRow works for simple cases.
        TableRow(
          cells: [
            buildHeaderCell('Invoice'),
            buildHeaderCell('Status'),
            buildHeaderCell('Method'),
            buildHeaderCell('Amount', true),
          ],
        ),
        // Body rows with invoice data.
        TableRow(
          cells: [
            buildCell('INV001'),
            buildCell('Paid'),
            buildCell('Credit Card'),
            buildCell('\$250.00', true),
          ],
        ),
        TableRow(
          cells: [
            buildCell('INV002'),
            buildCell('Pending'),
            buildCell('PayPal'),
            buildCell('\$150.00', true),
          ],
        ),
        TableRow(
          cells: [
            buildCell('INV003'),
            buildCell('Unpaid'),
            buildCell('Bank Transfer'),
            buildCell('\$350.00', true),
          ],
        ),
        TableRow(
          cells: [
            buildCell('INV004'),
            buildCell('Paid'),
            buildCell('Credit Card'),
            buildCell('\$450.00', true),
          ],
        ),
        TableRow(
          cells: [
            buildCell('INV005'),
            buildCell('Paid'),
            buildCell('PayPal'),
            buildCell('\$550.00', true),
          ],
        ),
        TableRow(
          cells: [
            buildCell('INV006'),
            buildCell('Pending'),
            buildCell('Bank Transfer'),
            buildCell('\$200.00', true),
          ],
        ),
        TableRow(
          cells: [
            buildCell('INV007'),
            buildCell('Unpaid'),
            buildCell('Credit Card'),
            buildCell('\$300.00', true),
          ],
        ),
        // Footer supports spanning across columns via TableCell.columnSpan.
        TableFooter(
          cells: [
            TableCell(
              columnSpan: 4,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Text('Total'),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: const Text('\$2,300.00').semiBold(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

```

### Table Example 2
```dart
import 'package:shadcn_flutter/shadcn_flutter.dart';

// Demonstrates ResizableTable with controller defaults (sizes/constraints)
// and thin per-cell borders; users can drag to resize columns/rows.

class TableExample2 extends StatefulWidget {
  const TableExample2({super.key});

  @override
  State<TableExample2> createState() => _TableExample2State();
}

class _TableExample2State extends State<TableExample2> {
  // Builds a single cell with a thin border using the theme's border color.
  // Optionally right-aligns the content (useful for numeric values).
  TableCell buildCell(String text, [bool alignRight = false]) {
    final theme = Theme.of(context);
    return TableCell(
      theme: TableCellTheme(
        border: WidgetStatePropertyAll(
          Border.all(
            color: theme.colorScheme.border,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        alignment: alignRight ? Alignment.topRight : null,
        child: Text(text),
      ),
    );
  }

  // Controller sets defaults for column/row sizes and min constraints.
  // Users can still drag to resize each column and row at runtime.
  final ResizableTableController controller = ResizableTableController(
    defaultColumnWidth: 150,
    defaultRowHeight: 40,
    defaultHeightConstraint: const ConstrainedTableSize(min: 40),
    defaultWidthConstraint: const ConstrainedTableSize(min: 80),
  );

  @override
  Widget build(BuildContext context) {
    return OutlinedContainer(
      child: ResizableTable(
        controller: controller,
        // A header row followed by regular rows; all cells share the same
        // border/spacing style via buildCell.
        rows: [
          TableHeader(
            cells: [
              buildCell('Invoice'),
              buildCell('Status'),
              buildCell('Method'),
              buildCell('Amount', true),
            ],
          ),
          TableRow(
            cells: [
              buildCell('INV001'),
              buildCell('Paid'),
              buildCell('Credit Card'),
              buildCell('\$250.00', true),
            ],
          ),
          TableRow(
            cells: [
              buildCell('INV002'),
              buildCell('Pending'),
              buildCell('PayPal'),
              buildCell('\$150.00', true),
            ],
          ),
          TableRow(
            cells: [
              buildCell('INV003'),
              buildCell('Unpaid'),
              buildCell('Bank Transfer'),
              buildCell('\$350.00', true),
            ],
          ),
          TableRow(
            cells: [
              buildCell('INV004'),
              buildCell('Paid'),
              buildCell('Credit Card'),
              buildCell('\$450.00', true),
            ],
          ),
          TableRow(
            cells: [
              buildCell('INV005'),
              buildCell('Paid'),
              buildCell('PayPal'),
              buildCell('\$550.00', true),
            ],
          ),
          TableRow(
            cells: [
              buildCell('INV006'),
              buildCell('Pending'),
              buildCell('Bank Transfer'),
              buildCell('\$200.00', true),
            ],
          ),
          TableRow(
            cells: [
              buildCell('INV007'),
              buildCell('Unpaid'),
              buildCell('Credit Card'),
              buildCell('\$300.00', true),
            ],
          ),
          TableRow(
            cells: [
              buildCell('INV008'),
              buildCell('Paid'),
              buildCell('Credit Card'),
              buildCell('\$250.00', true),
            ],
          ),
          TableRow(
            cells: [
              buildCell('INV009'),
              buildCell('Pending'),
              buildCell('PayPal'),
              buildCell('\$150.00', true),
            ],
          ),
          TableRow(
            cells: [
              buildCell('INV010'),
              buildCell('Unpaid'),
              buildCell('Bank Transfer'),
              buildCell('\$350.00', true),
            ],
          ),
        ],
      ),
    );
  }
}

```

### Table Example 3
```dart
import 'dart:ui';

import 'package:shadcn_flutter/shadcn_flutter.dart';

// Demonstrates a scrollable Table hooked to ScrollableClient with frozen
// rows/columns and diagonal drag panning.

class TableExample3 extends StatefulWidget {
  const TableExample3({super.key});

  @override
  State<TableExample3> createState() => _TableExample3State();
}

class _TableExample3State extends State<TableExample3> {
  // Builds a bordered cell; amounts can be right-aligned by passing true.
  TableCell buildCell(String text, [bool alignRight = false]) {
    final theme = Theme.of(context);
    return TableCell(
      theme: TableCellTheme(
        border: WidgetStatePropertyAll(
          Border.all(
            color: theme.colorScheme.border,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        alignment: alignRight ? Alignment.topRight : null,
        child: Text(text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
        },
        // Disable overscroll glow and bouncing to keep the table steady.
        overscroll: false,
      ),
      child: SizedBox(
        height: 400,
        child: OutlinedContainer(
          child: ScrollableClient(
            // Allow simultaneous horizontal and vertical drags for panning.
            diagonalDragBehavior: DiagonalDragBehavior.free,
            builder: (context, offset, viewportSize, child) {
              return Table(
                // Hook the table's scroll offsets to the ScrollableClient.
                horizontalOffset: offset.dx,
                verticalOffset: offset.dy,
                // The viewport tells the table how much content area is visible.
                viewportSize: viewportSize,
                // Fixed sizes for consistent cell dimensions.
                defaultColumnWidth: const FixedTableSize(150),
                defaultRowHeight: const FixedTableSize(40),
                // Freeze the first and fourth rows, and the first and third columns.
                // These rows/columns stay pinned while the rest scrolls.
                frozenCells: const FrozenTableData(
                  frozenRows: [TableRef(0), TableRef(3)],
                  frozenColumns: [TableRef(0), TableRef(2)],
                ),
                rows: [
                  TableHeader(
                    cells: [
                      buildCell('Invoice'),
                      buildCell('Status'),
                      buildCell('Method'),
                      buildCell('Amount', true),
                      buildCell('Verification'),
                      buildCell('Last Updated'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV001'),
                      buildCell('Paid'),
                      buildCell('Credit Card'),
                      buildCell('\$250.00', true),
                      buildCell('Verified'),
                      buildCell('2 hours ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV002'),
                      buildCell('Pending'),
                      buildCell('PayPal'),
                      buildCell('\$150.00', true),
                      buildCell('Pending'),
                      buildCell('1 day ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV003'),
                      buildCell('Unpaid'),
                      buildCell('Bank Transfer'),
                      buildCell('\$350.00', true),
                      buildCell('Unverified'),
                      buildCell('1 week ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV004'),
                      buildCell('Paid'),
                      buildCell('Credit Card'),
                      buildCell('\$450.00', true),
                      buildCell('Verified'),
                      buildCell('2 weeks ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV005'),
                      buildCell('Paid'),
                      buildCell('PayPal'),
                      buildCell('\$550.00', true),
                      buildCell('Verified'),
                      buildCell('3 weeks ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV006'),
                      buildCell('Pending'),
                      buildCell('Bank Transfer'),
                      buildCell('\$200.00', true),
                      buildCell('Pending'),
                      buildCell('1 month ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV007'),
                      buildCell('Unpaid'),
                      buildCell('Credit Card'),
                      buildCell('\$300.00', true),
                      buildCell('Unverified'),
                      buildCell('1 year ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV008'),
                      buildCell('Paid'),
                      buildCell('Credit Card'),
                      buildCell('\$250.00', true),
                      buildCell('Verified'),
                      buildCell('2 hours ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV009'),
                      buildCell('Pending'),
                      buildCell('PayPal'),
                      buildCell('\$150.00', true),
                      buildCell('Pending'),
                      buildCell('1 day ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV010'),
                      buildCell('Unpaid'),
                      buildCell('Bank Transfer'),
                      buildCell('\$350.00', true),
                      buildCell('Unverified'),
                      buildCell('1 week ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV011'),
                      buildCell('Paid'),
                      buildCell('Credit Card'),
                      buildCell('\$450.00', true),
                      buildCell('Verified'),
                      buildCell('2 weeks ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV012'),
                      buildCell('Paid'),
                      buildCell('PayPal'),
                      buildCell('\$550.00', true),
                      buildCell('Verified'),
                      buildCell('3 weeks ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV013'),
                      buildCell('Pending'),
                      buildCell('Bank Transfer'),
                      buildCell('\$200.00', true),
                      buildCell('Pending'),
                      buildCell('1 month ago'),
                    ],
                  ),
                  TableRow(
                    cells: [
                      buildCell('INV014'),
                      buildCell('Unpaid'),
                      buildCell('Credit Card'),
                      buildCell('\$300.00', true),
                      buildCell('Unverified'),
                      buildCell('1 year ago'),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

```

### Table Example 4
```dart
import 'dart:ui';

import 'package:shadcn_flutter/shadcn_flutter.dart';
import 'package:gap/gap.dart';

// Demonstrates Table.textDirection. Flip the toggle to see the same table laid
// out right-to-left: column 0 moves to the right edge, the frozen first column
// pins there, and horizontal scrolling starts there and runs leftwards.
//
// Column indices never change. columnWidths key 0 and TableRef(0) still mean
// the first column in both directions.

class TableExample4 extends StatefulWidget {
  const TableExample4({super.key});

  @override
  State<TableExample4> createState() => _TableExample4State();
}

class _TableExample4State extends State<TableExample4> {
  bool _rtl = false;

  // Builds a bordered cell; the first column is tinted so it is easy to follow
  // as it moves from one edge to the other.
  TableCell buildCell(String text, {bool highlight = false}) {
    final theme = Theme.of(context);
    return TableCell(
      theme: TableCellTheme(
        border: WidgetStatePropertyAll(
          Border.all(
            color: theme.colorScheme.border,
            strokeAlign: BorderSide.strokeAlignCenter,
          ),
        ),
        backgroundColor: highlight
            ? WidgetStatePropertyAll(theme.colorScheme.muted)
            : null,
      ),
      child: Container(padding: const EdgeInsets.all(8), child: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final direction = _rtl ? TextDirection.rtl : TextDirection.ltr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Checkbox(
              state: _rtl ? CheckboxState.checked : CheckboxState.unchecked,
              onChanged: (state) {
                setState(() {
                  _rtl = state == CheckboxState.checked;
                });
              },
              trailing: const Text('Right-to-left'),
            ),
          ],
        ),
        const Gap(16),
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
            },
            overscroll: false,
          ),
          child: SizedBox(
            height: 280,
            child: OutlinedContainer(
              child: ScrollableClient(
                diagonalDragBehavior: DiagonalDragBehavior.free,
                // Reversed so that scroll offset zero is the first column,
                // which under RTL sits at the right edge.
                horizontalDetails: ScrollableDetails.horizontal(reverse: _rtl),
                builder: (context, offset, viewportSize, child) {
                  return Table(
                    textDirection: direction,
                    horizontalOffset: offset.dx,
                    verticalOffset: offset.dy,
                    viewportSize: viewportSize,
                    defaultColumnWidth: const FixedTableSize(150),
                    defaultRowHeight: const FixedTableSize(40),
                    // Row 0 and column 0 stay pinned. Under RTL the frozen
                    // column pins to the right rather than the left.
                    frozenCells: const FrozenTableData(
                      frozenRows: [TableRef(0)],
                      frozenColumns: [TableRef(0)],
                    ),
                    rows: [
                      TableHeader(
                        cells: [
                          buildCell('Invoice', highlight: true),
                          buildCell('Status'),
                          buildCell('Method'),
                          buildCell('Amount'),
                          buildCell('Verification'),
                          buildCell('Last Updated'),
                        ],
                      ),
                      for (final row in const [
                        [
                          'INV001',
                          'Paid',
                          'Credit Card',
                          '250.00',
                          'Verified',
                          '2 hours ago',
                        ],
                        [
                          'INV002',
                          'Pending',
                          'PayPal',
                          '150.00',
                          'Pending',
                          '1 day ago',
                        ],
                        [
                          'INV003',
                          'Unpaid',
                          'Bank Transfer',
                          '350.00',
                          'Unverified',
                          '1 week ago',
                        ],
                        [
                          'INV004',
                          'Paid',
                          'Credit Card',
                          '450.00',
                          'Verified',
                          '2 weeks ago',
                        ],
                        [
                          'INV005',
                          'Paid',
                          'PayPal',
                          '550.00',
                          'Verified',
                          '3 weeks ago',
                        ],
                        [
                          'INV006',
                          'Pending',
                          'Bank Transfer',
                          '200.00',
                          'Pending',
                          '1 month ago',
                        ],
                      ])
                        TableRow(
                          cells: [
                            buildCell(row[0], highlight: true),
                            buildCell(row[1]),
                            buildCell(row[2]),
                            buildCell('\$${row[3]}'),
                            buildCell(row[4]),
                            buildCell(row[5]),
                          ],
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

```

### Table Tile
```dart
import 'package:docs/pages/docs/components_page.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

class TableTile extends StatelessWidget implements IComponentPage {
  const TableTile({super.key});

  @override
  String get title => 'Table';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ComponentCard(
      name: 'table',
      title: 'Table',
      scale: 1.2,
      example: Card(
        child: Container(
          width: 400,
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.border),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.muted,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 2, child: const Text('Name').bold()),
                    Expanded(flex: 2, child: const Text('Role').bold()),
                    Expanded(flex: 1, child: const Text('Status').bold()),
                  ],
                ),
              ),
              // Rows
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Expanded(flex: 2, child: Text('John Doe')),
                    const Expanded(flex: 2, child: Text('Developer')),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(theme: DividerTheme(height: 1)),
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Expanded(flex: 2, child: Text('Jane Smith')),
                    const Expanded(flex: 2, child: Text('Designer')),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Away',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(theme: DividerTheme(height: 1)),
              Container(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Expanded(flex: 2, child: Text('Bob Johnson')),
                    const Expanded(flex: 2, child: Text('Manager')),
                    Expanded(
                      flex: 1,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

```



## Features
- **Cell Spanning**: Support for colspan and rowspan across multiple cells
- **Flexible Sizing**: Multiple sizing strategies (fixed, flex, intrinsic) for columns/rows
- **Frozen Cells**: Ability to freeze specific cells during scrolling
- **Interactive States**: Hover effects and selection states with visual feedback
- **Scrolling**: Optional horizontal and vertical scrolling with viewport control
- **Theming**: Comprehensive theming system for visual customization

## Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `rows` | `List<TableRow>?` | List of rows to display in the table.  Type: `List<TableRow>?`. Contains the table data organized as rows. Can include [TableRow], [TableHeader], and [TableFooter] instances. Each row contains a list of [TableCell] widgets. |
| `defaultColumnWidth` | `TableSize` | Default sizing strategy for all columns.  Type: `TableSize`. Used when no specific width is provided in [columnWidths]. Defaults to [FlexTableSize] for proportional sizing. |
| `defaultRowHeight` | `TableSize` | Default sizing strategy for all rows.  Type: `TableSize`. Used when no specific height is provided in [rowHeights]. Defaults to [IntrinsicTableSize] for content-based sizing. |
| `columnWidths` | `Map<int, TableSize>?` | Specific column width overrides.  Type: `Map<int, TableSize>?`. Maps column indices to specific sizing strategies. Overrides [defaultColumnWidth] for specified columns. |
| `rowHeights` | `Map<int, TableSize>?` | Specific row height overrides.  Type: `Map<int, TableSize>?`. Maps row indices to specific sizing strategies. Overrides [defaultRowHeight] for specified rows. |
| `clipBehavior` | `Clip` | Clipping behavior for the table content.  Type: `Clip`. Controls how content is clipped at table boundaries. Defaults to [Clip.hardEdge] for clean boundaries. |
| `theme` | `TableTheme?` | Styling for this widget alone. Takes precedence over any `T` an ancestor [ComponentTheme] provides: when this is non-null the ancestor is not consulted at all, so a field left null here falls back to the component's built-in default rather than to the ancestor's value. To adjust an ancestor theme instead of replacing it, read it with [ComponentTheme.maybeOf] and `copyWith` the result. Prefer this over the per-property constructor arguments, which are deprecated. |
| `frozenCells` | `FrozenTableData?` | Configuration for frozen cells during scrolling.  Type: `FrozenTableData?`. Specifies which cells remain visible during horizontal or vertical scrolling. Useful for headers/footers. |
| `horizontalOffset` | `double?` | Horizontal scroll offset for the table viewport.  Type: `double?`. Controls horizontal scrolling position. If provided, the table displays within a scrollable viewport. |
| `verticalOffset` | `double?` | Vertical scroll offset for the table viewport.  Type: `double?`. Controls vertical scrolling position. If provided, the table displays within a scrollable viewport. |
| `viewportSize` | `Size?` | Size constraints for the table viewport.  Type: `Size?`. When provided with scroll offsets, constrains the visible area of the table. Essential for scrolling behavior. |
| `verticalController` | `ScrollController?` | Optional controller for vertical scrolling owned by this [Table].  When provided, the table wraps itself in a [ScrollableClient] and drives [verticalOffset]/[viewportSize] internally from this controller instead of requiring the caller to wire up their own [ScrollableClient]/[Scrollable] and pass [verticalOffset] manually. If both this and [verticalOffset] are provided, [verticalOffset] is ignored for the vertical axis. |
| `horizontalController` | `ScrollController?` | Optional controller for horizontal scrolling owned by this [Table].  Same semantics as [verticalController], for the horizontal axis. |
| `textDirection` | `TextDirection?` | The direction columns run in.  Defaults to the ambient [Directionality]. Column indices are always logical — [columnWidths] key 0, [FrozenTableData.frozenColumns] index 0 and [TableRow.cells] position 0 all refer to the first column — so under [TextDirection.rtl] that column is laid out at the right edge, frozen columns pin to the right, and horizontal scrolling starts there and runs leftwards. |
