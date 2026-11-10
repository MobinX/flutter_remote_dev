import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../models/product.dart';
import '../../providers/products_provider.dart';
import '../../widgets/app_card.dart';

class ProductFormScreen extends StatefulWidget {
  final String businessId;
  final ProductModel? product;

  const ProductFormScreen({
    super.key,
    required this.businessId,
    this.product,
  });

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _regularPriceController;
  late TextEditingController _stockController;
  late TextEditingController _skuController;
  late TextEditingController _imageUrlController;

  String? _selectedCategoryId;
  bool _isSaving = false;

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameController = TextEditingController(text: p?.name ?? '');
    _descController = TextEditingController(text: p?.description ?? '');
    _priceController = TextEditingController(text: p != null ? p.price.toStringAsFixed(0) : '');
    _regularPriceController = TextEditingController(text: p?.regularPrice != null ? p!.regularPrice!.toStringAsFixed(0) : '');
    _stockController = TextEditingController(text: p != null ? p.stock.toString() : '10');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? '');
    _selectedCategoryId = p?.categoryId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _regularPriceController.dispose();
    _stockController.dispose();
    _skuController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final prods = context.read<ProductsProvider>();

    final payload = {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
      'price': double.tryParse(_priceController.text) ?? 0.0,
      'regularPrice': _regularPriceController.text.trim().isNotEmpty ? double.tryParse(_regularPriceController.text) : null,
      'stock': int.tryParse(_stockController.text) ?? 0,
      'sku': _skuController.text.trim().isNotEmpty ? _skuController.text.trim() : null,
      'imageUrl': _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null,
      'categoryId': _selectedCategoryId,
    };

    bool ok;
    if (_isEditing) {
      ok = await prods.updateProduct(widget.businessId, widget.product!.id, payload);
    } else {
      ok = await prods.createProduct(widget.businessId, payload);
    }

    setState(() => _isSaving = false);

    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isEditing ? 'Product updated' : 'Product created')),
      );
      Navigator.pop(context);
    }
  }

  void _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product?'),
        content: const Text('Are you sure you want to remove this product from your catalog?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final prods = context.read<ProductsProvider>();
      final ok = await prods.deleteProduct(widget.businessId, widget.product!.id);
      if (ok && mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final prods = context.watch<ProductsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Product' : 'Add New Product'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.danger),
              onPressed: _delete,
            ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
        ),
        child: SafeArea(
          child: ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Update Product' : 'Save Product'),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Product Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Product Title *', hintText: 'e.g. Cotton Polo Shirt'),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter product title' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Description', hintText: 'Fabric details, sizes, colors...'),
                  ),
                  const SizedBox(height: 12),
                  if (prods.categories.isNotEmpty) ...[
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('No Category')),
                        ...prods.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                      ],
                      onChanged: (v) => setState(() => _selectedCategoryId = v),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Sale Price (৳) *'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Enter price' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _regularPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Regular Price (৳)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _stockController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Stock Units *'),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Enter stock count' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _skuController,
                          decoration: const InputDecoration(labelText: 'SKU Code', hintText: 'e.g. POLO-01'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Image & Media', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Primary Image URL',
                      hintText: 'https://...',
                      prefixIcon: Icon(Icons.link),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  if (_imageUrlController.text.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        color: Colors.grey.withValues(alpha: 0.1),
                        child: Image.network(
                          _imageUrlController.text.trim(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.image_not_supported_outlined, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
