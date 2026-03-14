use crate::gfx::modulators::{AudioBridge, KickPumper, LinearSweep};
use infinitedsp_core::core::audio_param::AudioParam;
use infinitedsp_core::synthesis::lfo::{Lfo, LfoWaveform};
use infinitegfx_core::core::GfxChain;
use infinitegfx_core::core::GfxParam;
use infinitegfx_core::effects::{TextEffect, fade, glitch, haze, sparkle};
use infinitemedia_core::MediaState;
use std::sync::Arc;
use wgpu::TextureFormat;

pub fn intro_chain(format: TextureFormat, state: Arc<MediaState>) -> GfxChain {
    let kick_param = state.parameters[0].clone();
    let sample_rate = state.sample_rate.clone();

    GfxChain::new(format)
        .and(super::intro())
        .and(sparkle())
        .and(
            TextEffect::new("SONIXWAVE", 4.5, 7.5)
                .with_pos(40.0, 0.0)
                .with_fade(1.0, 0.5)
                .with_color([0.5, 0.8, 1.0]),
        )
        .and(
            TextEffect::new("PRESENTS", 7.5, 9.5)
                .with_pos(36.0, 0.0)
                .with_fade(0.3, 0.8)
                .with_color([0.5, 0.8, 1.0]),
        )
        .and(
            TextEffect::new("A NEW", 9.5, 11.5)
                .with_pos(
                    LinearSweep {
                        start: 60.0,
                        end: -60.0,
                        start_time: 9.5,
                        duration: 2.0,
                    },
                    0.0,
                )
                .with_fade(0.5, 0.5)
                .with_color([0.5, 0.8, 1.0]),
        )
        .and(
            TextEffect::new("PRODUCTION", 11.5, 14.0)
                .with_pos(
                    AudioBridge {
                        param: AudioParam::Dynamic({
                            let mut lfo = Lfo::new(AudioParam::hz(1.0), LfoWaveform::Sine);
                            lfo.set_range(10.0, 70.0);
                            Box::new(lfo)
                        }),
                        shared_sample_rate: sample_rate,
                        last_clock: 0,
                    },
                    0.0,
                )
                .with_fade(0.8, 0.2)
                .with_color([0.5, 0.8, 1.0]),
        )
        .and(
            GfxChain::new(format)
                .isolated()
                .and(
                    TextEffect::new("KARNAGE", 14.0, 24.5)
                        .with_pos(32.0, 0.0)
                        .with_scale(KickPumper {
                            shared_value: kick_param.clone(),
                            base: 1.0,
                            amount: 0.3,
                        })
                        .with_modulation(2.0, 10.0, 1.0, 15.0)
                        .with_fade(0.1, 10.0)
                        .with_color([0.9, 0.9, 1.0]),
                )
                .and(glitch(GfxParam::Static(0.8), GfxParam::Linked(kick_param))),
        )
        .and(haze(
            0.0,
            LinearSweep {
                start: 0.0,
                end: 1.0,
                start_time: 14.0,
                duration: 6.0,
            },
        ))
        .and(fade(9.0, 2.0))
}
