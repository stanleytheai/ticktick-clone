import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ticktick_clone/models/pomodoro_session.dart';
import 'package:ticktick_clone/providers/auth_provider.dart';

// Pomodoro settings (persisted in memory for now)
final pomodoroSettingsProvider =
    StateProvider<PomodoroSettings>((ref) => const PomodoroSettings());

// Stream of pomodoro session history
final pomodoroHistoryProvider = StreamProvider<List<PomodoroSession>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value([]);
  return ref.watch(firestoreServiceProvider).watchPomodoroSessions(user.uid);
});

// Today's completed work sessions
final todayFocusMinutesProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(0);
  return ref
      .watch(firestoreServiceProvider)
      .watchTodayPomodoroSessions(user.uid)
      .map((sessions) => sessions
          .where((s) =>
              s.completed && s.sessionType == PomodoroSessionType.work)
          .fold<int>(0, (sum, s) => sum + s.durationMinutes));
});

// Today's completed work session count
final todaySessionCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(0);
  return ref
      .watch(firestoreServiceProvider)
      .watchTodayPomodoroSessions(user.uid)
      .map((sessions) => sessions
          .where((s) =>
              s.completed && s.sessionType == PomodoroSessionType.work)
          .length);
});

// Active pomodoro timer state
enum TimerState { idle, running, paused }

class PomodoroTimerState {
  final TimerState state;
  final PomodoroSessionType sessionType;
  final int remainingSeconds;
  final int totalSeconds;
  final String? taskId;
  final String? activeSessionId;
  final int completedWorkSessions; // count in current cycle
  final List<AmbientSound> selectedSounds;

  const PomodoroTimerState({
    this.state = TimerState.idle,
    this.sessionType = PomodoroSessionType.work,
    this.remainingSeconds = 25 * 60,
    this.totalSeconds = 25 * 60,
    this.taskId,
    this.activeSessionId,
    this.completedWorkSessions = 0,
    this.selectedSounds = const [],
  });

  PomodoroTimerState copyWith({
    TimerState? state,
    PomodoroSessionType? sessionType,
    int? remainingSeconds,
    int? totalSeconds,
    String? taskId,
    bool clearTaskId = false,
    String? activeSessionId,
    bool clearActiveSessionId = false,
    int? completedWorkSessions,
    List<AmbientSound>? selectedSounds,
  }) {
    return PomodoroTimerState(
      state: state ?? this.state,
      sessionType: sessionType ?? this.sessionType,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      totalSeconds: totalSeconds ?? this.totalSeconds,
      taskId: clearTaskId ? null : (taskId ?? this.taskId),
      activeSessionId: clearActiveSessionId
          ? null
          : (activeSessionId ?? this.activeSessionId),
      completedWorkSessions:
          completedWorkSessions ?? this.completedWorkSessions,
      selectedSounds: selectedSounds ?? this.selectedSounds,
    );
  }

  double get progress {
    if (totalSeconds == 0) return 0;
    return 1.0 - (remainingSeconds / totalSeconds);
  }

