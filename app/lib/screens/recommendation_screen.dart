import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/recommended_course.dart';
import '../services/location_service.dart';
import '../services/overpass_service.dart';
import '../services/recommendation_service.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/recommended_route_map.dart';

/// "이 근처에서 얼마나 걷고 싶으세요?" → 순환 코스 하나를 찾아 보여준다.
///
/// docs/추천-설계.md 의 v2(규칙 기반 추천) 프로토타입. 백엔드 없이
/// 앱 안에서 OSM(Overpass) + 고도(Open-Elevation) 를 직접 불러 점수화하고
/// 코스를 만든다. 개발 중인 이 PC(회사 네트워크)에서는 Overpass 요청이
/// 막혀 있어 여기서 확인할 수 없다 — 실기기(회사 와이파이 아닌 곳)에서
/// 확인할 것. 자세한 사정은 lib/services/overpass_service.dart 참조.
class RecommendationScreen extends StatefulWidget {
  const RecommendationScreen({super.key});

  @override
  State<RecommendationScreen> createState() => _RecommendationScreenState();
}

class _RecommendationScreenState extends State<RecommendationScreen> {
  final _recommendation = RecommendationService();
  final _location = LocationService();

  // 1~2km 정도가 짧은 산책, 3km 이상이 긴 산책이라는 감으로 고른
  // 프리셋이다. **근거 없음** — WalkGoal 처럼 실제 견종별 권장 거리와
  // 연결하는 게 다음 개선 지점이다(지금은 반려견 프로필과 연동 안 함).
  static const _presetsKm = [1.0, 2.0, 3.0];
  double _targetKm = 2.0;

  bool _loading = false;
  String? _error;
  RecommendedCourse? _course;

  Future<void> _recommend() async {
    setState(() {
      _loading = true;
      _error = null;
      _course = null;
    });

    try {
      final pos = await _location.currentPosition();
      if (pos == null) {
        setState(() {
          _loading = false;
          _error = '지금 위치를 확인할 수 없어요. 위치 권한을 확인해 주세요.';
        });
        return;
      }

      final course = await _recommendation.recommendNear(
        start: LatLng(pos.latitude, pos.longitude),
        targetDistanceM: _targetKm * 1000,
      );

      setState(() {
        _loading = false;
        _course = course;
        if (course == null) {
          _error = '주변에서 걸을 만한 순환 코스를 찾지 못했어요. '
              '거리를 바꿔서 다시 시도해 보세요.';
        }
      });
    } on OverpassException catch (e) {
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = '코스를 찾는 중 문제가 생겼어요: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = PetWalkTokens.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('코스 추천')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('오늘 얼마나 걸을까요?',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final km in _presetsKm)
                      ChoiceChip(
                        label: Text('${km.toStringAsFixed(0)}km'),
                        selected: _targetKm == km,
                        onSelected: _loading
                            ? null
                            : (_) => setState(() => _targetKm = km),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _recommend,
                    icon: _loading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.route),
                    label: Text(_loading ? '주변 길을 찾는 중...' : '코스 찾기'),
                  ),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline,
                      size: 18, color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
                ],
              ),
            ),
          if (_course != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  _stat(context, '거리', Fmt.distance(_course!.distanceM)),
                  const SizedBox(width: 24),
                  _stat(context, '예상 시간', '${_course!.estimatedMinutes}분'),
                  const SizedBox(width: 24),
                  _stat(context, '적합도', '${_course!.averageScore.round()}점'),
                ],
              ),
            ),
            Expanded(
              child: RecommendedRouteMap(course: _course!),
            ),
          ] else if (!_loading)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '거리를 고르고 "코스 찾기"를 눌러 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.muted),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final tokens = PetWalkTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: tokens.display.copyWith(fontSize: 20)),
        Text(label, style: tokens.caption),
      ],
    );
  }
}
