Engine_Haze : CroneEngine {
  classvar num_voices = 4;

  var pg;
  var <buffers;
  var <recorders;
  var <voices;

  *new { arg context, doneCallback;
    ^super.new(context, doneCallback);
  }

  alloc {
    buffers = Array.fill(num_voices, { arg i;
      var bufferLengthSeconds = 8;

      Buffer.alloc(
        context.server,
        context.server.sampleRate * bufferLengthSeconds,
        bufnum: i
      );
    });

    SynthDef(\recordBuf, { arg bufnum = 0, run = 0, preLevel = 1.0, recLevel = 1.0;
      var in = Mix.new(SoundIn.ar([0, 1]));

      RecordBuf.ar(
        in,
        bufnum,
        recLevel: recLevel,
        preLevel: preLevel,
        loop: 1,
        run: run
      );
    }).add;

    SynthDef(\synth, {
      arg out, buf, gate = 0, pos = 0, speed = 1, jitter = 0, size = 0.1, density = 20, pitch = 1, spread = 0, gain = 1, envscale = 1, pos_trig = 0, filter_cutoff = 20000, filter_q = 1;

      var grain_trig;
      var jitter_sig;
      var buf_dur;
      var pan_sig;
      var buf_pos;
      var pos_sig;
      var sig;
      var level;

      grain_trig = Impulse.kr(density);
      buf_dur = BufDur.kr(buf);

      pan_sig = TRand.kr(
        trig: grain_trig,
        lo: spread.neg,
        hi: spread
      );

      jitter_sig = TRand.kr(
        trig: grain_trig,
        lo: buf_dur.reciprocal.neg * jitter,
        hi: buf_dur.reciprocal * jitter
      );

      buf_pos = Phasor.kr(
        trig: pos_trig,
        rate: buf_dur.reciprocal / ControlRate.ir * speed,
        resetPos: pos
      );

      pos_sig = Wrap.kr(buf_pos + jitter_sig);

      // TODO: add controlled size randomness
      sig = GrainBuf.ar(2, grain_trig, size, buf, pitch, pos_sig, 2, pan_sig);
      sig = BLowPass4.ar(sig, filter_cutoff, filter_q);

      level = EnvGen.kr(Env.asr(1, 1, 1), gate: gate, timeScale: envscale);

      Out.ar(out, sig * level * gain);
    }).add;

    context.server.sync;

    pg = ParGroup.head(context.xg);

    voices = Array.fill(num_voices, { arg i;
      Synth.new(\synth, [
        \out, context.out_b.index,
        \buf, buffers[i],
      ], target: pg);
    });

    recorders = Array.fill(num_voices, { arg i;
      Synth.new(\recordBuf, [
        \bufnum, buffers[i].bufnum,
        \run, 0
      ], target: pg);
    });

    context.server.sync;

    this.addCommand("read", "is", { arg msg;
      var voice = msg[1] - 1;
      this.readBuf(voice, msg[2]);
    });

    this.addCommand("record", "ii", { arg msg;
      var voice = msg[1] - 1;
      recorders[voice].set(\run, msg[2]);
    });

    this.addCommand("pre_level", "if", { arg msg;
      var voice = msg[1] - 1;
      recorders[voice].set(\preLevel, msg[2]);
    });

    this.addCommand("rec_level", "if", { arg msg;
      var voice = msg[1] - 1;
      recorders[voice].set(\recLevel, msg[2]);
    });

    this.addCommand("seek", "if", { arg msg;
      var voice = msg[1] - 1;

      voices[voice].set(\pos, msg[2]);
      voices[voice].set(\pos_trig, 1);
    });

    this.addCommand("gate", "ii", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\gate, msg[2]);
    });

    this.addCommand("speed", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\speed, msg[2]);
    });

    this.addCommand("jitter", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\jitter, msg[2]);
    });

    this.addCommand("size", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\size, msg[2]);
    });

    this.addCommand("density", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\density, msg[2]);
    });

    this.addCommand("pitch", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\pitch, msg[2]);
    });

    this.addCommand("spread", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\spread, msg[2]);
    });

    this.addCommand("gain", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\gain, msg[2]);
    });

    this.addCommand("envscale", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\envscale, msg[2]);
    });

    this.addCommand("filter_cutoff", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\filter_cutoff, msg[2]);
    });

    this.addCommand("filter_q", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\filter_q, msg[2]);
    });
  }

  free {
    voices.do({ arg voice; voice.free; });
    buffers.do({ arg b; b.free; });
    recorders.do({ arg r; r.free; });
  }
}
