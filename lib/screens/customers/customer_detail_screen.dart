import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_theme.dart';
import '../../models/customer.dart';
import '../../widgets/app_card.dart';

class CustomerDetailScreen extends StatelessWidget {
  final CustomerModel customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(customer.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Card
          AppCard(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    customer.name.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  customer.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (customer.phone != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    customer.phone!,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (customer.phone != null)
                      ElevatedButton.icon(
                        onPressed: () => launchUrl(Uri.parse('tel:${customer.phone}')),
                        icon: const Icon(Icons.phone, size: 16),
                        label: const Text('Call'),
                      ),
                    const SizedBox(width: 12),
                    if (customer.email != null)
                      OutlinedButton.icon(
                        onPressed: () => launchUrl(Uri.parse('mailto:${customer.email}')),
                        icon: const Icon(Icons.email, size: 16),
                        label: const Text('Email'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Lifetime Stats
          Row(
            children: [
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Spend', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text(
                        customer.formattedSpend,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total Orders', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 4),
                      Text(
                        '${customer.orderCount}',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Address & Notes
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 8),
                Text(
                  customer.address ?? 'No address registered.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                if (customer.notes != null && customer.notes!.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text('Merchant Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 8),
                  Text(
                    customer.notes!,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