  String get timeDisplay {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class PomodoroTimerNotifier extends StateNotifier<PomodoroTimerState> {
  PomodoroTimerNotifier(this._ref) : super(const PomodoroTimerState()) {
    _syncWithSettings();
  }

  final Ref _ref;
  Timer? _timer;

  void _syncWithSettings() {
    final settings = _ref.read(pomodoroSettingsProvider);
    state = state.copyWith(
      remainingSeconds: settings.workMinutes * 60,
      totalSeconds: settings.workMinutes * 60,
    );
  }

  void start() {
    if (state.state == TimerState.running) return;

    final user = _ref.read(currentUserProvider);
    if (user == null) return;

    if (state.state == TimerState.idle) {
      // Create a new session in Firestore
      final now = DateTime.now();
      final settings = _ref.read(pomodoroSettingsProvider);
      final duration = switch (state.sessionType) {
        PomodoroSessionType.work => settings.workMinutes,
        PomodoroSessionType.shortBreak => settings.shortBreakMinutes,
        PomodoroSessionType.longBreak => settings.longBreakMinutes,
      };

      final session = PomodoroSession(
        id: '',
        taskId: state.taskId,
        sessionType: state.sessionType,
        durationMinutes: duration,
        startTime: now,
        completed: false,
        ambientSounds: state.selectedSounds.map((s) => s.value).toList(),
        createdAt: now,
        updatedAt: now,
      );

      _ref
          .read(firestoreServiceProvider)
          .startPomodoroSession(user.uid, session)
          .then((created) {
        state = state.copyWith(activeSessionId: created.id);
      });

      state = state.copyWith(
        state: TimerState.running,
        remainingSeconds: duration * 60,
        totalSeconds: duration * 60,
      );
    } else {
      // Resume from paused
      state = state.copyWith(state: TimerState.running);
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (state.remainingSeconds <= 0) {
      _onComplete();
      return;
    }
    state = state.copyWith(remainingSeconds: state.remainingSeconds - 1);
  }

  void _onComplete() {
    _timer?.cancel();
    _timer = null;

    final user = _ref.read(currentUserProvider);
    if (user != null && state.activeSessionId != null) {
      _ref
          .read(firestoreServiceProvider)
          .stopPomodoroSession(user.uid, state.activeSessionId!, true);
    }

    final settings = _ref.read(pomodoroSettingsProvider);
    final wasWork = state.sessionType == PomodoroSessionType.work;
    final newWorkCount =
        wasWork ? state.completedWorkSessions + 1 : state.completedWorkSessions;

    // Determine next session type
    PomodoroSessionType nextType;
    if (wasWork) {
      if (newWorkCount % settings.sessionsUntilLongBreak == 0) {
        nextType = PomodoroSessionType.longBreak;
      } else {
        nextType = PomodoroSessionType.shortBreak;
      }
    } else {
      nextType = PomodoroSessionType.work;
    }

    final nextDuration = switch (nextType) {
      PomodoroSessionType.work => settings.workMinutes,
      PomodoroSessionType.shortBreak => settings.shortBreakMinutes,
      PomodoroSessionType.longBreak => settings.longBreakMinutes,
    };

    state = state.copyWith(
      state: TimerState.idle,
      sessionType: nextType,
      remainingSeconds: nextDuration * 60,
      totalSeconds: nextDuration * 60,
      completedWorkSessions: newWorkCount,
      clearActiveSessionId: true,
    );

    // Auto-start next session if enabled
    if (settings.autoStartNext) {
      start();
    }
  }

  void pause() {
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(state: TimerState.paused);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;

    final user = _ref.read(currentUserProvider);
    if (user != null && state.activeSessionId != null) {
      _ref
          .read(firestoreServiceProvider)
          .stopPomodoroSession(user.uid, state.activeSessionId!, false);
    }

    final settings = _ref.read(pomodoroSettingsProvider);
    state = PomodoroTimerState(
      taskId: state.taskId,
      selectedSounds: state.selectedSounds,
      remainingSeconds: settings.workMinutes * 60,
      totalSeconds: settings.workMinutes * 60,
    );
  }

  void setTaskId(String? taskId) {
    state = state.copyWith(taskId: taskId, clearTaskId: taskId == null);
  }

  void setSessionType(PomodoroSessionType type) {
    if (state.state != TimerState.idle) return;
    final settings = _ref.read(pomodoroSettingsProvider);
    final duration = switch (type) {
      PomodoroSessionType.work => settings.workMinutes,
      PomodoroSessionType.shortBreak => settings.shortBreakMinutes,
      PomodoroSessionType.longBreak => settings.longBreakMinutes,
    };
    state = state.copyWith(
      sessionType: type,
      remainingSeconds: duration * 60,
      totalSeconds: duration * 60,
    );
  }

  void toggleSound(AmbientSound sound) {
    final current = List<AmbientSound>.from(state.selectedSounds);
    if (current.contains(sound)) {
      current.remove(sound);
    } else {
      current.add(sound);
    }
    state = state.copyWith(selectedSounds: current);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final pomodoroTimerProvider =
    StateNotifierProvider<PomodoroTimerNotifier, PomodoroTimerState>((ref) {
  return PomodoroTimerNotifier(ref);
});
