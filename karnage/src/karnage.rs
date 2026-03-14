use crate::gfx::scenes::{
    intro_chain, scene_2, scene_3, scene_4_chain, scene_5_chain, solid_color, speech_chain,
};
use crate::gfx::{MediaEngine, TransitionKind};
use infinitegfx_core::StandardGlobals;
use infinitegfx_core::core::GfxChain;
use infinitemedia_core::{AudioSequence, MediaAction, MediaState, Timeline};
use std::sync::Arc;

fn karnage_globals_builder(
    state: &MediaState,
    time: f32,
    dt: f32,
    width: u32,
    height: u32,
    tesser_rot: &mut f32,
) -> StandardGlobals {
    use std::sync::atomic::Ordering;
    let kick = f32::from_bits(state.parameters[0].load(Ordering::Relaxed));
    let sweep = f32::from_bits(state.parameters[1].load(Ordering::Relaxed));
    let fade = (time / 2.0).clamp(0.0, 1.0);

    *tesser_rot += dt * 1.5 + kick * dt * 12.0;

    StandardGlobals {
        time,
        kick,
        sweep,
        res_x: width as f32,
        res_y: height as f32,
        fade,
        p2: 0.0,
        p3: *tesser_rot,
    }
}

fn add_audio_sequence(
    mut engine: MediaEngine,
    start: f32,
    end: f32,
    sequence: AudioSequence,
) -> MediaEngine {
    Arc::make_mut(&mut engine.content.timeline).add(
        start,
        end,
        MediaAction::AudioSequence(sequence.clone()),
    );

    let step_duration = sequence.step_duration();
    let mut current_t = start;
    let mut step = 0;

    while current_t < end {
        let step_idx = step % sequence.base_pattern.len();
        let trans_idx = (step / sequence.base_pattern.len()) % sequence.transpositions.len();
        let is_accented = sequence.accents.get(step_idx).copied().unwrap_or(0.0) > 0.5;

        let step_in_beat = step % 4;

        if step_in_beat == 0 {
            engine = engine.with_trigger(current_t, current_t + 0.1, 0);
        }

        if is_accented {
            engine = engine.with_trigger(current_t, current_t + 0.1, 2);
        } else {
            engine = engine.with_trigger(current_t, current_t + 0.1, 1);
        }

        let base_freq = sequence.base_pattern[step_idx];
        let trans = sequence.transpositions[trans_idx];
        let freq = sequence.root_freq * trans * base_freq;
        engine = engine.with_parameter(current_t, current_t + 0.1, 4, freq);

        if step_in_beat == 2 {
            engine = engine.with_trigger(current_t, current_t + 0.1, 3);
        } else {
            engine = engine.with_trigger(current_t, current_t + 0.1, 4);
        }

        current_t += step_duration;
        step += 1;
    }

    engine
}

pub fn karnage_music() -> AudioSequence {
    AudioSequence::new(4.5, 204.0, 140.0)
        .with_fades(2.0, 5.0)
        .with_steps_per_beat(4)
        .with_root(55.0)
        .with_pattern(vec![
            1.0, 1.0, 2.0, 1.0, 1.189, 1.0, 1.0, 2.0, 1.0, 1.0, 1.782, 1.0, 2.0, 1.0, 1.189, 0.891,
        ])
        .with_accents(vec![
            0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, 1.0, 0.0, 1.0, 0.0,
        ])
        .with_transpositions(vec![
            1.0, 1.0, 1.0, 1.0, 0.7937, 0.7937, 1.0, 1.0, 1.0, 1.0, 1.1892, 1.1892, 1.0, 1.0, 1.0,
            1.0,
        ])
}

pub fn populate_audio(engine: MediaEngine) -> MediaEngine {
    let music = karnage_music();
    add_audio_sequence(engine, music.start, music.end, music)
}

pub fn build_demo(
    state: Arc<MediaState>,
    timeline: Arc<Timeline<MediaAction>>,
    format: wgpu::TextureFormat,
) -> MediaEngine {
    let mut engine = MediaEngine::new(state.clone())
        .with_timeline(timeline)
        .with_globals_builder(karnage_globals_builder);

    let speech = speech_chain(format);
    engine = engine.with_scene(0.0, 4.5, speech);

    let intro = intro_chain(format, state.clone());
    engine = engine.with_scene(4.5, 18.5, intro);
    engine = engine.with_transition(18.5, 21.5, 1, 2, TransitionKind::Flip);

    let scene_tunnel = GfxChain::new(format).and(scene_2());
    engine = engine.with_scene(21.5, 71.5, scene_tunnel);
    engine = engine.with_transition(71.5, 79.5, 2, 3, TransitionKind::SpaceBend);

    let scene_sanctuary = GfxChain::new(format).and(scene_3());
    engine = engine.with_scene(79.5, 96.5, scene_sanctuary);
    engine = engine.with_transition(96.5, 99.5, 3, 4, TransitionKind::Flip);

    let scene_grid = scene_4_chain(format, state.waveform.clone(), state.waveform_ptr.clone());
    engine = engine.with_scene(99.5, 119.5, scene_grid);
    engine = engine.with_transition(119.5, 123.5, 4, 5, TransitionKind::Crossfade);

    let scene_cyber = scene_5_chain(format);
    engine = engine.with_scene(123.5, 197.0, scene_cyber);
    engine = engine.with_transition(197.0, 205.0, 5, 6, TransitionKind::Crossfade);

    let scene_finale = GfxChain::new(format).and(solid_color([0.0, 0.0, 0.0, 1.0]));
    engine = engine.with_scene(205.0, 206.0, scene_finale);

    engine
}
