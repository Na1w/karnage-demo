use infinitedsp_core::FrameProcessor;
use infinitedsp_core::core::channels::Mono;
use infinitemedia_core::MediaState;
use std::sync::Arc;
use std::sync::atomic::Ordering;

pub struct GlitchProcessor {
    pub sr: f32,

    pub state: Arc<MediaState>,
}

impl FrameProcessor<Mono> for GlitchProcessor {
    fn process(&mut self, buffer: &mut [f32], clock: u64) {
        let k_gate = f32::from_bits(self.state.parameters[0].load(Ordering::Relaxed));
        let intensity = f32::from_bits(self.state.parameters[2].load(Ordering::Relaxed));

        for (i, sample) in buffer.iter_mut().enumerate() {
            let current_clock = clock + i as u64;

            let glitch_seed = (current_clock as f32 / (self.sr / 30.0)).floor();
            let h = ((glitch_seed * 127.1).sin() * 43_758.547).fract().abs();

            if h < (k_gate * intensity * 0.7) {
                *sample =
                    (((current_clock as f32 * 123.456).sin() * 456.789).fract() * 2.0 - 1.0) * 0.2;
            } else {
                *sample = 0.0;
            }
        }
    }
    fn set_sample_rate(&mut self, sr: f32) {
        self.sr = sr;
    }
}

#[allow(dead_code)]
pub struct OrbSwooshProcessor {
    pub visual_delay: f32,

    pub sr: f32,
}

impl FrameProcessor<Mono> for OrbSwooshProcessor {
    fn process(&mut self, buffer: &mut [f32], clock: u64) {
        for (i, sample) in buffer.iter_mut().enumerate() {
            let t_abs = (clock + i as u64) as f32 / self.sr;
            let t_visual = (t_abs - self.visual_delay).max(0.0);
            *sample = 0.0;
            if t_visual > 25.0 && t_visual < 60.0 {
                let orb_interval = 8.0f32;
                let orb_t = t_visual - 25.0;
                let orb_cycle = (orb_t / orb_interval).floor();
                let orb_fract = (orb_t / orb_interval).fract();
                let p_speed = 120.0f32;
                let cam_speed = 28.0f32;

                let ro_z = (t_visual - 12.0) * cam_speed;
                let z_at_spawn = (orb_cycle * orb_interval + 25.0 - 12.0) * cam_speed;
                let z_start = z_at_spawn + 400.0;
                let orb_z = z_start - orb_fract * orb_interval * p_speed;

                let dist_z = (ro_z - orb_z).abs();
                if dist_z < 30.0 {
                    let swoosh_env = (1.0 - dist_z / 30.0).max(0.0).powi(3);
                    let noise_val =
                        (((clock + i as u64) as f32 * 0.005).sin() * 789.012).fract() * 2.0 - 1.0;
                    *sample = noise_val * swoosh_env * 0.25;
                }
            }
        }
    }
    fn set_sample_rate(&mut self, sr: f32) {
        self.sr = sr;
    }
}
