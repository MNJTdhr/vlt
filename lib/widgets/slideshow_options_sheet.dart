// lib/widgets/slideshow_options_sheet.dart
import 'package:flutter/material.dart';

class SlideshowOptionsSheet extends StatefulWidget {
  const SlideshowOptionsSheet({super.key});

  @override
  State<SlideshowOptionsSheet> createState() => _SlideshowOptionsSheetState();
}

class _SlideshowOptionsSheetState extends State<SlideshowOptionsSheet> {
  double _currentInterval = 3.0;
  double _currentTransition = 0.3; // Default to 300ms for a smooth slide

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- Header ---
            Text(
              'Slideshow Options',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),

            // --- Interval Slider ---
            Text(
              'Slideshow Interval: ${_currentInterval.toStringAsFixed(1)} seconds',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Slider(
              value: _currentInterval,
              min: 0.5,
              max: 10.0,
              divisions: 19, // (10.0 - 0.5) / 0.5 = 19 steps
              label: _currentInterval.toStringAsFixed(1),
              onChanged: (double value) {
                setState(() {
                  _currentInterval = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // --- Transition Slider ---
            Text(
              'Transition Duration: ${_currentTransition.toStringAsFixed(1)} seconds',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Slider(
              value: _currentTransition,
              min: 0.1,
              max: 5.0,
              divisions: 49, // (5.0 - 0.1) / 0.1 = 49 steps
              label: _currentTransition.toStringAsFixed(1),
              onChanged: (double value) {
                setState(() {
                  _currentTransition = value;
                });
              },
            ),
            const SizedBox(height: 24),

            // --- Action Buttons ---
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start in Sequence'),
              onPressed: () {
                Navigator.of(context).pop({
                  'interval': _currentInterval,
                  'transition': _currentTransition,
                  'random': false,
                });
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.shuffle),
              label: const Text('Start Randomly'),
              onPressed: () {
                Navigator.of(context).pop({
                  'interval': _currentInterval,
                  'transition': _currentTransition,
                  'random': true,
                });
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}