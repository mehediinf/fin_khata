import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../finance/presentation/providers/finance_controller.dart';

final appLockControllerProvider =
    NotifierProvider<AppLockController, AppLockState>(AppLockController.new);

class AppLockState {
  const AppLockState({
    this.checking = true,
    this.pinEnabled = false,
    this.locked = false,
  });

  /// True while the initial PIN check (secure storage read) is in flight.
  final bool checking;
  final bool pinEnabled;
  final bool locked;

  AppLockState copyWith({bool? checking, bool? pinEnabled, bool? locked}) =>
      AppLockState(
        checking: checking ?? this.checking,
        pinEnabled: pinEnabled ?? this.pinEnabled,
        locked: locked ?? this.locked,
      );
}

class AppLockController extends Notifier<AppLockState> {
  @override
  AppLockState build() {
    Future.microtask(_checkInitialLock);
    return const AppLockState();
  }

  Future<void> _checkInitialLock() async {
    final hasPin = await ref.read(securityServiceProvider).hasPin;
    state = AppLockState(checking: false, pinEnabled: hasPin, locked: hasPin);
  }

  /// Re-reads PIN status after the user sets or removes a PIN from settings.
  /// Does not re-lock an already-unlocked session just because a PIN was set.
  Future<void> refreshPinStatus() async {
    final hasPin = await ref.read(securityServiceProvider).hasPin;
    state = state.copyWith(
      pinEnabled: hasPin,
      locked: hasPin ? state.locked : false,
    );
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await ref.read(securityServiceProvider).verifyPin(pin);
    if (ok) state = state.copyWith(locked: false);
    return ok;
  }

  Future<bool> unlockWithBiometric() async {
    final ok = await ref.read(securityServiceProvider).authenticateBiometric();
    if (ok) state = state.copyWith(locked: false);
    return ok;
  }

  /// Called when the app is backgrounded; no-op if no PIN is set.
  void lockNow() {
    if (state.pinEnabled && !state.locked) {
      state = state.copyWith(locked: true);
    }
  }
}
