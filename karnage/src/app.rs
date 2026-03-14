use crate::audio::start_audio;
use crate::gfx::{GfxBackend, GfxFrameProcessor, MediaEngine};
use crate::karnage::build_demo;
use infinitemedia_core::MediaState;
use log::error;
use std::sync::Arc;
use std::sync::atomic::Ordering;
use winit::application::ApplicationHandler;
use winit::event::{ElementState, KeyEvent, WindowEvent};
use winit::event_loop::ActiveEventLoop;
use winit::keyboard::{Key, NamedKey};
use winit::window::{Window, WindowId};

#[cfg(target_arch = "wasm32")]
use wasm_bindgen::prelude::*;

#[cfg(target_arch = "wasm32")]
use infinitemedia_core::{MediaAction, Timeline};

#[cfg(target_arch = "wasm32")]
use std::cell::RefCell;

#[cfg(target_arch = "wasm32")]
thread_local! {

    static GLOBAL_STATE: RefCell<Option<(Arc<MediaState>, Arc<Timeline<MediaAction>>)>> = const { RefCell::new(None) };
}

#[cfg(target_arch = "wasm32")]

static AUDIO_STARTED: std::sync::atomic::AtomicBool = std::sync::atomic::AtomicBool::new(false);

#[cfg(target_arch = "wasm32")]
#[wasm_bindgen]

pub fn wasm_start_demo() {
    if AUDIO_STARTED.load(Ordering::Relaxed) {
        return;
    }
    GLOBAL_STATE.with(|lock| {
        if let Some((state, timeline)) = lock.borrow().as_ref() {
            if !AUDIO_STARTED.load(Ordering::Relaxed) {
                start_audio(state.clone(), timeline.clone(), 0.0);
                AUDIO_STARTED.store(true, Ordering::Relaxed);

                if let Some(window) = web_sys::window() {
                    let _ = js_sys::eval("if(window.hideOverlay) window.hideOverlay();");
                }
            }
        }
    });
}

pub struct App {
    pub window: Option<Arc<Window>>,

    pub state: Arc<MediaState>,

    pub backend: Option<GfxBackend>,

    pub engine: MediaEngine,

    pub audio_started: bool,

    pub start_time_offset: f32,

    pub render_scale: f32,

    pub allow_mode_switch: bool,
    #[cfg(target_arch = "wasm32")]
    pub backend_receiver: Option<std::sync::mpsc::Receiver<GfxBackend>>,
}

impl App {
    pub fn new(start_time_offset: f32, allow_mode_switch: bool) -> Self {
        let state = Arc::new(MediaState::new(8));
        state
            .audio_time
            .store(start_time_offset.to_bits(), Ordering::Relaxed);

        let engine = MediaEngine::new(state.clone());

        #[cfg(target_arch = "wasm32")]
        GLOBAL_STATE.with(|lock| {
            *lock.borrow_mut() = Some((state.clone(), engine.content.timeline.clone()));
        });

        Self {
            window: None,
            state,
            backend: None,
            engine,
            audio_started: false,
            start_time_offset,
            render_scale: 2.0,
            allow_mode_switch,
            #[cfg(target_arch = "wasm32")]
            backend_receiver: None,
        }
    }

    fn maybe_start_audio(&mut self) {
        if !self.audio_started {
            start_audio(
                self.state.clone(),
                self.engine.content.timeline.clone(),
                self.start_time_offset,
            );
            self.audio_started = true;
            #[cfg(target_arch = "wasm32")]
            {
                AUDIO_STARTED.store(true, Ordering::Relaxed);
                if let Some(window) = web_sys::window() {
                    let _ = js_sys::eval("if(window.hideOverlay) window.hideOverlay();");
                }
            }
        }
    }

    fn get_render_size(&self) -> (u32, u32) {
        let size = self.window.as_ref().unwrap().inner_size();
        (
            (size.width as f32 / self.render_scale).max(1.0) as u32,
            (size.height as f32 / self.render_scale).max(1.0) as u32,
        )
    }

    fn update_fullscreen(&mut self) {
        if let Some(window) = &self.window {
            if self.render_scale < 1.0 || !self.allow_mode_switch {
                window.set_fullscreen(Some(winit::window::Fullscreen::Borderless(None)));
            } else {
                let monitor = window.current_monitor().unwrap();
                let size = window.inner_size();
                let target_w = (size.width as f32 / self.render_scale) as u32;
                let target_h = (size.height as f32 / self.render_scale) as u32;
                let mut best_mode = None;
                let mut min_diff = u32::MAX;
                for mode in monitor.video_modes() {
                    let m_size = mode.size();
                    let diff = m_size.width.abs_diff(target_w) + m_size.height.abs_diff(target_h);
                    if diff < min_diff {
                        min_diff = diff;
                        best_mode = Some(mode);
                    }
                }
                if let Some(mode) = best_mode {
                    window.set_fullscreen(Some(winit::window::Fullscreen::Exclusive(mode)));
                } else {
                    window.set_fullscreen(Some(winit::window::Fullscreen::Borderless(None)));
                }
            }
        }
    }
}

