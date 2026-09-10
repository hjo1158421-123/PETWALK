import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/walk.dart';
import '../services/location_service.dart';
import '../services/walk_recorder.dart';
import '../utils/format.dart';
import '../widgets/route_map.dart';
import '../widgets/stat_tile.dart';
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
          if (recorder.isActive)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: _AccuracyBanner(recorder: recorder),
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

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StatTile(
                  label: '거리',
                  value: Fmt.distance(recorder.distanceM),
                  emphasize: true,
                ),
                StatTile(
                  label: '시간',
                  value: Fmt.duration(recorder.elapsedSec),
                  emphasize: true,
                ),
                StatTile(
                  label: '페이스',
                  value: Fmt.pace(recorder.avgSpeedMps),
                  emphasize: true,
                ),
              ],
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
    final readiness = await recorder.start();
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
