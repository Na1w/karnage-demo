use bytemuck;
use infinitegfx_core::core::GfxParam;
use infinitegfx_core::effects::{ShaderInputs, ShaderNode};
use infinitegfx_core::font::DEFAULT_FONT;

#[repr(C)]
#[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
pub struct TwistScrollerStatic {
    pub char_ids: [[i32; 4]; 256],

    pub font_chars: [[u32; 4]; 16],
}

#[repr(C)]
#[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
pub struct TwistScrollerUniforms {
    pub num_chars: i32,

    pub y_pos: f32,

    pub height: f32,

    pub speed: f32,

    pub twistscroller_amount: f32,

    pub start_time: f32,

    pub _pad: [f32; 2],
}

pub fn twistscroller(text: &str, start_time: f32, y_pos: impl Into<GfxParam>) -> ShaderNode {
    let mut ids = [[-1; 4]; 256];
    let mut count = 0;
    for (i, c) in text.chars().enumerate().take(1024) {
        let v_idx = i / 4;
        let c_idx = i % 4;
        let char_id = match c.to_ascii_uppercase() {
            'A' => 0,
            'B' => 1,
            'C' => 2,
            'D' => 3,
            'E' => 4,
            'F' => 5,
            'G' => 6,
            'H' => 7,
            'I' => 8,
            'J' => 9,
            'K' => 10,
            'L' => 11,
            'M' => 12,
            'N' => 13,
            'O' => 14,
            'P' => 15,
            'Q' => 16,
            'R' => 17,
            'S' => 18,
            'T' => 19,
            'U' => 20,
            'V' => 21,
            'W' => 22,
            'X' => 23,
            'Y' => 24,
            'Z' => 25,
            ' ' => 26,
            ':' => 27,
            '.' => 28,
            _ => -1,
        };
        ids[v_idx][c_idx] = char_id;
        count = i + 1;
    }

    let mut packed_font = [[0u32; 4]; 16];
    for (i, char_data) in DEFAULT_FONT.iter().enumerate().take(27) {
        let u32_idx = i * 2;
        packed_font[u32_idx / 4][u32_idx % 4] = char_data[0];
        packed_font[(u32_idx + 1) / 4][(u32_idx + 1) % 4] = char_data[1];
    }

    let static_data = TwistScrollerStatic {
        char_ids: ids,
        font_chars: packed_font,
    };

    let mut y_pos_param = y_pos.into();

    ShaderNode::new(
        "TwistScrollerEffect",
        include_str!("../shaders/twistscroller.wgsl"),
        ShaderInputs::One,
    )
    .with_static_data(&static_data)
    .with_uniforms(move |t| TwistScrollerUniforms {
        num_chars: count as i32,
        y_pos: y_pos_param.get_value(t),
        height: 0.08,
        speed: 0.5,
        twistscroller_amount: 0.5,
        start_time,
        _pad: [0.0; 2],
    })
}
