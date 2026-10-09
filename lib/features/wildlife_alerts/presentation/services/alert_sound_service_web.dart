import 'dart:js_interop';

@JS('eval')
external void _eval(String code);

void playHighRiskAlarmImpl() {
  try {
    _eval('''
      (function() {
        try {
          var AudioCtx = window.AudioContext || window.webkitAudioContext;
          if (!AudioCtx) return;
          var ctx = new AudioCtx();
          if (ctx.state === 'suspended') {
            ctx.resume();
          }
          var now = ctx.currentTime;
          
          // Emergency alternating frequency siren (880Hz / 587Hz)
          var freqs = [880, 587, 880, 587];
          freqs.forEach(function(freq, i) {
            var osc = ctx.createOscillator();
            var gain = ctx.createGain();
            
            osc.type = 'sawtooth';
            osc.frequency.setValueAtTime(freq, now + i * 0.12);
            
            gain.gain.setValueAtTime(0.3, now + i * 0.12);
            gain.gain.exponentialRampToValueAtTime(0.001, now + (i + 1) * 0.12);
            
            osc.connect(gain);
            gain.connect(ctx.destination);
            
            osc.start(now + i * 0.12);
            osc.stop(now + (i + 1) * 0.12);
          });
        } catch(e) {
          console.warn('Alert sound playback failed:', e);
        }
      })();
    ''');
  } catch (_) {}
}
