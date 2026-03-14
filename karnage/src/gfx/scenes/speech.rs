use infinitegfx_core::effects::TextEffect;
use wgpu::TextureFormat;

pub fn speech_chain(format: TextureFormat) -> infinitegfx_core::core::GfxChain {
    use infinitegfx_core::core::GfxChain;

    GfxChain::new(format)
        .isolated()
        .and(
            TextEffect::new("WELCOME", 0.4, 1.8)
                .with_pos(31.5, 0.0)
                .with_color([1.0, 1.0, 1.0]),
        )
        .and(
            TextEffect::new("PREPARE", 1.8, 2.5)
                .with_pos(31.5, 0.0)
                .with_color([1.0, 1.0, 1.0]),
        )
        .and(
            TextEffect::new("PREPARE FOR", 2.5, 3.3)
                .with_pos(49.5, 0.0)
                .with_color([1.0, 1.0, 1.0]),
        )
        .and(
            TextEffect::new("PREPARE FOR DEMO", 3.3, 4.5)
                .with_pos(72.0, 0.0)
                .with_color([1.0, 1.0, 1.0]),
        )
}
