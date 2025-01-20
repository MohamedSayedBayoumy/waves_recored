import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';

import '../audio_waveforms.dart';
import 'base/wave_clipper.dart';
import 'painters/player_wave_painter.dart';

class AudioFileWaveforms extends StatefulWidget {
  /// A size to define height and width of waveform.
  final Size size;

  /// A PlayerController having different controls for audio player.
  final PlayerController playerController;

  /// Directly draws waveforms from this data. Extracted waveform data
  /// is ignored if waveform data is provided from this parameter.
  final List<double> waveformData;

  /// When this flag is set to true, new waves are drawn as soon as new
  /// waveform data is available from [onCurrentExtractedWaveformData].
  /// If this flag is set to false then waveforms will be drawn after waveform
  /// extraction is fully completed.
  ///
  /// This flag is ignored if [waveformData] is directly provided.
  ///
  /// See documentation of extractWaveformData in [PlayerController] to
  /// determine which value to choose.
  ///
  /// Defaults to true.
  final bool continuousWaveform;

  /// A PlayerWaveStyle instance controls how waveforms should look.
  final PlayerWaveStyle playerWaveStyle;

  /// Provides padding around waveform.
  final EdgeInsets? padding;

  /// Provides margin around waveform.
  final EdgeInsets? margin;

  /// Provides box decoration to the container having waveforms.
  final BoxDecoration? decoration;

  /// Color which is applied in to background of the waveform.
  /// If decoration is used then use color in it.
  final Color? backgroundColor;

  /// Duration for animation. Defaults to 500 milliseconds.
  final Duration animationDuration;

  /// Curve for animation. Defaults to Curves.easeIn
  final Curve animationCurve;

  /// A clipping behaviour which is applied to container having waveforms.
  final Clip clipBehavior;

  /// Draws waveform bases on selected option. For more info, see
  /// [WaveformType] documentation.
  final WaveformType waveformType;

  /// Allow seeking with gestures when turned on.
  final bool enableSeekGesture;

  /// Provides a callback when drag starts.
  final Function(DragStartDetails)? onDragStart;

  /// Provides a callback when drag ends.
  final Function(DragEndDetails)? onDragEnd;

  /// Provides a callback on drag updates.
  final Function(DragUpdateDetails)? dragUpdateDetails;

  /// Provides a callback when tapping on the waveform.
  final Function(TapUpDetails)? tapUpUpdateDetails;

  /// Generate waveforms from audio file. You play those audio file using
  /// [PlayerController].
  ///
  /// When you play the audio file, waves change their color according to
  /// how much audio has been played and how much is left.
  ///
  /// With seeking gesture enabled, playing audio can be seeked to
  /// any position using gestures.
  ///

  final String fileSize;
  final TextStyle? style;
  const AudioFileWaveforms({
    super.key,
    required this.size,
    required this.playerController,
    this.waveformData = const [],
    this.continuousWaveform = true,
    this.playerWaveStyle = const PlayerWaveStyle(),
    this.padding,
    this.margin,
    this.decoration,
    this.backgroundColor,
    this.animationDuration = const Duration(milliseconds: 500),
    this.animationCurve = Curves.easeIn,
    this.clipBehavior = Clip.none,
    this.waveformType = WaveformType.long,
    this.enableSeekGesture = true,
    this.onDragStart,
    this.onDragEnd,
    this.dragUpdateDetails,
    this.tapUpUpdateDetails,
    this.fileSize = "",
    this.style,
  });

  @override
  State<AudioFileWaveforms> createState() => _AudioFileWaveformsState();
}

