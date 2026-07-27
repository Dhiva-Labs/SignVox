import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

import '../../speech/stt_service.dart';
import '../../theme.dart';
import '../widgets/empty_state.dart';

/// Reply-mode STT transcript for Conversation mode (PLAN.md §4 screen 4):
/// big, high-contrast text for the hearing speaker's side of the exchange.
/// Shows a clear explainer instead of a silently-dead transcript when
/// on-device recognition isn't available on this device (§6.5) — never
/// implies a network fallback happened instead.
class ConversationTranscript extends StatelessWidget {
  const ConversationTranscript({super.key, required this.stt});

  final SttService stt;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ColoredBox(
      color: colors.groupedBg,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: ValueListenableBuilder(
            valueListenable: stt.availability,
            builder: (context, availability, _) {
              if (availability == SttAvailability.unavailable) {
                return const SvEmptyState(
                  icon: CupertinoIcons.mic_slash,
                  title: 'Captions Unavailable',
                  message:
                      'Reply captions need on-device speech recognition, which '
                      "isn't available on this device (requires Android 12+ with the "
                      'offline speech model installed, and microphone permission).',
                );
              }
              return ValueListenableBuilder(
                valueListenable: stt.transcript,
                builder: (context, transcript, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ValueListenableBuilder(
                        valueListenable: stt.isListening,
                        builder: (context, listening, _) => Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: listening
                                    ? colors.destructive
                                    : colors.tertiaryLabel,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              listening ? 'Listening' : 'Reply captions',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.1,
                                color: colors.secondaryLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          reverse: true,
                          child: Text(
                            transcript.isEmpty
                                ? 'Waiting for the other person to speak…'
                                : transcript,
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.5,
                              height: 1.25,
                              color: transcript.isEmpty
                                  ? colors.tertiaryLabel
                                  : colors.label,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
