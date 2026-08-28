import 'package:web/web.dart' as web;

void reproducirBeep() {
  final audioContext = web.AudioContext();
  for (var i = 0; i < 2; i++) {
    final inicio = audioContext.currentTime + (i * 0.35);
    final oscillator = audioContext.createOscillator();
    final gainNode = audioContext.createGain();
    oscillator.type = 'sine';
    oscillator.frequency.value = 880;
    gainNode.gain.value = 0.3;
    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);
    oscillator.start(inicio);
    oscillator.stop(inicio + 0.25);
  }
}