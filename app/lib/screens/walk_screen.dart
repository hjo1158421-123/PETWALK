import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/walk.dart';
import '../services/dog_repository.dart';
import '../services/location_service.dart';
import '../services/simulated_location_service.dart';
import '../services/theme_controller.dart';
import '../services/walk_recorder.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/route_map.dart';
import '../widgets/stat_tile.dart';
import 'dog_picker_sheet.dart';
import 'walk_detail_screen.dart';

class WalkScreen extends StatelessWidget {
  const WalkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final recorder = context.watch<WalkRecorder>();

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: RouteMap(
              segments: recorder.segments,
              follow: recorder.state == RecorderState.recording,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _ThemeSwitchButton(),
                // 릴리스 빌드에는 들어가지 않는다. 가짜 좌표로 만든 기록이
                // 실제 사용자 이력에 섞이면 안 된다.
                if (kDebugMode) ...[
                  const SizedBox(height: 10),
                  const _SimulateWalkButton(),
                ],
                if (recorder.isActive) ...[
                  const SizedBox(height: 10),
                  _AccuracyBanner(recorder: recorder),
                ],
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: _ControlPanel(recorder: recorder),
          ),
        ],
      ),
    );
  }
}

/// 앱 전체 테마를 바꾸는 버튼. 산책 화면 최상단에 둔다.
///
/// 설정 화면 안쪽에 묻어 두면 두 안을 견줘 보기가 번거롭다. 지금은 어느
/// 쪽이 나은지 고르는 단계라 한 번에 눌러 보고 바로 비교할 수 있어야 한다.
/// 결정이 끝나면 "우리 아이" 탭의 설정 목록으로 옮길 자리다.
class _ThemeSwitchButton extends StatelessWidget {
  const _ThemeSwitchButton();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final tokens = PetWalkTokens.of(context);
    final next = controller.variant.next;

