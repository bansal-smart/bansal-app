import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase/supabase_client.dart';

const _navy = Color(0xFF102A63);
const _blue = Color(0xFF193F8F);
const _orange = Color(0xFFF47B20);
const _background = Color(0xFFFFFBF8);

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

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen> {
  _ProductKind _selectedKind = _ProductKind.book;
  String _search = '';

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

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(_storeCatalogProvider);

    return ColoredBox(
      color: _background,
      child: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            _StoreError(onRetry: () => ref.invalidate(_storeCatalogProvider)),
        data: (data) {
          final source = _selectedKind == _ProductKind.book
              ? data.books
              : data.packs;
          final query = _search.trim().toLowerCase();
          final products = query.isEmpty
              ? source
              : source
                    .where(
                      (product) =>
                          product.title.toLowerCase().contains(query) ||
                          (product.subtitle?.toLowerCase().contains(query) ??
                              false),
                    )
                    .toList();

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(_storeCatalogProvider.future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(child: _StoreHero()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                    child: Column(
                      children: [
                        _StoreTabs(
                          selected: _selectedKind,
                          onChanged: (kind) =>
                              setState(() => _selectedKind = kind),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          onChanged: (value) => setState(() => _search = value),
                          decoration: InputDecoration(
                            hintText: _selectedKind == _ProductKind.book
                                ? 'Search books or authors'
                                : 'Search module packs',
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                          ),
                        ),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverGrid.builder(
                      itemCount: products.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.61,
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
      ),
    );
  }
}

class _StoreHero extends StatelessWidget {
  const _StoreHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_navy, _blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StoreBadge(),
                SizedBox(height: 12),
                Text(
                  'Books & Module Packs',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Study material created by Bansal Classes faculty.',
                  style: TextStyle(color: Color(0xFFDCE6FF), fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.local_mall_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreBadge extends StatelessWidget {
  const _StoreBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.storefront_rounded, size: 14, color: Colors.white),
        SizedBox(width: 6),
        Text(
          'Bansal E-Store',
          style: TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _StoreTabs extends StatelessWidget {
  final _ProductKind selected;
  final ValueChanged<_ProductKind> onChanged;

  const _StoreTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE5E7EB)),
    ),
    child: Row(
      children: [
        _TabButton(
          label: 'Books',
          icon: Icons.menu_book_rounded,
          selected: selected == _ProductKind.book,
          onTap: () => onChanged(_ProductKind.book),
        ),
        _TabButton(
          label: 'Module Packs',
          icon: Icons.inventory_2_rounded,
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
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _orange : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : const Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : const Color(0xFF6B7280),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
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
                padding: const EdgeInsets.all(11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.targetExam?.isNotEmpty == true ||
                        product.kind == _ProductKind.pack)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEEE1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          product.targetExam?.isNotEmpty == true
                              ? product.targetExam!
                              : 'Module Pack',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _orange,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    const SizedBox(height: 7),
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 13,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.subtitle?.isNotEmpty == true
                          ? product.subtitle!
                          : (product.classLevel ?? 'Bansal Classes'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '₹${_price(product.price)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (hasDiscount) ...[
                          const SizedBox(width: 5),
                          Text(
                            '₹${_price(product.originalPrice!)}',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 10,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Text(
                          'View on website',
                          style: TextStyle(
                            color: _blue,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 3),
                        Icon(Icons.open_in_new_rounded, color: _blue, size: 12),
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

class _ProductPlaceholder extends StatelessWidget {
  final _ProductKind kind;
  const _ProductPlaceholder({required this.kind});

  @override
  Widget build(BuildContext context) => Center(
    child: Icon(
      kind == _ProductKind.book
          ? Icons.menu_book_rounded
          : Icons.inventory_2_rounded,
      size: 48,
      color: _orange,
    ),
  );
}

class _EmptyStore extends StatelessWidget {
  const _EmptyStore();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inventory_2_outlined, size: 44, color: Color(0xFF9CA3AF)),
          SizedBox(height: 10),
          Text(
            'No products found',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );
}

class _StoreError extends StatelessWidget {
  final VoidCallback onRetry;
  const _StoreError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_outlined,
            size: 48,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load the store.',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
