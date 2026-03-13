import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/user_profile.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

final subscriptionProvider = StreamProvider<UserProfile>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(const UserProfile());

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .map((snap) {
    if (!snap.exists || snap.data() == null) {
      return const UserProfile();
    }
    final data = snap.data()!;
    final tier = data['subscriptionTier'] == 'premium'
        ? SubscriptionTier.premium
        : SubscriptionTier.free;
    final isPremium =
        tier == SubscriptionTier.premium &&
        (data['subscriptionStatus'] == null ||
            data['subscriptionStatus'] == 'active');
    return UserProfile(
      tier: tier,
      isPremium: isPremium,
      limits: isPremium ? TierLimits.premium : TierLimits.free,
      subscriptionStatus: data['subscriptionStatus'] as String?,
      subscriptionEndDate: data['subscriptionEndDate'] != null
          ? DateTime.tryParse(data['subscriptionEndDate'] as String)
          : null,
    );
  });
});

final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).value?.isPremium ?? false;
});

final tierLimitsProvider = Provider<TierLimits>((ref) {
  return ref.watch(subscriptionProvider).value?.limits ?? TierLimits.free;
});
