import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/business_provider.dart';
import '../../providers/products_provider.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _newCategoryController = TextEditingController();

  @override
  void dispose() {
    _newCategoryController.dispose();
    super.dispose();
  }

  void _showAddCategoryDialog() {
    _newCategoryController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Category'),
        content: TextField(
          controller: _newCategoryController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            hintText: 'e.g. Menswear, Electronics, Shoes',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = _newCategoryController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);

              final biz = context.read<BusinessProvider>();
              if (biz.currentBusiness != null) {
                await context.read<ProductsProvider>().createCategory(biz.currentBusiness!.id, name);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final biz = context.watch<BusinessProvider>();
    final prods = context.watch<ProductsProvider>();
    final currentStore = biz.currentBusiness;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Categories'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add Category',
            onPressed: _showAddCategoryDialog,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        onPressed: _showAddCategoryDialog,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('New Category'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (currentStore != null) {
            await prods.fetchCategories(currentStore.id);
          }
        },
        child: prods.categories.isEmpty
            ? EmptyState(
                icon: Icons.category_outlined,
                title: 'No Categories',
                description: 'Group your products into categories to help customers and AI discover items easily.',
                buttonText: 'Add Category',
                onButtonPressed: _showAddCategoryDialog,
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: prods.categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final cat = prods.categories[index];

                  return AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.folder_outlined, color: AppTheme.primaryColor),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                cat.name,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              if (cat.slug != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '/${cat.slug}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
