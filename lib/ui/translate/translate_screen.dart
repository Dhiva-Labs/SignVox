import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/prototype_store.dart';
import '../../core/providers.dart';
import '../../core/signs_controller.dart';
import '../../core/spell_controller.dart';
import '../../core/vision_channel.dart';
import '../../engines/decoder.dart';
import '../../engines/letter_engine.dart';
import '../../engines/word_suggester.dart';
import '../../speech/stt_service.dart';
import '../widgets/empty_state.dart';
import '../widgets/frosted.dart';
import '../widgets/nav.dart';
import '../widgets/segmented.dart';
import 'conversation_transcript.dart';
import 'hand_overlay_painter.dart';
import 'quick_phrases_row.dart';
import 'sentence_strip.dart';
import 'signs_strip.dart';
import 'vision_hud.dart';

enum TranslateMode { spell, signs }

class TranslateScreen extends ConsumerStatefulWidget {
  const TranslateScreen({super.key});

  @override
  ConsumerState<TranslateScreen> createState() => _TranslateScreenState();
}

class _TranslateScreenState extends ConsumerState<TranslateScreen> {
  SpellController? _spellController;
  SignsController? _signsController;
  VoidCallback? _frameListener;
  CameraInit? _cameraInit;
  String? _errorMessage;
  bool _showOverlay = true;
  bool _disposed = false;
  TranslateMode _mode = TranslateMode.spell;

  SttService? _sttService;
  bool _conversationMode = false;
  VoidCallback? _settingsListener;

  // Haptic commit ticks (UI-side so the recognition spine stays untouched):
  // a letter landing is a light tap, a whole word committing is a firmer one.
  int _lastSentenceLength = 0;
  int _lastWordLength = 0;
  int _lastSignsCount = 0;
  VoidCallback? _spellHapticListener;
  VoidCallback? _signsHapticListener;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final status = await Permission.camera.request();
    if (_disposed) return;
    if (!status.isGranted) {
      setState(
        () =>
            _errorMessage = 'Camera permission is required to translate signs.',
      );
      return;
    }
    try {
      final controller = ref.read(visionControllerProvider);
      final init = await controller.ensureStarted();
      if (_disposed) return;
      ref.read(
        adaptiveFpsControllerProvider,
      ); // constructing it activates the thermal listener
      final letterEngine = await LetterEngine.load();
      if (_disposed) return;

      final settings = ref.read(appSettingsProvider);
      await settings.ready;
      if (_disposed) return;
      final initialSettings = settings.data.value;

      final tts = ref.read(ttsServiceProvider);
      await tts.setRate(initialSettings.ttsRate);
      final history = ref.read(historyRepositoryProvider);
      // Word suggestions are a pure add-on: a missing/corrupt asset just means
      // no chips, never a broken Translate screen.
      WordSuggester? suggester;
      try {
        suggester = await WordSuggester.load();
      } catch (_) {
        suggester = null;
      }
      if (_disposed) return;

      final spell = SpellController(
        letterEngine: letterEngine,
        tts: tts,
        history: history,
        suggester: suggester,
        leftHandedMode: initialSettings.leftHandedMode,
        speakPerWord: initialSettings.speakPerWord,
        decoder: SpellDecoder(
          holdDuration: Duration(milliseconds: initialSettings.letterHoldMs),
        ),
      )..autocorrect = initialSettings.autocorrectEnabled;
      spell.letterEngine.prototypes = await loadUserPrototypes()
        ..enabled = initialSettings.personalisationEnabled;
      final signs = SignsController(
        repository: ref.read(signRepositoryProvider),
        tts: tts,
        history: history,
        dominantIsLeft: initialSettings.leftHandedMode,
        speakPerWord: initialSettings.speakPerWord,
      );
      setState(() => _showOverlay = initialSettings.showOverlayByDefault);
      if (initialSettings.keepScreenOnWhileTranslating) {
        await WakelockPlus.enable();
      }

      _settingsListener = () {
        final s = settings.data.value;
        spell.leftHandedMode = s.leftHandedMode;
        spell.decoder.holdDuration = Duration(milliseconds: s.letterHoldMs);
        spell.letterEngine.prototypes?.enabled = s.personalisationEnabled;
        spell.speakPerWord = s.speakPerWord;
        spell.autocorrect = s.autocorrectEnabled;
        signs.dominantIsLeft = s.leftHandedMode;
        signs.speakPerWord = s.speakPerWord;
        tts.setRate(s.ttsRate);
        if (s.keepScreenOnWhileTranslating || _conversationMode) {
          WakelockPlus.enable();
        } else {
          WakelockPlus.disable();
        }
      };
      settings.data.addListener(_settingsListener!);

      _frameListener = () {
        final f = controller.frame.value;
        if (f == null) return;
        switch (_mode) {
          case TranslateMode.spell:
            spell.onFrame(f);
          case TranslateMode.signs:
            signs.onFrame(f);
        }
      };
      controller.frame.addListener(_frameListener!);

      _spellHapticListener = () {
        final s = spell.state.value;
        if (s.sentence.length > _lastSentenceLength) {
          HapticFeedback.mediumImpact();
        } else if (s.currentWord.length > _lastWordLength) {
          HapticFeedback.lightImpact();
        }
        _lastSentenceLength = s.sentence.length;
        _lastWordLength = s.currentWord.length;
      };
      spell.state.addListener(_spellHapticListener!);
      _signsHapticListener = () {
        final count = signs.state.value.sentence.length;
        if (count > _lastSignsCount) HapticFeedback.mediumImpact();
        _lastSignsCount = count;
      };
      signs.state.addListener(_signsHapticListener!);

      setState(() {
        _cameraInit = init;
        _spellController = spell;
        _signsController = signs;
      });
    } catch (e) {
      if (_disposed) return;
      setState(() => _errorMessage = 'Camera failed to start:\n$e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_frameListener != null) {
      ref.read(visionControllerProvider).frame.removeListener(_frameListener!);
    }
    if (_settingsListener != null) {
      ref.read(appSettingsProvider).data.removeListener(_settingsListener!);
    }
    if (_spellHapticListener != null) {
      _spellController?.state.removeListener(_spellHapticListener!);
    }
    if (_signsHapticListener != null) {
      _signsController?.state.removeListener(_signsHapticListener!);
    }
    _spellController?.dispose();
    _signsController?.dispose();
    WakelockPlus.disable();
    _sttService?.dispose();
    super.dispose();
  }

