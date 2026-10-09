import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase/supabase_client.dart';
import '../../core/theme/colors.dart';
import '../../skeleton_loading/store_skeleton.dart';

enum _ProductKind { book, pack }

class _StoreProduct {
  final String id;
  final String slug;
  final String title;
  final String? subtitle;
  final String? coverUrl;
  final String? targetExam;
  final String? classLevel;
  final double price;
  final double? originalPrice;
  final _ProductKind kind;

  const _StoreProduct({
    required this.id,
    required this.slug,
    required this.title,
    required this.subtitle,
    required this.coverUrl,
    required this.targetExam,
    required this.classLevel,
    required this.price,
    required this.originalPrice,
    required this.kind,
  });

  factory _StoreProduct.book(Map<String, dynamic> row) => _StoreProduct(
    id: row['id'] as String,
    slug: row['slug'] as String,
    title: row['title'] as String? ?? 'Bansal Book',
    subtitle: row['author'] as String?,
    coverUrl: row['cover_url'] as String?,
    targetExam: row['target_exam'] as String?,
    classLevel: row['class_level'] as String?,
    price: (row['price'] as num?)?.toDouble() ?? 0,
    originalPrice: (row['original_price'] as num?)?.toDouble(),
    kind: _ProductKind.book,
  );

  factory _StoreProduct.pack(Map<String, dynamic> row) => _StoreProduct(
    id: row['id'] as String,
    slug: row['slug'] as String,
    title: row['title'] as String? ?? 'Bansal Module Pack',
    subtitle: 'Module Pack',
    coverUrl: row['cover_url'] as String?,
    targetExam: row['target_exam'] as String?,
    classLevel: row['class_level'] as String?,
    price: (row['price'] as num?)?.toDouble() ?? 0,
    originalPrice: (row['original_price'] as num?)?.toDouble(),
    kind: _ProductKind.pack,
  );

  Uri get webUri => Uri.parse(
    kind == _ProductKind.book
        ? 'https://www.bansal.ac.in/e-store/$slug'
        : 'https://www.bansal.ac.in/e-store/pack/$slug',
  );
}

class _StoreCatalog {
  final List<_StoreProduct> books;
  final List<_StoreProduct> packs;

  const _StoreCatalog({required this.books, required this.packs});
}

final _storeCatalogProvider = FutureProvider.autoDispose<_StoreCatalog>((
  ref,
) async {
  final client = supabaseOrNull;
  if (client == null) throw Exception('Store is not available right now.');

  final bookRows = await client
      .from('books')
      .select(
        'id,slug,title,author,cover_url,target_exam,class_level,price,original_price',
      )
      .eq('is_published', true)
      .order('sort_order')
      .order('created_at', ascending: false);
  final packRows = await client
      .from('module_packs')
      .select(
        'id,slug,title,cover_url,target_exam,class_level,price,original_price',
      )
      .eq('is_published', true)
      .order('sort_order');

  return _StoreCatalog(
    books: (bookRows as List)
        .map((row) => _StoreProduct.book(Map<String, dynamic>.from(row as Map)))
        .toList(),
    packs: (packRows as List)
        .map((row) => _StoreProduct.pack(Map<String, dynamic>.from(row as Map)))
        .toList(),
  );
});

