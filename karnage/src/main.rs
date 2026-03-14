#![cfg_attr(target_arch = "wasm32", no_main)]

mod app;
mod audio;
mod gfx;
pub mod karnage;

use crate::app::App;
use winit::event_loop::EventLoop;

#[cfg(target_arch = "wasm32")]
use wasm_bindgen::prelude::*;

#[cfg_attr(target_arch = "wasm32", wasm_bindgen(start))]
pub fn main() {
    #[cfg(not(target_arch = "wasm32"))]
    {
        env_logger::builder()
            .filter_level(log::LevelFilter::Info)
            .init();
    }
    #[cfg(target_arch = "wasm32")]
    {
        console_log::init_with_level(log::Level::Info).expect("error initializing logger");
        std::panic::set_hook(Box::new(console_error_panic_hook::hook));
    }

    #[cfg(not(target_arch = "wasm32"))]
    let (start_time, allow_mode_switch) = {
        let mut st = 0.0;
        let mut ams = false;
        let args: Vec<String> = std::env::args().collect();
        for arg in &args[1..] {
            if arg == "--switch" {
                ams = true;
            } else if let Ok(t) = arg.parse::<f32>() {
                st = t;
            }
        }
        (st, ams)
    };

    #[cfg(target_arch = "wasm32")]
    let (start_time, allow_mode_switch) = (0.0, false);

    let mut app = App::new(start_time, allow_mode_switch);
    let event_loop = EventLoop::new().unwrap();
    event_loop.run_app(&mut app).unwrap();
}
