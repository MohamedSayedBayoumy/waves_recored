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
  final String? fileAudio;

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
    required this.fileAudio,
  });

  @override
  State<AudioFileWaveforms> createState() => _AudioFileWaveformsState();
}

class _AudioFileWaveformsState extends State<AudioFileWaveforms>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<int> _seekProgress = ValueNotifier(0);
  bool showSeekLine = false;

  late EdgeInsets? margin;
  late EdgeInsets? padding;
  late BoxDecoration? decoration;
  late Color? backgroundColor;
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

    onCurrentDurationSubscription =
        playerController.onCurrentDurationChanged.listen((event) {
      _seekProgress.value = event;

      silderStreamController.add(event);

      timerStreamController.add(event);

      _updatePlayerPercent();
    });

    onCompletionSubscription = playerController.onCompletion.listen((event) {
      // _seekProgress.value = playerController.maxDuration;
      silderStreamController.close();
      silderStreamController = StreamController<int>();
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
    onCurrentExtractedWaveformData!.onDone(() {
      log("message>>>>>>>>>>>>>>>>>>>>>>>. is done stream");
    });
    WidgetsBinding.instance.addPostFrameCallback((time) async {
      await getduration();
    });
  }

  @override
  void dispose() {
    onCurrentDurationSubscription.cancel();
    onCurrentExtractedWaveformData?.cancel();
    onCompletionSubscription.cancel();
    playerController
        .removeListener(() => _addWaveformDataFromController(isDispose: true));
    silderStreamController.close();
    timerStreamController.close();

    super.dispose();
  }

  double _audioProgress = 0.0;
  final double _cachedAudioProgress = 0.0;

  final Offset _totalBackDistance = Offset.zero;
  final Offset _dragOffset = Offset.zero;

  final bool _isScrolled = false;
  double scrollScale = 1.0;

  final List<double> _waveformData = [];

  // ignore: close_sinks
  StreamController<int> timerStreamController = StreamController<int>();

  StreamController<int> silderStreamController = StreamController<int>();

  int durationFile = 0;
  Future<void> getduration() async {
    durationFile = await playerController.getDuration();
    log("message>>>>>>>>>>>>> durationFile $durationFile");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: widget.margin,
      decoration: widget.decoration,
      clipBehavior: widget.clipBehavior,
      child: Stack(
        children: [
          ClipPath(
            clipper: WaveClipper(extraClipperHeight: 0),
            child: RepaintBoundary(
              child: ValueListenableBuilder<int>(
                builder: (_, __, ___) {
                  return CustomPaint(
                    isComplex: true,
                    painter: PlayerWavePainter(
                      playerWaveStyle: playerWaveStyle,
                      waveformData: _waveformData,
                      // [
                      //   0.08094660192728043,
                      //   0.06582608819007874,
                      //   0.06829135119915009,
                      //   0.07795902341604233,
                      //   0.0613601878285408,
                      //   0.08147887140512466,
                      //   0.07330138236284256,
                      //   0.06941984593868256,
                      //   0.10907264798879623,
                      //   0.08663133531808853,
                      //   0.10842423141002655,
                      //   0.07830434292554855,
                      //   0.07001353055238724,
                      //   0.07266294956207275,
                      //   0.09277749806642532,
                      //   0.06480734050273895,
                      //   0.08314724266529083,
                      //   0.06386280804872513,
                      //   0.06504005938768387,
                      //   0.08759556710720062,
                      //   0.08024410158395767,
                      //   0.09636557847261429,
                      //   0.08150824159383774,
                      //   0.07929716259241104,
                      //   0.09534493833780289,
                      //   0.09916909039020538,
                      //   0.08795736730098724,
                      //   0.09170526266098022,
                      //   0.09836561977863312,
                      //   0.09577436000108719,
                      //   0.09918149560689926,
                      //   0.07969027757644653,
                      //   0.14972232282161713,
                      //   0.19466519355773926,
                      //   0.19722683727741241,
                      //   0.19960136711597443,
                      //   0.2042304277420044,
                      //   0.1977429986000061,
                      //   0.19517944753170013,
                      //   0.19365133345127106,
                      //   0.19805747270584106,
                      //   0.2044951468706131,
                      //   0.14581744372844696,
                      //   0.1517835557460785,
                      //   0.19356299936771393,
                      //   0.1999235302209854,
                      //   0.19596055150032043,
                      //   0.19960768520832062,
                      //   0.19970081746578217,
                      //   0.2018519639968872,
                      //   0.19708538055419922,
                      //   0.19701912999153137,
                      //   0.1928798258304596,
                      //   0.19304847717285156,
                      //   0.10400137305259705,
                      //   0.11166584491729736,
                      //   0.11294949799776077,
                      //   0.11211550235748291,
                      //   0.10790254175662994,
                      //   0.11839986592531204,
                      //   0.13031291961669922,
                      //   0.11842246353626251,
                      //   0.12830016016960144,
                      //   0.14604580402374268,
                      //   0.1456572264432907,
                      //   0.11745446175336838,
                      //   0.1029864102602005,
                      //   0.11209825426340103,
                      //   0.11743009090423584,
                      //   0.11296277493238449,
                      //   0.09894987940788269,
                      //   0.12905935943126678,
                      //   0.12406527251005173,
                      //   0.12315776944160461,
                      //   0.1438521146774292,
                      //   0.16044774651527405,
                      //   0.13645318150520325,
                      //   0.14221514761447906,
                      //   0.17109590768814087,
                      //   0.21429523825645447,
                      //   0.20193345844745636,
                      //   0.2063133269548416,
                      //   0.21653521060943604,
                      //   0.21035243570804596,
                      //   0.21102508902549744,
                      //   0.21671923995018005,
                      //   0.19016636908054352,
                      //   0.1914316862821579,
                      //   0.19478552043437958,
                      //   0.18995583057403564,
                      //   0.19996510446071625,
                      //   0.19438304007053375,
                      //   0.20398354530334473,
                      //   0.19489559531211853,
                      //   0.19617988169193268,
                      //   0.1841927468776703,
                      //   0.1776404231786728,
                      //   0.15813423693180084,
                      //   0.05661311373114586
                      // ],
                      totalBackDistance: _totalBackDistance,
                      dragOffset: _dragOffset,
                      audioProgress: _audioProgress,
                      callPushback: !_isScrolled,
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
                  if (widget.fileSize.isNotEmpty) ...[
                    Text(
                      widget.fileSize,
                      style: widget.style,
                    )
                  ] else ...[
                    StreamBuilder<int>(
                        stream: timerStreamController.stream,
                        builder: (context, snapshot) {
                          if (snapshot.hasData == false ||
                              (snapshot.data == 0)) {
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

  void _addWaveformDataFromController({isDispose = false}) =>
      _addWaveformData(playerController.waveformData);

  void _addWaveformData(List<double> data, {isDispose = false}) {
    _waveformData
      ..clear()
      ..addAll(data);
    if (isDispose == false) {
      if (mounted) setState(() {});
    }
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
    // if (!_isScrolled && widget.waveformType.isLong) {
    //   _totalBackDistance = Offset(
    //       (playerWaveStyle.spacing * _audioProgress * _waveformData.length) +
    //           playerWaveStyle.spacing +
    //           _dragOffset.dx,
    //       0.0);
    // }
    // if (playerController.shouldClearLabels) {
    //   _initialDragPosition = 0.0;
    //   _totalBackDistance = Offset.zero;
    //   _dragOffset = Offset.zero;
    // }
    // _cachedAudioProgress = _audioProgress;
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (mounted) {
    //     setState(() {});
    //   }
    // });
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
