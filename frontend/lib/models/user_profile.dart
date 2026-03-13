enum SubscriptionTier { free, premium }

class TierLimits {
  final int? maxLists;
  final int? maxTasksPerList;
  final int maxRemindersPerTask;
  final int? maxHabits;

  const TierLimits({
    this.maxLists,
    this.maxTasksPerList,
    this.maxRemindersPerTask = 2,
    this.maxHabits,
  });

  static const free = TierLimits(
    maxLists: 9,
    maxTasksPerList: 19,
    maxRemindersPerTask: 2,
    maxHabits: 5,
  );

  static const premium = TierLimits(
    maxLists: null,
    maxTasksPerList: null,
    maxRemindersPerTask: 5,
    maxHabits: null,
  );

  factory TierLimits.fromMap(Map<String, dynamic> map) {
    return TierLimits(
      maxLists: map['maxLists'] as int?,
      maxTasksPerList: map['maxTasksPerList'] as int?,
      maxRemindersPerTask: map['maxRemindersPerTask'] as int? ?? 2,
      maxHabits: map['maxHabits'] as int?,
    );
  }
}

class UserProfile {
  final SubscriptionTier tier;
  final bool isPremium;
  final TierLimits limits;
  final String? subscriptionStatus;
  final DateTime? subscriptionEndDate;

  const UserProfile({
    this.tier = SubscriptionTier.free,
    this.isPremium = false,
    this.limits = TierLimits.free,
    this.subscriptionStatus,
    this.subscriptionEndDate,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    final tier = map['tier'] == 'premium'
        ? SubscriptionTier.premium
        : SubscriptionTier.free;
    return UserProfile(
      tier: tier,
      isPremium: map['isPremium'] as bool? ?? false,
      limits: map['limits'] != null
          ? TierLimits.fromMap(map['limits'] as Map<String, dynamic>)
          : (tier == SubscriptionTier.premium
              ? TierLimits.premium
              : TierLimits.free),
      subscriptionStatus: map['subscriptionStatus'] as String?,
      subscriptionEndDate: map['subscriptionEndDate'] != null
          ? DateTime.tryParse(map['subscriptionEndDate'] as String)
          : null,
    );
  }
}
