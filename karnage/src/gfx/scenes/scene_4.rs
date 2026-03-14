use infinitegfx_core::core::GfxChain;
use std::sync::Arc;
use std::sync::atomic::{AtomicU32, AtomicUsize};
use wgpu::TextureFormat;

use super::oscilloscope;
use super::scene_4;
use super::tesseract;

pub fn scene_4_chain(
    format: TextureFormat,
    waveform: Arc<Vec<AtomicU32>>,
    waveform_ptr: Arc<AtomicUsize>,
) -> GfxChain {
    GfxChain::new(format)
        .and(scene_4())
        .and(tesseract())
        .and(oscilloscope(
            waveform,
            waveform_ptr,
            0.35,
            0.1,
            [0.1, 1.0, 0.4],
        ))
}
