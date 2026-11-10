import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/app_theme.dart';
import '../../models/customer.dart';
import '../../providers/business_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import 'customer_detail_screen.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _searchController = TextEditingController();
  List<CustomerModel> _customers = [];
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCustomers() async {
    final biz = context.read<BusinessProvider>();
    if (biz.currentBusiness == null) return;
    final bId = biz.currentBusiness!.id;
    final api = context.read<ApiService>();

    setState(() => _isLoading = true);
    try {
      final res = await api.get(ApiConfig.pathCustomers(bId, limit: 100));
      if (res is Map && res['customers'] is List) {
        _customers = (res['customers'] as List)
            .map((c) => CustomerModel.fromJson(c as Map<String, dynamic>))
            .toList();
      } else if (res is List) {
        _customers = res.map((c) => CustomerModel.fromJson(c as Map<String, dynamic>)).toList();
      }
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  List<CustomerModel> get _filteredCustomers {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _customers;
    return _customers.where((c) {
      final n = c.name.toLowerCase();
      final p = (c.phone ?? '').toLowerCase();
      final e = (c.email ?? '').toLowerCase();
      return n.contains(q) || p.contains(q) || e.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final list = _filteredCustomers;

    return Scaffold(
      appBar: AppBar(title: const Text('Customers CRM')),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            color: isDark ? AppTheme.surfaceDark : AppTheme.surfaceLight,
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search customer name or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _loadCustomers(),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? EmptyState(
                          icon: Icons.people_outline,
                          title: 'No Customers Yet',
                          description: 'Customers created through Messenger or web checkout will appear in this directory.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final c = list[index];

                            return AppCard(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => CustomerDetailScreen(customer: c),
                                  ),
                                );
                              },
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                                    child: Text(
                                      c.name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          c.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          c.phone ?? c.email ?? 'No contact',
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        c.formattedSpend,
                                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${c.orderCount} orders',
                                        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
