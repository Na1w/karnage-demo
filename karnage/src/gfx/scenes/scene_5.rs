use crate::gfx::modulators::RampingLfo;
use infinitegfx_core::core::GfxChain;
use infinitegfx_core::effects::{fade, glass};
use wgpu::TextureFormat;

use super::scene_5;
use super::twistscroller;

pub fn scene_5_chain(format: TextureFormat) -> GfxChain {
    GfxChain::new(format)
        .and(scene_5())
        .and(glass(RampingLfo {
            frequency: 0.12,
            min_start: 0.0,
            max_start: 0.2,
            min_end: 0.0,
            max_end: 3.5,
            start_time: 120.5,
            duration: 30.0,
        }))
        .and(twistscroller(
            "KARNAGE . . . DESIGN .... AUDIO .... AND PROGRAMMING BY FREDRIK ANDERSSON ..... THIS IS A TEST BENCH FOR AN UPCOMING LIBRARY THAT INTEGRATES INFINITEDSP WITH VISUAL EFFECTS .... IT SUPPORTS TRANSITIONS .... MULTIPLE BUFFERS... LAYERED EFFECTS AND SCENE GRAPHS AT THIS MOMENT .... MORE TO COME",
            128.0,
            0.0,
        ))
        .and(fade(120.5, 2.0))
}