// ── Design tokens (Figma) ─────────────────────────────────────────────────
const _ink = AppColors.ink;
const _soft = Color(0xFF6B7280);
const _peachBand = Color(0xFFFCE6D2);
const _peachChip = Color(0xFFFDEEDC);
const _blueChip = Color(0xFFE6EDF8);
const _cardInfo = Color(0xFFE9F0FB);
const _heroTagline = Color(0xFFF7C948);
const _shadow = [
  BoxShadow(color: Color(0x1F102A5C), blurRadius: 14, offset: Offset(0, 5)),
];

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  _ProductKind _selectedKind = _ProductKind.book;
  String _search = '';

  /// Selected `target_exam` (upper-cased); null means "All".
  String? _category;

  Future<void> _openProduct(_StoreProduct product) async {
    final opened = await launchUrl(
      product.webUri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the product page.')),
      );
    }
  }

  static String? _examKey(_StoreProduct p) {
    final exam = p.targetExam?.trim();
    return exam == null || exam.isEmpty ? null : exam.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(_storeCatalogProvider);

    return catalog.when(
      loading: () => const StoreSkeleton(),
      error: (error, stackTrace) =>
          _StoreError(onRetry: () => ref.invalidate(_storeCatalogProvider)),
      data: (data) {
        final source = _selectedKind == _ProductKind.book
            ? data.books
            : data.packs;

        // Categories come from the products' own exam tags, in first-seen order.
        final categories = <String>[];
        for (final p in source) {
          final key = _examKey(p);
          if (key != null && !categories.contains(key)) categories.add(key);
        }
        final category = categories.contains(_category) ? _category : null;

        final query = _search.trim().toLowerCase();
        final products = source.where((product) {
          if (category != null && _examKey(product) != category) return false;
          if (query.isEmpty) return true;
          return product.title.toLowerCase().contains(query) ||
              (product.subtitle?.toLowerCase().contains(query) ?? false);
        }).toList();

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(_storeCatalogProvider.future),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Books & Modules',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _StoreHero(),
                      const SizedBox(height: 22),
                      _SearchBar(
                        hint: _selectedKind == _ProductKind.book
                            ? 'Search books or authors'
                            : 'Search module packs',
                        onChanged: (value) => setState(() => _search = value),
                      ),
                      const SizedBox(height: 26),
                      const _SectionTitle('Categories'),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _CategoryBand(
                  categories: categories,
                  selected: category,
                  onSelected: (value) => setState(() => _category = value),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StoreTabs(
                        selected: _selectedKind,
                        onChanged: (kind) => setState(() {
                          _selectedKind = kind;
                          _category = null;
                        }),
                      ),
                      const SizedBox(height: 30),
                      const _SectionTitle('Recommended for you'),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
              if (products.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyStore(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  sliver: SliverGrid.builder(
                    itemCount: products.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                          childAspectRatio: 0.56,
                        ),
                    itemBuilder: (context, index) => _ProductCard(
                      product: products[index],
                      onTap: () => _openProduct(products[index]),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: _ink,
      letterSpacing: 0.2,
    ),
  );
}

// ── Hero ──────────────────────────────────────────────────────────────────
class _StoreHero extends StatelessWidget {
  const _StoreHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 24, 26),
      decoration: BoxDecoration(
        color: AppColors.deepNavy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33102A5C),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'BANSAL E-STORE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Study smarter with trusted material',
                  style: TextStyle(
                    color: _heroTagline,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(LucideIcons.archive200, color: Colors.white, size: 40),
        ],
      ),
    );
  }
}

