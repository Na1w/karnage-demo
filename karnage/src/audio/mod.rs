pub mod processors;

use crate::audio::processors::GlitchProcessor;
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use infinitedsp_core::FrameProcessor;
use infinitedsp_core::core::audio_param::AudioParam;
use infinitedsp_core::core::dsp_chain::DspChain;
use infinitedsp_core::core::parameter::Parameter;
use infinitedsp_core::effects::dynamics::distortion::{Distortion, DistortionType};
use infinitedsp_core::effects::filter::predictive_ladder::PredictiveLadderFilter;
use infinitedsp_core::effects::spectral::granular_pitch::GranularPitchShift;
use infinitedsp_core::effects::time::delay::Delay;
use infinitedsp_core::effects::time::reverb::Reverb;
use infinitedsp_core::synthesis::oscillator::{Oscillator, Waveform};
use infinitedsp_core::synthesis::speech::{Phoneme, SpeechSynth};
use infinitemedia_core::{MediaAction, MediaState, Timeline};
use log::{error, info};
use std::sync::Arc;
use std::sync::atomic::Ordering;

fn smoothstep(edge0: f32, edge1: f32, x: f32) -> f32 {
    let t = ((x - edge0) / (edge1 - edge0)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

pub fn start_audio(
    state: Arc<MediaState>,
    timeline: Arc<Timeline<MediaAction>>,
    start_offset: f32,
) {
    #[cfg(not(target_arch = "wasm32"))]
    {
        std::thread::spawn(move || {
            run_audio(state, timeline, start_offset);
        });
    }

    #[cfg(target_arch = "wasm32")]
    {
        let stream = run_audio(state, timeline, start_offset);
        std::mem::forget(stream);
    }
}

#[cfg(not(target_arch = "wasm32"))]
fn run_audio(state: Arc<MediaState>, timeline: Arc<Timeline<MediaAction>>, start_offset: f32) {
    let (_stream, _config) = setup_audio_stream(state, timeline, start_offset);
    loop {
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}

#[cfg(target_arch = "wasm32")]
fn run_audio(
    state: Arc<MediaState>,
    timeline: Arc<Timeline<MediaAction>>,
    start_offset: f32,
) -> cpal::Stream {
    let (stream, _config) = setup_audio_stream(state, timeline, start_offset);
    stream.play().expect("Failed to play stream");
    stream
}

fn setup_audio_stream(
    state: Arc<MediaState>,
    timeline: Arc<Timeline<MediaAction>>,
    start_offset: f32,
) -> (cpal::Stream, cpal::StreamConfig) {
    let host = cpal::default_host();
    let device = host.default_output_device().expect("No audio device");
    let config_sup = device.default_output_config().expect("No config");
    let config = config_sup.config();
    let sr = config.sample_rate as f32;

    info!("Audio initialized (sr: {})", sr);

    let mut speech = SpeechSynth::new(sr);
    let mut phonemes_vec = Vec::new();
    let sequence = [
        "W", "E", "L", "K", "U", "M", "GAP", "P", "R", "E", "P", "E", "R", "GAP", "F", "O", "R",
        "GAP", "D", "E", "M", "O",
    ];
    for token in sequence {
        phonemes_vec.extend_from_slice(Phoneme::from_token(token));
    }
    let phonemes: &'static [Phoneme] = Box::leak(phonemes_vec.into_boxed_slice());
    if start_offset < 0.1 {
        speech.set_phonemes(phonemes);
    }

    let mut voice_chain = DspChain::new(speech, sr)
        .and(GranularPitchShift::new(30.0, AudioParam::linear(-0.8)))
        .and(Delay::new(
            1.0,
            AudioParam::linear(0.25),
            AudioParam::linear(0.08),
            AudioParam::linear(1.0),
        ))
        .to_stereo()
        .and_mix(
            0.1,
            Reverb::new_with_params(AudioParam::linear(0.6), AudioParam::linear(0.15), 1337),
        );

    let mut bass_osc = Oscillator::new(AudioParam::hz(55.0), Waveform::Saw);
    let bass_cutoff = Parameter::new(500.0);
    let bass_res = Parameter::new(0.88);
    let mut bass_filter = PredictiveLadderFilter::new(
        AudioParam::Linked(bass_cutoff.clone()),
        AudioParam::Linked(bass_res.clone()),
    );
    let mut bass_dist = Distortion::new(
        AudioParam::linear(14.0),
        AudioParam::linear(0.3),
        DistortionType::SoftClip,
    );

    let mut hat_osc = Oscillator::new(AudioParam::hz(10000.0), Waveform::WhiteNoise);
    let mut hat_filter =
        PredictiveLadderFilter::new(AudioParam::hz(8000.0), AudioParam::linear(0.2));

    let mut kick = Oscillator::new(AudioParam::hz(50.0), Waveform::Sine);

    bass_osc.set_sample_rate(sr);
    bass_filter.set_sample_rate(sr);
    bass_dist.set_sample_rate(sr);
    hat_osc.set_sample_rate(sr);
    hat_filter.set_sample_rate(sr);
    kick.set_sample_rate(sr);

    let mut glitch = GlitchProcessor {
        sr,
        state: state.clone(),
    };

    let k_decay = (0.9993f32).powf(44100.0 / sr);
    let b_decay = (0.9990f32).powf(44100.0 / sr);
    let h_decay = (0.9985f32).powf(44100.0 / sr);

    let mut clock = (start_offset * sr) as u64;
    let mut k_env = 0.0f32;
    let mut b_env = 0.0f32;
    let mut h_env = 0.0f32;
    let mut current_freq = 55.0f32;
    let mut accent_active = false;

    let max_block_size = 4096;
    let mut voice_buf = vec![0.0; max_block_size * 2];
    let mut bass_buf = vec![0.0; max_block_size];
    let mut kick_buf = vec![0.0; max_block_size];
    let mut hat_buf = vec![0.0; max_block_size];
    let mut glitch_buf = vec![0.0; max_block_size];
    let mut swoosh_buf = vec![0.0; max_block_size];

    let channels = config.channels as usize;
    state.sample_rate.store(sr.to_bits(), Ordering::Relaxed);

    let stream = device
        .build_output_stream(
            &config,
            move |data: &mut [f32], _| {
                let block_size = data.len() / channels;
                let v_slice = &mut voice_buf[..block_size * 2];
                let b_slice = &mut bass_buf[..block_size];
                let k_slice = &mut kick_buf[..block_size];
                let h_slice = &mut hat_buf[..block_size];
                let g_slice = &mut glitch_buf[..block_size];
                let s_slice = &mut swoosh_buf[..block_size];

                v_slice.fill(0.0);
                voice_chain.process(v_slice, clock);

                let cur_t = clock as f32 / sr;
                let next_t = (clock + block_size as u64) as f32 / sr;

                let mut active_seq_data = None;
                for event in timeline.active_at(cur_t) {
                    if let MediaAction::AudioSequence(seq) = &event.data {
                        active_seq_data = Some((event.start, event.end, seq.clone()));
                        break;
                    }
                }

                let triggers = timeline.find_in_range(cur_t, next_t);
                for trigger in triggers {
                    match trigger.data {
                        MediaAction::Trigger(id) => match id {
                            0 => k_env = 1.0,
                            1 => {
                                b_env = 1.0;
                                accent_active = false;
                            }
                            2 => {
                                b_env = 1.0;
                                accent_active = true;
                            }
                            3 => h_env = 1.0,
                            4 => h_env = 0.4,
                            _ => {}
                        },
                        MediaAction::Parameter(id, val) => {
                            if id == 4 {
                                current_freq = val;
                            }
                        }
                        _ => {}
                    }
                }

                for i in 0..block_size {
                    let cur_clock = clock + i as u64;
                    let t = cur_clock as f32 / sr;
                    let t_v = (t - 4.5).max(0.0);

                    k_env *= k_decay;
                    b_env *= b_decay;
                    h_env *= h_decay;

                    kick.frequency = AudioParam::hz(40.0 + k_env * k_env * 180.0);
                    let mut kv = [0.0];
                    kick.process(&mut kv, cur_clock);
                    k_slice[i] = kv[0] * k_env * 1.1;

                    bass_osc.frequency = AudioParam::hz(current_freq);
                    let mut bv = [0.0];
                    bass_osc.process(&mut bv, cur_clock);
                    let lfo = (t_v * 0.15).sin() * 0.5 + 0.5;
                    let cutoff = 100.0
                        + (b_env * 2800.0)
                        + (if accent_active { 2000.0 } else { 0.0 })
                        + (lfo * 1200.0);
                    bass_cutoff.set(cutoff);
                    bass_res.set(if accent_active { 0.94 } else { 0.87 });
                    let mut fbv = [bv[0]];
                    bass_filter.process(&mut fbv, cur_clock);
                    let ducking = (1.0 - k_env * 0.95).max(0.05);
                    b_slice[i] = fbv[0] * b_env * 0.65 * ducking;

                    let mut hv = [0.0];
                    hat_osc.process(&mut hv, cur_clock);
                    let mut fhv = [hv[0]];
                    hat_filter.process(&mut fhv, cur_clock);
                    h_slice[i] = fhv[0] * h_env * 0.25;
                }

                bass_dist.process(b_slice, clock);
                g_slice.fill(0.0);
                glitch.process(g_slice, clock);

                for (i, sample) in s_slice.iter_mut().enumerate().take(block_size) {
                    let cur_clock = clock + i as u64;
                    let t_cur = cur_clock as f32 / sr;

                    if t_cur > 25.0 && t_cur < 60.0 {
                        let dt = t_cur - 12.0;
                        let speed_boost = smoothstep(37.0, 45.0, dt) * (dt - 37.0) * 28.0;
                        let cam_z = dt * 28.0 + speed_boost;

                        let orb_interval = 8.0;
                        let orb_t = t_cur - 25.0;
                        let orb_cycle = (orb_t / orb_interval).floor();
                        let orb_fract = (orb_t / orb_interval).fract();
                        let p_speed = 120.0;

                        let z_at_spawn = (orb_cycle * orb_interval + 25.0 - 12.0) * 28.0;
                        let z_start = z_at_spawn + 400.0;
                        let orb_z = z_start - orb_fract * orb_interval * p_speed;

                        let dist_z = (cam_z - orb_z).abs();
                        if dist_z < 30.0 {
                            let swoosh = ((1.0 - dist_z / 30.0).max(0.0)).powi(3);
                            let noise =
                                ((cur_clock as f32 * 0.003).sin() * 789.0).fract() * 2.0 - 1.0;
                            *sample = noise * swoosh * 0.25;
                        } else {
                            *sample = 0.0;
                        }
                    } else {
                        *sample = 0.0;
                    }
                }

                let waveform_len = state.waveform.len();
                let samples_to_copy = block_size.min(waveform_len);
                let mut ptr = state.waveform_ptr.load(Ordering::Relaxed);

                for j in 0..samples_to_copy {
                    let s_mix = (k_slice[j]
                        + b_slice[j]
                        + h_slice[j]
                        + g_slice[j] * 0.8
                        + s_slice[j] * 1.3)
                        * 0.45;
                    state.waveform[ptr % waveform_len].store(s_mix.to_bits(), Ordering::Relaxed);
                    ptr = (ptr + 1) % waveform_len;
                }
                state.waveform_ptr.store(ptr, Ordering::Relaxed);

                for (i, frame) in data.chunks_mut(channels).enumerate() {
                    let mix = (k_slice[i]
                        + b_slice[i]
                        + h_slice[i]
                        + g_slice[i] * 0.8
                        + s_slice[i] * 1.3)
                        * 0.45;

                    let cur_t = (clock + i as u64) as f32 / sr;

                    let mut fade_in = 1.0;
                    let mut fade_out = 1.0;

                    if let Some((start, end, seq)) = &active_seq_data {
                        if seq.fade_in > 0.0 {
                            fade_in = ((cur_t - start) / seq.fade_in).clamp(0.0, 1.0);
                        }
                        if seq.fade_out > 0.0 {
                            fade_out = ((end - cur_t) / seq.fade_out).clamp(0.0, 1.0);
                        }
                    } else {
                        fade_in = 0.0;
                        fade_out = 0.0;
                    }

                    let music = mix * fade_in * fade_out;

                    if frame.len() >= 2 {
                        frame[0] = music + v_slice[i * 2] * 0.15;
                        frame[1] = music + v_slice[i * 2 + 1] * 0.15;
                    } else {
                        frame[0] = music + v_slice[i * 2] * 0.15;
                    }
                }

                clock += block_size as u64;
                state
                    .audio_time
                    .store((clock as f32 / sr).to_bits(), Ordering::Relaxed);

                state.parameters[0].store(k_env.to_bits(), Ordering::Relaxed);
                state.parameters[1].store(b_env.to_bits(), Ordering::Relaxed);
            },
            |e| error!("{}", e),
            None,
        )
        .unwrap();

    #[cfg(not(target_arch = "wasm32"))]
    stream.play().unwrap();
    (stream, config)
}
