import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/billing/subscription_service.dart';
import '../../../family/presentation/providers/family_providers.dart';

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

/// True once the current family's last-verified subscription state is
/// active and unexpired — see `Family.isPremium` for the exact logic.
/// Everything that gates a premium feature should watch this, not
/// `currentFamilyProvider` directly, so the gate logic stays in one place.
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(currentFamilyProvider).valueOrNull?.isPremium ?? false;
});
