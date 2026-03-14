use infinitegfx_core::effects::fade as fx_fade;
use infinitegfx_core::effects::ShaderNode;


pub fn fade(start_time: f32, duration: f32) -> ShaderNode {
    fx_fade(start_time, duration)
}