  Future<void> _toggleConversationMode() async {
    HapticFeedback.selectionClick();
    if (_conversationMode) {
      setState(() => _conversationMode = false);
      // Only release the wakelock if the general "keep screen on while
      // translating" setting isn't independently holding it too.
      if (!ref
          .read(appSettingsProvider)
          .data
          .value
          .keepScreenOnWhileTranslating) {
        await WakelockPlus.disable();
      }
      await _sttService?.stop();
      return;
    }
    // Create (or reuse) the STT service *before* flipping the flag that
    // makes the build method read it — ConversationTranscript assumes a
    // non-null service once conversation mode is on.
    final stt = _sttService ??= SttService();
    setState(() => _conversationMode = true);
    await WakelockPlus.enable();
    await stt.start();
  }

  @override
  Widget build(BuildContext context) {
    // Camera chrome is dark in both themes, like every capture UI Apple ships.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(backgroundColor: Colors.black, body: _buildBody()),
    );
  }

  Widget _buildBody() {
    final error = _errorMessage;
    if (error != null) {
      return SvEmptyState(
        onDark: true,
        icon: CupertinoIcons.videocam,
        title: 'Camera unavailable',
        message: error,
        action: error.startsWith('Camera permission')
            ? OutlinedButton(
                onPressed: openAppSettings,
                child: const Text('Open Settings'),
              )
            : null,
      );
    }

    final init = _cameraInit;
    final spell = _spellController;
    final signs = _signsController;
    if (init == null || spell == null || signs == null) {
      return const Center(
        child: CupertinoActivityIndicator(radius: 14, color: Colors.white70),
      );
    }

    return _conversationMode
        ? _buildConversation(init, spell, signs)
        : _buildTranslate(init, spell, signs);
  }

  Widget _cameraLayer(CameraInit init) {
    final controller = ref.read(visionControllerProvider);
    return Center(
      child: AspectRatio(
        aspectRatio: init.displayWidth / init.displayHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RotatedBox(
              quarterTurns: init.rotationDegrees ~/ 90,
              child: Texture(textureId: init.textureId),
            ),
            if (_showOverlay)
              CustomPaint(painter: HandOverlayPainter(controller.frame)),
          ],
        ),
      ),
    );
  }

  Widget _strip(SpellController spell, SignsController signs) {
    return switch (_mode) {
      TranslateMode.spell => SentenceStrip(
        state: spell.state,
        onSpeakAll: spell.speakAll,
        onBackspace: spell.backspace,
        onAddSpace: spell.addSpace,
        onClear: spell.clear,
        onSuggestion: spell.acceptSuggestion,
      ),
      TranslateMode.signs => SignsStrip(
        state: signs.state,
        onSpeakAll: signs.speakAll,
        onClear: signs.clear,
        onAcceptCandidate: signs.acceptCandidate,
      ),
    };
  }

  Widget _topButtons() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassIconButton(
          icon: _conversationMode
              ? CupertinoIcons.bubble_left_bubble_right_fill
              : CupertinoIcons.bubble_left_bubble_right,
          semanticLabel: _conversationMode
              ? 'Exit conversation mode'
              : 'Conversation mode',
          active: _conversationMode,
          onPressed: _toggleConversationMode,
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: _showOverlay ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
          semanticLabel: 'Toggle skeleton overlay',
          onPressed: () => setState(() => _showOverlay = !_showOverlay),
        ),
      ],
    );
  }

  /// Full-bleed camera, floating glass chrome, everything else out of the way.
  Widget _buildTranslate(
    CameraInit init,
    SpellController spell,
    SignsController signs,
  ) {
    final controller = ref.read(visionControllerProvider);
    final bottomInset = kSvTabBarHeight + MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        _cameraLayer(init),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VisionHud(stats: controller.stats),
                const Spacer(),
                _topButtons(),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: bottomInset + 10,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 192,
                child: SvSegmented<TranslateMode>(
                  onDark: true,
                  value: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                  segments: const [
                    (TranslateMode.spell, 'Spell'),
                    (TranslateMode.signs, 'Signs'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _strip(spell, signs),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Split view: the hearing person's captions up top, camera below, quick
  /// phrases and the composing strip at the bottom.
  Widget _buildConversation(
    CameraInit init,
    SpellController spell,
    SignsController signs,
  ) {
    final bottomInset = kSvTabBarHeight + MediaQuery.paddingOf(context).bottom;
    return Column(
      children: [
        Expanded(flex: 3, child: ConversationTranscript(stt: _sttService!)),
        Expanded(
          flex: 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _cameraLayer(init),
              Positioned(top: 8, right: 14, child: _topButtons()),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const QuickPhrasesRow(),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _strip(spell, signs),
        ),
        SizedBox(height: bottomInset + 10),
      ],
    );
  }
}
