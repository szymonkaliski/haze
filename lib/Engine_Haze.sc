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
    buffers = Array.fill(num_voices, {
      arg i;

      var buf_dur = 8;

      Buffer.alloc(
        context.server,
        context.server.sampleRate * buf_dur,
        bufnum: i
      );
    });

    SynthDef(\recordBuf, {
      arg bufnum = 0, run = 0, pre_level = 1.0, rec_level = 1.0, in_gain = 1.0, filter_cutoff = 18000, filter_q = 1.0;

      var in_sig;

      in_sig = Mix.new(SoundIn.ar([0, 1]));
      // in_sig = BLowPass4.ar(in_sig, filter_cutoff, filter_q);

      // // noise gate
      // in_sig = Compander.ar(
      //   in_sig,
      //   in_sig,
      //   thresh: 0.003,
      //   slopeBelow: 10,
      //   slopeAbove: 1,
      //   clampTime: 0.01,
      //   relaxTime: 0.01
      // );

      in_sig = in_sig * in_gain;

      RecordBuf.ar(
        in_sig,
        bufnum,
        recLevel: rec_level,
        preLevel: pre_level,
        loop: 1,
        run: run
      );
    }).add;

    SynthDef(\synth, {
      arg out, buf, gate = 0, pos = 0, speed = 1, jitter_pos = 0, jitter_size = 0, size = 0.1, density = 20, pitch = 1.0, spread = 0, out_gain = 1.0, fade = 1, t_pos = 0, filter_cutoff = 18000, filter_q = 1;

      var t_grain;
      var jitter_pos_sig;
      var jitter_size_sig;
      var buf_dur;
      var pan;
      var buf_pos;
      var grain;
      var grain_level;
      var out_sig;

      t_grain = Impulse.kr(density);
      buf_dur = BufDur.kr(buf);

      pan = TRand.kr(
        trig: t_grain,
        lo: spread.neg,
        hi: spread
      );

      jitter_size_sig = TRand.kr(
        trig: t_grain,
        lo: buf_dur.reciprocal.neg * jitter_size,
        hi: buf_dur.reciprocal * jitter_size
      );

      jitter_pos_sig = TRand.kr(
        trig: t_grain,
        lo: buf_dur.reciprocal.neg * jitter_pos,
        hi: buf_dur.reciprocal * jitter_pos
      );

      buf_pos = Phasor.kr(
        trig: t_pos,
        rate: buf_dur.reciprocal / ControlRate.ir * speed,
        resetPos: pos
      );
      buf_pos = Wrap.kr(buf_pos + jitter_pos);

      size = Wrap.kr(size + jitter_size_sig, 0.001, 2);

      grain = GrainBuf.ar(2, t_grain, size, buf, pitch, buf_pos, 2, pan);
      grain = BLowPass4.ar(grain, filter_cutoff, filter_q);

      grain_level = EnvGen.ar(Env.asr(1, 1, 1), gate: gate, timeScale: fade);
      out_sig = LeakDC.ar(grain * grain_level * out_gain);
      Out.ar(out, out_sig);
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
      recorders[voice].set(\pre_level, msg[2]);
    });

    this.addCommand("rec_level", "if", { arg msg;
      var voice = msg[1] - 1;
      recorders[voice].set(\rec_level, msg[2]);
    });

    this.addCommand("pos", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\pos, msg[2]);
      voices[voice].set(\t_pos, 1);
    });

    this.addCommand("gate", "ii", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\gate, msg[2]);
    });

    this.addCommand("speed", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\speed, msg[2]);
    });

    this.addCommand("size", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\size, msg[2]);
    });

    this.addCommand("jitter_pos", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\jitter_pos, msg[2]);
    });

    this.addCommand("jitter_size", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\jitter_size, msg[2]);
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

    this.addCommand("out_gain", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\out_gain, msg[2]);
    });

    this.addCommand("in_gain", "if", { arg msg;
      var voice = msg[1] - 1;
      recorders[voice].set(\in_gain, msg[2]);
    });

    this.addCommand("fade", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\fade, msg[2]);
    });

    this.addCommand("filter_cutoff", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\filter_cutoff, msg[2]);
      recorders[voice].set(\filter_cutoff, msg[2]);
    });

    this.addCommand("filter_q", "if", { arg msg;
      var voice = msg[1] - 1;
      voices[voice].set(\filter_q, msg[2]);
      recorders[voice].set(\filter_q, msg[2]);
    });
  }

  free {
    voices.do({ arg voice; voice.free; });
    buffers.do({ arg b; b.free; });
    recorders.do({ arg r; r.free; });
  }
}