// ── Search ────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: _shadow,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0x29000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(LucideIcons.search, size: 18, color: _soft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 13, color: _ink),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CA3AF),
                ),
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category chips on a full-width peach band ─────────────────────────────
class _CategoryBand extends StatelessWidget {
  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  const _CategoryBand({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _peachBand.withValues(alpha: 0.7),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _CategoryChip(
              label: 'All',
              selected: selected == null,
              style: _ChipStyle.blue,
              onTap: () => onSelected(null),
            ),
            for (var i = 0; i < categories.length; i++) ...[
              const SizedBox(width: 18),
              _CategoryChip(
                label: categories[i],
                selected: selected == categories[i],
                // Alternate blue / peach like the design.
                style: i % 3 == 1 ? _ChipStyle.peach : _ChipStyle.blue,
                onTap: () => onSelected(categories[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ChipStyle { blue, peach }

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final _ChipStyle style;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final peach = style == _ChipStyle.peach;
    final bg = selected ? AppColors.primary : (peach ? _peachChip : _blueChip);
    final fg = selected
        ? Colors.white
        : (peach ? AppColors.orange : AppColors.primary);
    final border = selected
        ? AppColors.primary
        : (peach ? AppColors.orange.withValues(alpha: 0.5) : Colors.white);

    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minWidth: 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A102A5C),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: fg,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Books / Module Packs toggle ───────────────────────────────────────────
class _StoreTabs extends StatelessWidget {
  final _ProductKind selected;
  final ValueChanged<_ProductKind> onChanged;

  const _StoreTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: const Color(0xFFD1D5DB)),
      boxShadow: _shadow,
    ),
    child: Row(
      children: [
        _TabButton(
          label: 'Books',
          icon: LucideIcons.bookOpen,
          selected: selected == _ProductKind.book,
          onTap: () => onChanged(_ProductKind.book),
        ),
        _TabButton(
          label: 'Module Packs',
          icon: LucideIcons.archive,
          selected: selected == _ProductKind.pack,
          onTap: () => onChanged(_ProductKind.pack),
        ),
      ],
    ),
  );
}

class _TabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : _soft;
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Align(
            // Selected segment hugs its content, like the design.
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: selected ? AppColors.orange : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              // Shrinks slightly on narrow phones so "Module Packs" is never
              // cut off.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 17, color: color),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      maxLines: 1,
                      style: TextStyle(
                        color: color,
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Product card ──────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final _StoreProduct product;
  final VoidCallback onTap;

  const _ProductCard({required this.product, required this.onTap});

  String _price(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final hasDiscount =
        product.originalPrice != null && product.originalPrice! > product.price;
    final tag = product.targetExam?.trim().isNotEmpty == true
        ? product.targetExam!.trim().toUpperCase()
        : (product.kind == _ProductKind.pack ? 'MODULE PACK' : null);
    final author = product.subtitle?.isNotEmpty == true
        ? product.subtitle!
        : (product.classLevel ?? 'Bansal Classes');

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: _shadow,
      ),
      child: Material(
        color: _cardInfo,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ColoredBox(
                  color: const Color(0xFFFFF4EB),
                  child: product.coverUrl?.isNotEmpty == true
                      ? Image.network(
                          product.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              _ProductPlaceholder(kind: product.kind),
                        )
                      : _ProductPlaceholder(kind: product.kind),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 13, child: tag != null ? _Tag(tag) : null),
                    const SizedBox(height: 4),
                    // Always three lines tall so long titles show in full
                    // and neighbouring cards keep equal cover heights.
                    Text(
                      '${product.title}\n\n',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // One line that scales down instead of cutting the name.
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        author,
                        maxLines: 1,
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${_price(product.price)}',
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 5),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 1),
                            child: Text(
                              '₹${_price(product.originalPrice!)}',
                              style: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 9.5,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Tooltip(
                          message: 'Buy on website',
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.orange,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              LucideIcons.shoppingCart,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View on website',
                          style: TextStyle(color: _ink, fontSize: 11.5),
                        ),
                        SizedBox(width: 6),
                        Icon(LucideIcons.arrowUpRight, color: _ink, size: 12),
                      ],
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

class _Tag extends StatelessWidget {
  final String label;
  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    // Advanced-level tags are highlighted in orange, the rest stay neutral.
    final accent = label.contains('ADV');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: accent ? const Color(0xFFFCD9B8) : const Color(0xFFD9DEE7),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: accent ? AppColors.orange : _soft,
          fontSize: 7,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ProductPlaceholder extends StatelessWidget {
  final _ProductKind kind;
  const _ProductPlaceholder({required this.kind});

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      kind == _ProductKind.book ? LucideIcons.bookOpen : LucideIcons.archive,
      size: 44,
      color: AppColors.orange,
    ),
  );
}

class _EmptyStore extends StatelessWidget {
  const _EmptyStore();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 32),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.packageOpen, size: 40, color: _soft),
        SizedBox(height: 10),
        Text(
          'No products found',
          style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
        ),
      ],
    ),
  );
}

class _StoreError extends StatelessWidget {
  final VoidCallback onRetry;
  const _StoreError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: _shadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.archive, size: 44, color: _soft),
          const SizedBox(height: 12),
          const Text(
            'Could not load the store.',
            style: TextStyle(fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(140, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            child: const Text('Try again'),
          ),
        ],
      ),
    ),
  );
}
