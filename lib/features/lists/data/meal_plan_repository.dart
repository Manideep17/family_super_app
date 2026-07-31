import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/analytics/app_analytics.dart';
import '../../family/data/family_scope.dart';
import '../domain/meal_plan_week.dart';

class MealPlanRepository {
  MealPlanRepository({
    required FamilyScope scope,
    FirebaseAuth? auth,
  })  : _scope = scope,
        _auth = auth ?? FirebaseAuth.instance;

  final FamilyScope _scope;
  final FirebaseAuth _auth;

  Stream<MealPlanWeek> watchWeek(String weekId) {
    return _scope.mealPlans.doc(weekId).snapshots().map(
          (s) => s.exists ? MealPlanWeek.fromDoc(s) : MealPlanWeek.empty(weekId),
        );
  }

  Future<void> setMeal({
    required String weekId,
    required String day,
    required String slot,
    required String dish,
  }) async {
    final u = _auth.currentUser;
    if (u == null) throw StateError('Not signed in');
    final key = MealPlanWeek.keyFor(day, slot);
    final trimmed = dish.trim();
    final docRef = _scope.mealPlans.doc(weekId);
    // Deliberately not `set(..., merge: true)` with a nested map literal —
    // that would risk wiping every other day/slot key depending on SDK
    // merge semantics. Dot-notation `update()` unambiguously touches only
    // this one nested key; the doc just needs to exist first.
    final snap = await docRef.get();
    if (!snap.exists) {
      await docRef.set({
        'weekId': weekId,
        'meals': {key: trimmed},
        'updatedBy': u.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await docRef.update({
        'meals.$key': trimmed,
        'updatedBy': u.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    AppAnalytics.logEvent('meal_plan_updated');
  }
}