class _AudioFileWaveformsState extends State<AudioFileWaveforms>
    with SingleTickerProviderStateMixin {
  late AnimationController _growingWaveController;
  late Animation<double> _growAnimation;

  double _growAnimationProgress = 0.0;
  final ValueNotifier<int> _seekProgress = ValueNotifier(0);
  bool showSeekLine = false;

  late EdgeInsets? margin;
  late EdgeInsets? padding;
  late BoxDecoration? decoration;
  late Color? backgroundColor;
  late Duration? animationDuration;
  late Curve? animationCurve;
  late Clip? clipBehavior;
  late StreamSubscription<int> onCurrentDurationSubscription;
  late StreamSubscription<void> onCompletionSubscription;
  StreamSubscription<List<double>>? onCurrentExtractedWaveformData;

  double get spacing => widget.playerWaveStyle.spacing;

  double get totalWaveWidth =>
      widget.playerWaveStyle.spacing * _waveformData.length;

  PlayerWaveStyle get playerWaveStyle => widget.playerWaveStyle;

  PlayerController get playerController => widget.playerController;

  @override
  void initState() {
    super.initState();
    _initialiseVariables();
    _growingWaveController = AnimationController(
      vsync: this,
      duration: widget.animationDuration,
    );
    _growAnimation = CurvedAnimation(
      parent: _growingWaveController,
      curve: widget.animationCurve,
    );

    _growingWaveController
      ..forward()
      ..addListener(_updateGrowAnimationProgress);

    onCurrentDurationSubscription =
        playerController.onCurrentDurationChanged.listen((event) {
      _seekProgress.value = event;

      silderStreamController.add(event);

      timerStreamController.add(event);

      _updatePlayerPercent();
    });

    onCompletionSubscription = playerController.onCompletion.listen((event) {
      _seekProgress.value = playerController.maxDuration;
      _updatePlayerPercent();
    });
    if (widget.waveformData.isNotEmpty) {
      _addWaveformData(widget.waveformData);
    } else {
      if (playerController.waveformData.isNotEmpty) {
        _addWaveformData(playerController.waveformData);
      }
      if (!widget.continuousWaveform) {
        playerController.addListener(_addWaveformDataFromController);
      } else {
        onCurrentExtractedWaveformData = playerController
            .onCurrentExtractedWaveformData
            .listen(_addWaveformData);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((time) async {
      await getduration();
    });
  }

  @override
  void dispose() {
    onCurrentDurationSubscription.cancel();
    onCurrentExtractedWaveformData?.cancel();
    onCompletionSubscription.cancel();
    playerController.removeListener(_addWaveformDataFromController);
    _growingWaveController.dispose();
    silderStreamController.close();
    timerStreamController.close();

    super.dispose();
  }

  double _audioProgress = 0.0;
  double _cachedAudioProgress = 0.0;

  Offset _totalBackDistance = Offset.zero;
  Offset _dragOffset = Offset.zero;

  double _initialDragPosition = 0.0;
  double _scrollDirection = 0.0;

  bool _isScrolled = false;
  double scrollScale = 1.0;
  double _proportion = 0.0;

  final List<double> _waveformData = [];

  // ignore: close_sinks
  StreamController<int> timerStreamController = StreamController<int>();

  StreamController<int> silderStreamController = StreamController<int>();

  int durationFile = 0;
  getduration() async {
    final duration = await playerController.getDuration();
    durationFile = duration;
    log("message>>>>>>>>>>> $durationFile seconds");
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      decoration: widget.decoration,
      clipBehavior: widget.clipBehavior,
      child: Stack(
        children: [
          Container(
            color: Colors.amber,
            child: GestureDetector(
              onHorizontalDragUpdate:
                  widget.enableSeekGesture ? _handleDragGestures : null,
              onTapUp:
                  widget.enableSeekGesture ? _handleScrubberSeekStart : null,
              onHorizontalDragStart:
                  widget.enableSeekGesture ? _handleHorizontalDragStart : null,
              onHorizontalDragEnd:
                  widget.enableSeekGesture ? _handleOnDragEnd : null,
              child: ClipPath(
                clipper: WaveClipper(extraClipperHeight: 0),
                child: RepaintBoundary(
                  child: ValueListenableBuilder<int>(
                    builder: (_, __, ___) {
                      return CustomPaint(
                        isComplex: true,
                        painter: PlayerWavePainter(
                          playerWaveStyle: playerWaveStyle,
                          waveformData: _waveformData,
                          animValue: _growAnimationProgress,
                          totalBackDistance: _totalBackDistance,
                          dragOffset: _dragOffset,
                          audioProgress: _audioProgress,
                          callPushback: !_isScrolled,
                          pushBack: _pushBackWave,
                          scrollScale: scrollScale,
                          waveformType: widget.waveformType,
                          cachedAudioProgress: _cachedAudioProgress,
                        ),
                        size: widget.size,
                      );
                    },
                    valueListenable: _seekProgress,
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: StreamBuilder<int>(
                stream: silderStreamController.stream,
                builder: (context, snapshot) {
                  return SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: Colors.transparent,
                      inactiveTrackColor: Colors.transparent,
                      thumbColor: Colors.white,
                      trackHeight: 2.0,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                      overlayColor: Colors.transparent,
                      trackShape: CustomTrackShape(),
                    ),
                    child: Slider(
                      min: 0.0,
                      value:
                          (snapshot.hasData ? snapshot.data! : 0.0).toDouble(),
                      max: (snapshot.hasData
                              ? playerController.maxDuration
                              : 0.0)
                          .toDouble(),
                      onChanged: (newValue) {
                        _seekProgress.value = newValue.toInt();

                        playerController.seekTo(_seekProgress.value);
                      },
                    ),
                  );
                }),
          ),
          Positioned(
            bottom: 0.0,
            child: IntrinsicHeight(
              child: Column(
                children: [
                  if (widget.fileSize.isNotEmpty &&
                      widget.playerController.playerState.isInitialised) ...[
                    Text(
                      widget.fileSize,
                      style: widget.style,
                    )
                  ],
                  if ((widget.playerController.playerState.isInitialised &&
                          widget.fileSize.isEmpty) ||
                      widget.playerController.playerState.isStopped) ...[
                    Text(
                      formatDuration(durationFile),
                      style: widget.style,
                    )
                  ],
                  if (widget.playerController.playerState.isPlaying ||
                      widget.playerController.playerState.isPaused) ...[
                    StreamBuilder<int>(
                        stream: timerStreamController.stream,
                        builder: (context, snapshot) {
                          if (snapshot.hasData == false) {
                            return Text(
                              formatDuration(durationFile),
                              style: widget.style,
                            );
                          }

                          return Text(
                            formatDuration(snapshot.data!),
                            style: widget.style,
                          );
                        }),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String formatDuration(int milliseconds) {
    Duration duration = Duration(milliseconds: milliseconds);

    // استخراج الساعات، الدقائق، والثواني
    int hours = duration.inHours;
    int minutes = duration.inMinutes % 60;
    int seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    } else {
      return '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}';
    }
  }

  void _addWaveformDataFromController() =>
      _addWaveformData(playerController.waveformData);

  void _updateGrowAnimationProgress() {
    if (mounted) {
      setState(() {
        _growAnimationProgress = _growAnimation.value;
      });
    }
  }

  void _handleOnDragEnd(DragEndDetails dragEndDetails) {
    log("_handleOnDragEnd>>>>>>>>>>");

    _isScrolled = false;
    scrollScale = 1.0;
    if (mounted) setState(() {});

    if (widget.waveformType.isLong) {
      playerController.seekTo(
        (playerController.maxDuration * _proportion).toInt(),
      );
    }
    widget.onDragEnd?.call(dragEndDetails);
  }

  void _addWaveformData(List<double> data) {
    _waveformData
      ..clear()
      ..addAll(data);
    if (mounted) setState(() {});
  }

  void _handleDragGestures(DragUpdateDetails details) {
    switch (widget.waveformType) {
      case WaveformType.fitWidth:
        _handleScrubberSeekUpdate(details);
        break;
      case WaveformType.long:
        _handleScrollUpdate(details);
        break;
    }

    widget.dragUpdateDetails?.call(details);
  }

  /// This method handles continues seek gesture
  void _handleScrubberSeekUpdate(DragUpdateDetails details) {
    final localPosition = details.localPosition.dx;

    _proportion = localPosition <= 0 ? 0 : localPosition / widget.size.width;
    var seekPosition = playerController.maxDuration * _proportion;

    playerController.seekTo(seekPosition.toInt());
  }

  /// This method handles tap seek gesture
  void _handleScrubberSeekStart(TapUpDetails details) {
    _proportion = details.localPosition.dx / widget.size.width;
    var seekPosition = playerController.maxDuration * _proportion;

    playerController.seekTo(seekPosition.toInt());

    widget.tapUpUpdateDetails?.call(details);
  }

  ///This method handles horizontal scrolling of the wave
  void _handleScrollUpdate(DragUpdateDetails details) {
    // Direction of the scroll. Negative value indicates scroll left to right
    // and positive value indicates scroll right to left
    _scrollDirection = details.localPosition.dx - _initialDragPosition;
    playerController.setRefresh(false);
    _isScrolled = true;

    scrollScale = playerWaveStyle.scrollScale;

    final spacing = playerWaveStyle.spacing;

    // Update the drag offset based on scroll direction and thresholds.
    final currentPosition = -_totalBackDistance.dx + _dragOffset.dx;
    final updatedPosition = currentPosition + details.delta.dx;

    // left to right
    if (updatedPosition + (spacing) < spacing / 2 && _scrollDirection > 0) {
      _dragOffset += details.delta;
    }

    // right to left
    else if (currentPosition + totalWaveWidth + details.delta.dx >
            (-spacing / 2) &&
        _scrollDirection < 0) {
      _dragOffset += details.delta;
    }

    // Indicates location of first wave
    var start = currentPosition - (spacing / 2);

    _proportion = _scrollDirection < 0
        ? (start.abs() + details.delta.dx) / totalWaveWidth
        : (details.delta.dx - start - spacing) / totalWaveWidth;
    if (mounted) setState(() {});
  }

  ///This will help-out to determine direction of the scroll
  void _handleHorizontalDragStart(DragStartDetails details) {
    _initialDragPosition = details.localPosition.dx;
    widget.onDragStart?.call(details);
  }

  /// This initialises variable in [initState] so that everytime current duration
  /// gets updated it doesn't re assign them to same values.
  ///

  void _initialiseVariables() {
    if (playerController.waveformData.isEmpty) {
      playerController.waveformData.addAll(widget.waveformData);
    }
    showSeekLine = false;
    margin = widget.margin;
    padding = widget.padding;
    decoration = widget.decoration;
    backgroundColor = widget.backgroundColor;
    animationDuration = widget.animationDuration;
    animationCurve = widget.animationCurve;
    clipBehavior = widget.clipBehavior;
  }

  /// calculates seek progress
  void _updatePlayerPercent() {
    if (playerController.maxDuration == 0) return;
    _audioProgress = _seekProgress.value / playerController.maxDuration;
  }

  ///This will handle pushing back the wave when it reaches to middle/end of the
  ///given size.width.
  ///
  ///This will also handle refreshing the wave after scrolled
  void _pushBackWave() {
    if (!_isScrolled && widget.waveformType.isLong) {
      _totalBackDistance = Offset(
          (playerWaveStyle.spacing * _audioProgress * _waveformData.length) +
              playerWaveStyle.spacing +
              _dragOffset.dx,
          0.0);
    }
    if (playerController.shouldClearLabels) {
      _initialDragPosition = 0.0;
      _totalBackDistance = Offset.zero;
      _dragOffset = Offset.zero;
    }
    _cachedAudioProgress = _audioProgress;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }
}

class CustomTrackShape extends RoundedRectSliderTrackShape {
  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final trackHeight = sliderTheme.trackHeight;
    final trackLeft = offset.dx;
    final trackTop = offset.dy + (parentBox.size.height - trackHeight!) / 2;
    final trackWidth = parentBox.size.width;
    return Rect.fromLTWH(trackLeft, trackTop, trackWidth, trackHeight);
  }
}
