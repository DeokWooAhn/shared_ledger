// 지갑 모양은 lucide 아이콘 'wallet'의 경로를 옮겼다.
// lucide: ISC License, Copyright (c) Lucide Contributors (https://lucide.dev/license)
import 'package:flutter/widgets.dart';

/// 앱 아이콘(`design/icon.pen`)과 같은 지갑 모양을 선으로 그린다. 로그인 화면 로고에 쓴다.
///
/// 크기와 상관없이 선명하게 그리려고 이미지 대신 lucide의 24×24 경로를 [size]에 맞춰 늘린다.
/// 장식이라 화면 읽기 도구에 내보내는 내용이 없다([CustomPaint]의 기본값).
class WalletGlyph extends StatelessWidget {
  const WalletGlyph({required this.size, required this.color, super.key});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _WalletPainter(color));
  }
}

class _WalletPainter extends CustomPainter {
  const _WalletPainter(this.color);

  final Color color;

  static const _grid = 24.0;
  static const _stroke = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _grid, size.height / _grid);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(_flapAndClasp, paint)
      ..drawPath(_body, paint);
  }

  // SVG의 sweep-flag 1은 화면에서 시계 방향, 0은 반시계 방향이다.
  static const _r1 = Radius.circular(1);
  static const _r2 = Radius.circular(2);

  /// 위 덮개와 오른쪽 잠금쇠. `M19 7V4a1 1 0 0 0-1-1H5a2 2 0 0 0 0 4h15a1 1 0 0 1 1 1v4h-3
  /// a2 2 0 0 0 0 4h3a1 1 0 0 0 1-1v-2a1 1 0 0 0-1-1`
  static final _flapAndClasp = Path()
    ..moveTo(19, 7)
    ..lineTo(19, 4)
    ..arcToPoint(const Offset(18, 3), radius: _r1, clockwise: false)
    ..lineTo(5, 3)
    ..arcToPoint(const Offset(5, 7), radius: _r2, clockwise: false)
    ..lineTo(20, 7)
    ..arcToPoint(const Offset(21, 8), radius: _r1)
    ..lineTo(21, 12)
    ..lineTo(18, 12)
    ..arcToPoint(const Offset(18, 16), radius: _r2, clockwise: false)
    ..lineTo(21, 16)
    ..arcToPoint(const Offset(22, 15), radius: _r1, clockwise: false)
    ..lineTo(22, 13)
    ..arcToPoint(const Offset(21, 12), radius: _r1, clockwise: false);

  /// 몸통. `M3 5v14a2 2 0 0 0 2 2h15a1 1 0 0 0 1-1v-4`
  static final _body = Path()
    ..moveTo(3, 5)
    ..lineTo(3, 19)
    ..arcToPoint(const Offset(5, 21), radius: _r2, clockwise: false)
    ..lineTo(20, 21)
    ..arcToPoint(const Offset(21, 20), radius: _r1, clockwise: false)
    ..lineTo(21, 16);

  @override
  bool shouldRepaint(_WalletPainter oldDelegate) => oldDelegate.color != color;
}
