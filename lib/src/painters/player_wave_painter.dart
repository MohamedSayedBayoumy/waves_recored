import 'package:flutter/material.dart';

import '../../audio_waveforms.dart';

class PlayerWavePainter extends CustomPainter {
  final List<double> waveformData;
  final double animValue;
  final Offset totalBackDistance;
  final Offset dragOffset;
  final double audioProgress;
  final VoidCallback pushBack;
  final bool callPushback;
  final double emptySpace;
  final double scrollScale;
  final WaveformType waveformType;

  final PlayerWaveStyle playerWaveStyle;

  PlayerWavePainter({
    required this.waveformData,
    required this.animValue,
    required this.dragOffset,
    required this.totalBackDistance,
    required this.audioProgress,
    required this.pushBack,
    required this.callPushback,
    required this.scrollScale,
    required this.waveformType,
    required this.cachedAudioProgress,
    required this.playerWaveStyle,
  })  : fixedWavePaint = Paint()
          ..color = playerWaveStyle.fixedWaveColor
          ..strokeWidth = playerWaveStyle.waveThickness
          ..strokeCap = playerWaveStyle.waveCap
          ..shader = playerWaveStyle.fixedWaveGradient,
        liveWavePaint = Paint()
          ..color = playerWaveStyle.liveWaveColor
          ..strokeWidth = playerWaveStyle.waveThickness
          ..strokeCap = playerWaveStyle.waveCap
          ..shader = playerWaveStyle.fixedWaveGradient,
        emptySpace = playerWaveStyle.spacing,
        middleLinePaint = Paint()
          ..color = playerWaveStyle.seekLineColor
          ..strokeWidth = playerWaveStyle.seekLineThickness;

  Paint fixedWavePaint;
  Paint liveWavePaint;
  Paint middleLinePaint;
  double cachedAudioProgress;

  @override
  void paint(Canvas canvas, Size size) {
    _drawWave(size, canvas);
    if (playerWaveStyle.showSeekLine && waveformType.isLong) {
      _drawMiddleLine(size, canvas);
    }
  }

  @override
  bool shouldRepaint(PlayerWavePainter oldDelegate) => true;

  void _drawMiddleLine(Size size, Canvas canvas) {
    // حساب الموضع الأفقي للدائرة بناءً على تقدم الصوت
    final currentX = size.width * audioProgress; // الموضع الأفقي للدائرة
    final centerY = size.height / 2; // الموضع الرأسي (منتصف الشاشة)
    final radius = size.width * 0.025; // نصف القطر (2.5% من عرض الشاشة)

    // رسم الدائرة
    canvas.drawCircle(
      Offset(currentX, centerY),
      radius,
      fixedWavePaint
        ..color = playerWaveStyle.seekLineColor
        ..style = PaintingStyle.fill, // نملأ الدائرة
    );
  }

  void _drawWave(Size size, Canvas canvas) {
    final length = waveformData.length;
    final halfHeight = size.height * 0.5;

    // إضافة المسافة بين الموجات
    final spacing = size.width / (length - 1);

    if (cachedAudioProgress != audioProgress) {
      pushBack();
    }

    for (int i = 0; i < length; i++) {
      // حساب الموضع الأفقي لكل موجة
      final dx = i * spacing;

      final waveHeight = (waveformData[i] * animValue) *
          playerWaveStyle.scaleFactor *
          scrollScale;
      final bottomDy =
          halfHeight + (playerWaveStyle.showBottom ? waveHeight : 0);
      final topDy = halfHeight + (playerWaveStyle.showTop ? -waveHeight : 0);

      // رسم الموجة
      canvas.drawLine(
        Offset(dx, bottomDy),
        Offset(dx, topDy),
        i < audioProgress * length ? liveWavePaint : fixedWavePaint,
      );
    }
  }
}
