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
  }

  @override
  bool shouldRepaint(PlayerWavePainter oldDelegate) => true;

  void _drawWave(Size size, Canvas canvas) {
    final length = waveformData.length;
    final halfHeight = size.height * 0.5;

    // خطوة لتقليل عدد النقاط
    const step = 3; // ارسم كل ثالث نقطة
    final reducedLength = (length / step).ceil();

    // إضافة المسافة بين الموجات
    final spacing =
        (size.width - 6.0) / (reducedLength - 1); // حساب المسافة بشكل ديناميكي

    if (cachedAudioProgress != audioProgress) {
      pushBack();
    }

    for (int i = 0; i < reducedLength; i++) {
      // اختيار البيانات بناءً على الـ step
      final dataIndex = i * step;
      if (dataIndex >= length) break;

      // حساب الموضع الأفقي لكل موجة
      double dx = i * spacing;

      // التأكد من أن الـ dx لا يتجاوز العرض الكامل
      if (dx > size.width - 6.0) {
        dx = size.width - 6.0; // ضبط dx في الموجة الأخيرة
      }

      // حساب ارتفاع الموجة
      final waveHeight =
          (waveformData[dataIndex]) * playerWaveStyle.scaleFactor * scrollScale;
      final bottomDy =
          halfHeight + (playerWaveStyle.showBottom ? waveHeight : 0);
      final topDy = halfHeight + (playerWaveStyle.showTop ? -waveHeight : 0);

      // تحقق إذا كانت القيم NaN
      if (dx.isNaN || bottomDy.isNaN || topDy.isNaN) {
        continue; // تخطي هذه الموجة إذا كانت تحتوي على NaN
      }

      // عرض الموجة
      const double waveWidth = 4.5; // عرض الموجة
      const double borderRadius = 4.0; // نصف القطر للحواف الدائرية

      // رسم الموجة كـ RRect
      final paint =
          i < audioProgress * reducedLength ? liveWavePaint : fixedWavePaint;

      final rrect = RRect.fromLTRBR(
        dx - waveWidth / 2, // اليسار
        topDy, // الأعلى
        dx + waveWidth / 2, // اليمين
        bottomDy, // الأسفل
        const Radius.circular(borderRadius), // حواف دائرية
      );

      canvas.drawRRect(rrect, paint);
    }
  }
}