impl ApplicationHandler for App {
    fn resumed(&mut self, event_loop: &ActiveEventLoop) {
        if self.window.is_some() {
            return;
        }
        let window_attrs = Window::default_attributes()
            .with_title("KARNAGE")
            .with_fullscreen(Some(winit::window::Fullscreen::Borderless(None)));
        let window = Arc::new(event_loop.create_window(window_attrs).unwrap());

        #[cfg(target_arch = "wasm32")]
        {
            use winit::platform::web::WindowExtWebSys;
            if let Some(canvas) = window.canvas() {
                canvas.set_id("main-canvas");
                if let Some(window) = web_sys::window() {
                    if let Some(document) = window.document() {
                        if let Some(body) = document.body() {
                            let _ = body.append_child(&web_sys::Element::from(canvas));
                        }

                        if let Some(btn) = document.get_element_by_id("start-btn") {
                            btn.set_inner_html("Press me");
                            let closure = Closure::wrap(Box::new(move || {
                                wasm_start_demo();
                            })
                                as Box<dyn Fn()>);
                            use wasm_bindgen::JsCast;
                            let _ = btn.add_event_listener_with_callback(
                                "click",
                                closure.as_ref().unchecked_ref(),
                            );
                            closure.forget();
                        }
                    }
                }
            }
        }

        #[cfg(not(target_arch = "wasm32"))]
        window.set_cursor_visible(false);
        self.window = Some(window.clone());

        #[cfg(not(target_arch = "wasm32"))]
        {
            let backend = pollster::block_on(GfxBackend::new(window.clone()))
                .expect("Failed to init graphics");
            let handle = crate::gfx::GfxHandle {
                device: &backend.device,
                queue: &backend.queue,
                format: backend.format,
            };

            self.engine = build_demo(
                self.state.clone(),
                self.engine.content.timeline.clone(),
                backend.format,
            );
            self.engine.init(
                &handle,
                &backend
                    .device
                    .create_bind_group_layout(&wgpu::BindGroupLayoutDescriptor {
                        label: Some("DummyLayout"),
                        entries: &[],
                    }),
            );
            self.backend = Some(backend);
            self.update_fullscreen();
            self.maybe_start_audio();
        }

        #[cfg(target_arch = "wasm32")]
        {
            use wasm_bindgen_futures::spawn_local;
            let (tx, rx) = std::sync::mpsc::channel();
            self.backend_receiver = Some(rx);
            let window_clone = window.clone();
            spawn_local(async move {
                let backend = GfxBackend::new(window_clone)
                    .await
                    .expect("Failed to init graphics");
                let _ = tx.send(backend);
            });
        }
    }

    fn window_event(&mut self, event_loop: &ActiveEventLoop, _id: WindowId, event: WindowEvent) {
        match event {
            WindowEvent::CloseRequested => event_loop.exit(),
            WindowEvent::MouseInput { .. } | WindowEvent::Touch { .. } => {
                if !self.audio_started {
                    self.maybe_start_audio();
                }
            }
            WindowEvent::KeyboardInput {
                event:
                    KeyEvent {
                        state: ElementState::Pressed,
                        logical_key: key,
                        ..
                    },
                ..
            } => match key {
                Key::Named(NamedKey::Escape) => event_loop.exit(),
                Key::Character(c) => {
                    let new_scale = match c.as_str() {
                        "1" => Some(8.0),
                        "2" => Some(6.0),
                        "3" => Some(4.0),
                        "4" => Some(3.0),
                        "5" => Some(1.0),
                        "6" => Some(1.5),
                        "7" => Some(2.0),
                        "8" => Some(0.5),
                        "9" => Some(0.25),
                        _ => None,
                    };
                    if let Some(s) = new_scale {
                        self.render_scale = s;
                        self.update_fullscreen();
                        let (w, h) = self.get_render_size();
                        if let Some(backend) = &mut self.backend {
                            backend.resize(w, h);
                            self.engine.resize(&backend.device, w, h);
                        }
                    }
                }
                _ => (),
            },
            WindowEvent::RedrawRequested => {
                #[cfg(target_arch = "wasm32")]
                if self.backend.is_none() {
                    if let Some(rx) = &self.backend_receiver {
                        if let Ok(backend) = rx.try_recv() {
                            let (w, h) = self.get_render_size();
                            let handle = crate::gfx::GfxHandle {
                                device: &backend.device,
                                queue: &backend.queue,
                                format: backend.format,
                            };
                            self.engine = build_demo(
                                self.state.clone(),
                                self.engine.content.timeline.clone(),
                                backend.format,
                            );
                            self.engine.init(
                                &handle,
                                &backend.device.create_bind_group_layout(
                                    &wgpu::BindGroupLayoutDescriptor {
                                        label: Some("DummyLayout"),
                                        entries: &[],
                                    },
                                ),
                            );
                            self.backend = Some(backend);
                            if let Some(win) = &self.window {
                                win.request_redraw();
                            }
                        }
                    }
                }

                let (w, h) = self.get_render_size();
                if let Some(backend) = &self.backend {
                    let frame = match backend.surface.get_current_texture() {
                        Ok(f) => f,
                        Err(e) => {
                            error!("Surface error: {:?}", e);
                            return;
                        }
                    };
                    let view = frame
                        .texture
                        .create_view(&wgpu::TextureViewDescriptor::default());
                    let audio_t = f32::from_bits(self.state.audio_time.load(Ordering::Relaxed));
                    if audio_t > self.engine.content.timeline.duration() {
                        log::info!("Timeline finished, exiting...");
                        event_loop.exit();
                        return;
                    }

                    self.engine.render_to_view(
                        &backend.device,
                        &backend.queue,
                        &view,
                        w,
                        h,
                        audio_t,
                    );

                    frame.present();
                }
            }
            WindowEvent::Resized(_) => {
                let (w, h) = self.get_render_size();
                if w > 0
                    && h > 0
                    && let Some(backend) = &mut self.backend
                {
                    backend.resize(w, h);
                    self.engine.resize(&backend.device, w, h);
                }
            }
            _ => (),
        }
    }

    fn about_to_wait(&mut self, _event_loop: &ActiveEventLoop) {
        if let Some(win) = &self.window {
            win.request_redraw();
        }
    }
}
