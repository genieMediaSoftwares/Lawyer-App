import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class VoiceRecordingVisualizer extends StatelessWidget {
  final List<double> amplitudes;
  final bool isRecording;

  const VoiceRecordingVisualizer({
    super.key,
    required this.amplitudes,
    required this.isRecording,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = theme.colorScheme.primary;

    // Fill with empty placeholders if there are not enough samples to display a full wave
    final List<double> displayAmplitudes = List<double>.from(amplitudes);
    const int maxBars = 25;
    while (displayAmplitudes.length < maxBars) {
      displayAmplitudes.insert(0, 0.05);
    }

    return Container(
      height: 48,
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(maxBars, (index) {
          final amp = displayAmplitudes[index];
          // Scale height between 4 and 40 pixels
          final double height = 4.0 + (amp * 36.0);

          return AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeInOut,
            width: 3,
            height: isRecording ? height : 4,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: isRecording ? goldColor : AppColors.mutedText.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}
