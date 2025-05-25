import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';

class LiveMicPitchPage extends StatefulWidget {
  const LiveMicPitchPage({super.key});

  @override
  State<LiveMicPitchPage> createState() => _LiveMicPitchPageState();
}

class _LiveMicPitchPageState extends State<LiveMicPitchPage> with TickerProviderStateMixin {
  static const _methodChannel = MethodChannel('com.example.pitch_detector');

  bool _listening = false;
  String? _note;
  String? _frequency;
  String? _filePath;
  String? _error;

  Duration _recordingDuration = Duration.zero;
  Timer? _timer;

  late AnimationController _micController;
  late Animation<double> _micPulse;

  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _micController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _micPulse = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _micController, curve: Curves.easeInOut),
    );
  }

  Future<void> _startListening() async {
    try {
      await _methodChannel.invokeMethod('startListening');
      _micController.repeat(reverse: true);
      _startTimer();
      setState(() {
        _note = null;
        _frequency = null;
        _filePath = null;
        _error = null;
        _listening = true;
      });
    } catch (e) {
      setState(() => _error = "Start failed: $e");
    }
  }

  Future<void> _stopListening() async {
    try {
      final result = await _methodChannel.invokeMethod<Map>('stopListening');
      _stopTimer();
      _micController.stop();
      setState(() {
        _note = result?['note']?.toString();
        _frequency = (result?['frequency'] as double?)?.toStringAsFixed(2);
        _filePath = result?['filePath']?.toString();
        _error = null;
        _listening = false;
      });

      if (_filePath != null && _filePath!.isNotEmpty) {
        await _player.setFilePath(_filePath!);
      }
    } catch (e) {
      setState(() {
        _error = "Stop failed: $e";
        _listening = false;
      });
    }
  }

  void _startTimer() {
    _recordingDuration = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _recordingDuration += const Duration(seconds: 1);
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _recordingDuration = Duration.zero;
  }

  @override
  void dispose() {
    _micController.dispose();
    _timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  double getNoteFrequency(String note) {
    const noteFreqs = {
      "C": 261.63, "C#": 277.18, "D": 293.66, "D#": 311.13,
      "E": 329.63, "F": 349.23, "F#": 369.99, "G": 392.00,
      "G#": 415.30, "A": 440.00, "A#": 466.16, "B": 493.88,
    };
    return noteFreqs[note] ?? 0.0;
  }

  Widget _buildPitchGauge(String note, double actualFreq) {
    final targetFreq = getNoteFrequency(note);
    if (targetFreq == 0) return const SizedBox();

    final diff = actualFreq - targetFreq;
    final clamped = (diff / 50).clamp(-1.0, 1.0); // normalized -1 to 1

    return Column(
      children: [
        const SizedBox(height: 24),
        const Text("Pitch Gauge", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        CustomPaint(
          size: const Size(200, 100),
          painter: _NeedlePainter(clamped),
        ),
      ],
    );
  }

  Widget _buildPlaybackButton() {
    if (_filePath == null || _filePath!.isEmpty || _listening) return const SizedBox.shrink();

    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final isPlaying = snapshot.data?.playing ?? false;

        return ElevatedButton.icon(
          icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
          label: Text(isPlaying ? 'Stop Playback' : 'Play Recording'),
          onPressed: () async {
            if (isPlaying) {
              await _player.stop();
            } else {
              await _player.seek(Duration.zero);
              await _player.play();
            }
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _note != null && _frequency != null;
    final actualFreq = double.tryParse(_frequency ?? '') ?? 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text("Live Mic Detection")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _listening ? _micPulse : const AlwaysStoppedAnimation(1.0),
              child: Icon(Icons.mic, size: 64, color: _listening ? Colors.green : Colors.grey),
            ),
            if (_listening)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Recording: ${_formatDuration(_recordingDuration)}",
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
              ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              icon: Icon(_listening ? Icons.stop : Icons.play_arrow),
              label: Text(_listening ? 'Stop Listening' : 'Start Listening'),
              onPressed: _listening ? _stopListening : _startListening,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrangeAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                textStyle: const TextStyle(fontSize: 18),
              ),
            ),

            const SizedBox(height: 36),

            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),

            if (hasResult) ...[
              const SizedBox(height: 12),
              Text('Detected Note: $_note', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Frequency: $_frequency Hz', style: const TextStyle(fontSize: 20)),
              _buildPitchGauge(_note!, actualFreq),
              const SizedBox(height: 24),
              _buildPlaybackButton(),
            ],
          ],
        ),
      ),
    );
  }
}

class _NeedlePainter extends CustomPainter {
  final double value;

  _NeedlePainter(this.value);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height);
    final radius = size.width / 2;

    final paintArc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.black;

    final paintNeedle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.red;

    final angle = pi / 2 * value;
    final needleX = center.dx + radius * cos(angle - pi / 2);
    final needleY = center.dy + radius * sin(angle - pi / 2);

    final arcRect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(arcRect, pi, pi, false, paintArc);

    canvas.drawLine(center, Offset(needleX, needleY), paintNeedle);
  }

  @override
  bool shouldRepaint(_NeedlePainter oldDelegate) => oldDelegate.value != value;
}
