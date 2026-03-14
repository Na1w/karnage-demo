use bytemuck;
use infinitegfx_core::core::GfxParam;
use infinitegfx_core::effects::{ShaderInputs, ShaderNode};
use std::sync::Arc;
use std::sync::atomic::{AtomicU32, AtomicUsize, Ordering};

#[repr(C)]
#[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
pub struct OscUniforms {
    pub samples: [[f32; 4]; 128],

    pub y_pos: f32,

    pub height: f32,

    pub waveform_ptr: u32,

    pub _pad_inner: f32,

    pub color: [f32; 4],
}

pub fn oscilloscope(
    waveform: Arc<Vec<AtomicU32>>,
    waveform_ptr: Arc<AtomicUsize>,
    y_pos: impl Into<GfxParam>,
    height: impl Into<GfxParam>,
    color: [f32; 3],
) -> ShaderNode {
    let mut y_pos = y_pos.into();
    let mut height = height.into();

    ShaderNode::new(
        "Oscilloscope",
        include_str!("../shaders/oscilloscope.wgsl"),
        ShaderInputs::One,
    )
    .with_uniforms(move |t| {
        let mut packed_samples = [[0.0f32; 4]; 128];

        for (i, slot) in packed_samples.iter_mut().enumerate().take(128) {
            let i4 = i * 4;
            *slot = [
                f32::from_bits(waveform[i4].load(Ordering::Relaxed)),
                f32::from_bits(waveform[i4 + 1].load(Ordering::Relaxed)),
                f32::from_bits(waveform[i4 + 2].load(Ordering::Relaxed)),
                f32::from_bits(waveform[i4 + 3].load(Ordering::Relaxed)),
            ];
        }

        let ptr = waveform_ptr.load(Ordering::Relaxed) as u32;

        OscUniforms {
            samples: packed_samples,
            y_pos: y_pos.get_value(t),
            height: height.get_value(t),
            waveform_ptr: ptr,
            _pad_inner: 0.0,
            color: [color[0], color[1], color[2], 1.0],
        }
    })
}
