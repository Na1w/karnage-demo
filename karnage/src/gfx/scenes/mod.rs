use infinitegfx_core::effects::{ShaderInputs, ShaderNode};

pub mod intro;
pub mod scene_4;
pub mod scene_5;
pub mod speech;

pub mod oscilloscope;
pub mod twistscroller;

pub use intro::intro_chain;
pub use oscilloscope::oscilloscope;
pub use scene_4::scene_4_chain;
pub use scene_5::scene_5_chain;
pub use speech::speech_chain;
pub use twistscroller::twistscroller;

pub fn scene_2() -> ShaderNode {
    ShaderNode::new(
        "Scene2",
        include_str!("../shaders/scene_2.wgsl"),
        ShaderInputs::None,
    )
}

pub fn scene_5() -> ShaderNode {
    ShaderNode::new(
        "Scene5",
        include_str!("../shaders/scene_5.wgsl"),
        ShaderInputs::None,
    )
}

pub fn intro() -> ShaderNode {
    ShaderNode::new(
        "Intro",
        include_str!("../shaders/intro.wgsl"),
        ShaderInputs::None,
    )
}

pub fn scene_3() -> ShaderNode {
    ShaderNode::new(
        "Scene3",
        include_str!("../shaders/scene_3.wgsl"),
        ShaderInputs::None,
    )
}

pub fn scene_4() -> ShaderNode {
    ShaderNode::new(
        "Scene4",
        include_str!("../shaders/scene_4.wgsl"),
        ShaderInputs::None,
    )
}

pub fn tesseract() -> ShaderNode {
    ShaderNode::new(
        "TesseractEffect",
        include_str!("../shaders/tesseract.wgsl"),
        ShaderInputs::One,
    )
}

pub fn solid_color(color: [f32; 4]) -> ShaderNode {
    use infinitegfx_core::effects::solid_color as solid_fx;
    solid_fx(color)
}