    return Material(
      color: Theme.of(context).cardTheme.color ?? Colors.white,
      elevation: tokens.usesHairline ? 0 : 3,
      shadowColor: const Color(0x224A3B31),
      borderRadius: BorderRadius.circular(tokens.buttonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.buttonRadius),
        onTap: controller.toggle,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.buttonRadius),
            border: tokens.usesHairline
                ? Border.all(color: tokens.hairline)
                : null,
          ),
          child: Row(
            children: [
              Icon(Icons.palette_outlined, size: 20, color: tokens.accentText),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.variant.label,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      '${next.label}(으)로 바꾸기',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: tokens.muted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.swap_horiz, size: 20, color: tokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// 실제로 걷지 않고 산책 기록 흐름을 확인하는 개발용 버튼.
///
/// 이 PC 에서는 에뮬레이터도 iOS 실기기도 쓸 수 없어서, 기록이 끝까지
/// 이어지는지 볼 방법이 이것뿐이다. `kDebugMode` 로 감싸 릴리스에서는
/// 보이지 않는다.
class _SimulateWalkButton extends StatelessWidget {
  const _SimulateWalkButton();

  @override
  Widget build(BuildContext context) {
    final recorder = context.watch<WalkRecorder>();
    final tokens = PetWalkTokens.of(context);
    final simulating = recorder.location is SimulatedLocationService;

    // 기록 중에는 출처를 바꿀 수 없다. 켜고 끄는 건 멈춰 있을 때만.
    final canToggle = recorder.state == RecorderState.idle;

    return Material(
      color: simulating
          ? const Color(0xFFFFE08A)
          : (Theme.of(context).cardTheme.color ?? Colors.white),
      elevation: tokens.usesHairline ? 0 : 3,
      shadowColor: const Color(0x224A3B31),
      borderRadius: BorderRadius.circular(tokens.buttonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(tokens.buttonRadius),
        onTap: canToggle ? () => _toggle(context, recorder, simulating) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.buttonRadius),
            border:
                tokens.usesHairline ? Border.all(color: tokens.hairline) : null,
          ),
          child: Row(
            children: [
              Icon(
                simulating ? Icons.science : Icons.science_outlined,
                size: 20,
                color: simulating ? const Color(0xFF7A5A00) : tokens.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      simulating ? '가짜 GPS 켜짐 (개발용)' : '가짜 GPS로 산책해 보기',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: simulating ? const Color(0xFF7A5A00) : null,
                          ),
                    ),
                    Text(
                      simulating
                          ? '아래 "산책 시작"을 누르면 저절로 걸어요'
                          : '실제로 걷지 않아도 기록이 쌓입니다',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: simulating
                                ? const Color(0xFF7A5A00)
                                : tokens.muted,
                          ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: simulating,
                onChanged: canToggle
                    ? (_) => _toggle(context, recorder, simulating)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(
      BuildContext context, WalkRecorder recorder, bool simulating) {
    final messenger = ScaffoldMessenger.of(context);
    final previous = recorder.location;

    if (simulating) {
      if (previous is SimulatedLocationService) previous.dispose();
      recorder.location = LocationService();
      messenger.showSnackBar(
        const SnackBar(content: Text('실제 GPS로 돌아왔어요.')),
      );
    } else {
      recorder.location = SimulatedLocationService();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('가짜 GPS로 바꿨어요. 여기서 만든 기록은 이력에 그대로 남으니 확인 후 지워 주세요.'),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }
}

/// GPS 신호 상태를 알려준다. 신호가 나쁘면 지점이 통째로 버려지므로
/// 사용자가 "왜 안 그려지지?" 하기 전에 미리 보여주는 편이 낫다.
class _AccuracyBanner extends StatelessWidget {
  const _AccuracyBanner({required this.recorder});

  final WalkRecorder recorder;

  @override
  Widget build(BuildContext context) {
    final acc = recorder.lastAccuracy;
    final scheme = Theme.of(context).colorScheme;

    final (String text, Color color, IconData icon) = switch (acc) {
      null => ('GPS 신호를 찾는 중이에요', scheme.tertiaryContainer, Icons.gps_not_fixed),
      final a when a <= 12 =>
        ('GPS 양호', scheme.surfaceContainerHighest, Icons.gps_fixed),
      final a when a <= 25 => (
          'GPS 신호 보통 (오차 약 ${a.round()}m)',
          scheme.surfaceContainerHighest,
          Icons.gps_fixed
        ),
      _ => ('GPS 신호 약함 - 경로가 끊길 수 있어요', scheme.errorContainer, Icons.gps_off),
    };

    return Card(
      color: color,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
          ],
        ),
      ),
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.recorder});

  final WalkRecorder recorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = PetWalkTokens.of(context);
    final minimal = tokens.variant == AppThemeVariant.minimal;

    final stats = [
      StatTile(
        label: minimal ? 'DISTANCE' : '거리',
        value: Fmt.distance(recorder.distanceM),
        emphasize: true,
        alignment:
            minimal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      ),
      StatTile(
        label: minimal ? 'TIME' : '시간',
        value: Fmt.duration(recorder.elapsedSec),
        emphasize: true,
        alignment:
            minimal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      ),
      StatTile(
        label: minimal ? 'PACE' : '페이스',
        value: Fmt.pace(recorder.avgSpeedMps),
        emphasize: true,
        alignment:
            minimal ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      ),
    ];

    return Container(
      // 1a 는 화면에서 떠 있는 둥근 카드, 1b 는 바닥에 붙어 선으로만
      // 나뉘는 면이다. 여백부터 다르다.
      margin: minimal
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: minimal ? theme.colorScheme.surface : Colors.white,
        borderRadius:
            minimal ? null : BorderRadius.circular(tokens.cardRadius + 2),
        border: minimal
            ? Border(top: BorderSide(color: tokens.hairline))
            : null,
        boxShadow: minimal
            ? null
            : const [
                BoxShadow(
                  color: Color(0x1F4A3B31),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (minimal)
              // 1b 는 수치 사이를 세로 1px 선으로 나눈다.
              IntrinsicHeight(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.symmetric(
                      horizontal: BorderSide(color: tokens.hairline),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    children: [
                      for (var i = 0; i < stats.length; i++)
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.only(left: i == 0 ? 0 : 14),
                            decoration: i == 0
                                ? null
                                : BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: tokens.hairline),
                                    ),
                                  ),
                            child: stats[i],
                          ),
                        ),
                    ],
                  ),
                ),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [for (final s in stats) s],
              ),
            if (recorder.isActive) ...[
              const SizedBox(height: 8),
              Text(
                '멈춰 있던 시간 '
                '${Fmt.duration(recorder.elapsedSec - recorder.movingSec)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 20),
            _buttons(context),
          ],
        ),
      ),
    );
  }

  Widget _buttons(BuildContext context) {
    const pad = EdgeInsets.symmetric(vertical: 16);

    switch (recorder.state) {
      case RecorderState.idle:
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => _start(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text('산책 시작'),
            style: FilledButton.styleFrom(padding: pad),
          ),
        );

      case RecorderState.starting:
      case RecorderState.saving:
        return const Padding(
          padding: pad,
          child: CircularProgressIndicator(),
        );

      case RecorderState.recording:
      case RecorderState.paused:
        final paused = recorder.state == RecorderState.paused;
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: paused ? recorder.resume : recorder.pause,
                icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                label: Text(paused ? '이어서' : '일시정지'),
                style: OutlinedButton.styleFrom(padding: pad),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => _stop(context),
                icon: const Icon(Icons.stop),
                label: const Text('종료'),
                style: FilledButton.styleFrom(padding: pad),
              ),
            ),
          ],
        );
    }
  }

  Future<void> _start(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    // 함께 나갈 아이를 고른다. 한 마리뿐이면 묻지 않는다 -- 매번 같은
    // 선택을 시키는 건 방해일 뿐이다.
    final dogs = await DogRepository().listDogs();
    var dogIds = <int>[for (final d in dogs) d.id!];
    if (dogs.length > 1 && context.mounted) {
      final picked = await showModalBottomSheet<List<int>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DogPickerSheet(dogs: dogs),
      );
      if (picked == null) return; // 취소
      dogIds = picked;
    }

    final readiness = await recorder.start(dogIds: dogIds);
    if (readiness == LocationReadiness.ready) return;

    final (String message, bool openable) = switch (readiness) {
      LocationReadiness.serviceDisabled => ('기기의 위치 서비스가 꺼져 있어요.', true),
      LocationReadiness.deniedForever =>
        ('위치 권한이 차단되어 있어요. 설정에서 허용해 주세요.', true),
      _ => ('산책을 기록하려면 위치 권한이 필요해요.', false),
    };

    messenger.showSnackBar(SnackBar(
      content: Text(message),
      action: !openable
          ? null
          : SnackBarAction(
              label: '설정 열기',
              onPressed: () {
                final svc = LocationService();
                if (readiness == LocationReadiness.serviceDisabled) {
                  svc.openLocationSettings();
                } else {
                  svc.openSettings();
                }
              },
            ),
    ));
  }

  Future<void> _stop(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final Walk? saved = await recorder.stop();

    if (saved == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('이동 거리가 너무 짧아 기록하지 않았어요.'),
      ));
      return;
    }

    navigator.push(MaterialPageRoute(
      builder: (_) => WalkDetailScreen(walkId: saved.id!, justFinished: true),
    ));
  }
}
