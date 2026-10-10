import 'package:flutter/material.dart';

class AudioWaveform extends StatelessWidget {
  final List<double> amplitudes;
  final double? progress;

  const AudioWaveform({super.key, required this.amplitudes, this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4F2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...List.generate(amplitudes.length, (index) {
            final value = amplitudes[index];

            final height = ((value + 60) / 60 * 60).clamp(6.0, 60.0).toDouble();
            final isPlayed =
                progress != null && index / amplitudes.length < progress!;

            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: progress == null
                    ? const Color(0xFF6FA7A3)
                    : isPlayed
                    ? const Color(0xFF287D78)
                    : const Color(0xFFBFD8D5),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ],
      ),
    );
  }
}
