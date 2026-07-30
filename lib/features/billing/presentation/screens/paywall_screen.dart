import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../family/presentation/providers/family_providers.dart';
import '../providers/billing_providers.dart';

/// "Go Premium" screen — lists the monthly plan, launches the Play Billing
/// purchase flow, and hands the resulting purchase to the backend for
/// verification. See docs/BILLING_SETUP.md for what has to exist in Play
/// Console before this can find a real product to sell.
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  ProductDetails? _product;
  bool _loadingProduct = true;
  bool _purchasing = false;
  String? _error;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  void initState() {
    super.initState();
    final service = ref.read(subscriptionServiceProvider);
    _sub = service.purchaseUpdates.listen(_onPurchaseUpdates, onError: (_) {});
    _loadProduct();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    final product = await ref.read(subscriptionServiceProvider).queryPremiumProduct();
    if (!mounted) return;
    setState(() {
      _product = product;
      _loadingProduct = false;
      if (product == null) {
        _error = 'Premium isn\'t available yet in this build.';
      }
    });
  }

  Future<void> _onPurchaseUpdates(List<PurchaseDetails> purchases) async {
    final familyId = ref.read(currentFamilyIdProvider).valueOrNull;
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          setState(() => _purchasing = true);
          break;
        case PurchaseStatus.error:
          setState(() {
            _purchasing = false;
            _error = purchase.error?.message ?? 'Purchase failed.';
          });
          break;
        case PurchaseStatus.canceled:
          setState(() => _purchasing = false);
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (familyId == null || familyId.isEmpty) {
            setState(() {
              _purchasing = false;
              _error = 'Join or create a family before subscribing.';
            });
            break;
          }
          try {
            await ref.read(subscriptionServiceProvider).verifyWithBackend(
                  familyId: familyId,
                  purchase: purchase,
                );
            await ref.read(subscriptionServiceProvider).completePurchase(purchase);
            ref.invalidate(currentFamilyProvider);
            if (mounted) {
              setState(() => _purchasing = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Premium unlocked — thank you!')),
              );
              Navigator.of(context).maybePop();
            }
          } catch (e) {
            if (mounted) {
              setState(() {
                _purchasing = false;
                _error = 'Purchase succeeded but verification failed: $e. '
                    'Try "Restore purchases" below.';
              });
            }
          }
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPremium = ref.watch(isPremiumProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('FAM Premium')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          AppGradient(
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: scheme.primary, size: 32),
                  const SizedBox(height: 12),
                  Text(
                    'More intelligence, more room for memories',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  const _PerkRow(
                    icon: Icons.auto_stories_rounded,
                    label: 'AI-written weekly family digest',
                  ),
                  const _PerkRow(
                    icon: Icons.photo_library_rounded,
                    label: 'Expanded vault storage for photos & videos',
                  ),
                  const _PerkRow(
                    icon: Icons.quiz_rounded,
                    label: 'AI memory quizzes for game night',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (isPremium)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Colors.green.shade600),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Your family already has Premium.')),
                  ],
                ),
              ),
            )
          else if (_loadingProduct)
            const Center(child: CircularProgressIndicator())
          else if (_product != null)
            FilledButton(
              onPressed: _purchasing ? null : () => ref
                  .read(subscriptionServiceProvider)
                  .buyPremium(_product!)
                  .catchError((e) => setState(() => _error = '$e')),
              child: _purchasing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Subscribe — ${_product!.price}/month'),
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => ref.read(subscriptionServiceProvider).restorePurchases(),
            child: const Text('Restore purchases'),
          ),
        ],
      ),
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
        ],
      ),
    );
  }
}
