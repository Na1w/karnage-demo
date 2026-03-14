
struct Globals {
    time: f32,
    kick: f32,
    sweep: f32,
    res_x: f32,
    res_y: f32,
    fade: f32,
    p2: f32,
    p3: f32,
}

struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
}


@group(0) @binding(0) var<uniform> globals: Globals;


fn hash(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

fn hash22(p: vec2<f32>) -> vec2<f32> {
    var p3 = fract(vec3<f32>(p.xyx) * vec3<f32>(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

fn rotate(p: vec2<f32>, a: f32) -> vec2<f32> {
    let s = sin(a);
    let c = cos(a);
    return vec2<f32>(p.x * c - p.y * s, p.x * s + p.y * c);
}

fn get_circuit(uv: vec2<f32>, t: f32, kick: f32, dist_atten: f32, is_top_layer: bool) -> vec3<f32> {
    if (dist_atten <= 0.05) {
        return vec3<f32>(0.0);
    }
    let scale = 12.0;
    let g_uv = uv * scale;
    let id = floor(g_uv);
    let f_uv = fract(g_uv) - 0.5;
    let h = hash22(id);
    var col = vec3<f32>(0.0);
    let is_bus = h.x > 0.75;
    var wire = 0.0;
    var packet = 0.0;
    let flow_speed = 1.2;
    let packet_freq = 1.5;
    let w_edge = 0.08 / max(0.1, dist_atten);
    if (is_bus) {
        let bus_f = fract(f_uv.x * 4.0) - 0.5;
        wire = smoothstep(w_edge * 2.0, 0.0, abs(bus_f));
        if (h.y > 0.7) {
            let flow_t = fract(uv.y * packet_freq - t * flow_speed + h.y);
            packet = wire * smoothstep(0.2, 0.0, flow_t);
        }
    } else {
        if (h.x > 0.4) {
            wire = smoothstep(w_edge, 0.0, abs(f_uv.x));
            if (h.y > 0.85) {
                let flow_t = fract(uv.y * packet_freq - t * flow_speed + h.y);
                packet = wire * smoothstep(0.15, 0.0, flow_t);
            }
        } else if (h.x > 0.2) {
            wire = smoothstep(w_edge, 0.0, abs(f_uv.x - f_uv.y));
        } else {
            wire = smoothstep(w_edge, 0.0, abs(f_uv.y));
            if (h.y > 0.85) {
                let flow_t = fract(uv.x * packet_freq - t * flow_speed + h.y);
                packet = wire * smoothstep(0.15, 0.0, flow_t);
            }
        }
    }
    let via = smoothstep(0.15, 0.0, length(f_uv)) * step(0.85, h.y);
    if (is_top_layer) {
        col += vec3<f32>(0.05, 0.15, 0.05) * wire;
        col += vec3<f32>(0.2, 0.4, 0.25) * via;
        col += vec3<f32>(0.4, 1.0, 0.2) * packet * (1.5 + kick * 5.0);
    } else {
        col += vec3<f32>(0.02, 0.08, 0.02) * wire * 0.6;
        col += vec3<f32>(0.1, 0.5, 0.1) * packet * (1.0 + kick * 2.0);
    }
    return col * dist_atten;
}


@vertex
fn vs_main(@builtin(vertex_index) idx: u32) -> VertexOutput {
    var out: VertexOutput;
    let x = f32((i32(idx) << 1u) & 2);
    let y = f32(i32(idx) & 2);
    out.pos = vec4<f32>(x * 2.0 - 1.0, 1.0 - y * 2.0, 0.0, 1.0);
    out.uv = vec2<f32>(x, y);
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let t = globals.time;
    let kick = globals.kick;
    let res = vec2<f32>(globals.res_x, globals.res_y);
    var p_uv = (in.uv - 0.5) * vec2<f32>(res.x / res.y, 1.0);
    
    let speed = 1.5;
    let z_current = t * speed;
    
    let horizon_y = p_uv.y + 0.45;
    if (horizon_y <= 0.0) {
        return vec4<f32>(0.001, 0.005, 0.002, 1.0);
    }
    
    let perspective = 1.0 / horizon_y;
    let z_world = z_current + perspective * 0.6;
    
    let path_at_cam = sin(z_current * 0.12) * 8.0 + cos(z_current * 0.05) * 4.0;
    let path_at_depth = sin(z_world * 0.12) * 8.0 + cos(z_world * 0.05) * 4.0;
    
    var uv = vec2<f32>(p_uv.x * perspective * 2.5 + (path_at_depth - path_at_cam), z_world);
    
    let dist_atten = smoothstep(18.0, 3.5, perspective);
    var col = vec3<f32>(0.002, 0.01, 0.004) * dist_atten;
    
    col += get_circuit(uv * 0.8 + 10.0, t, kick, dist_atten * 0.7, false);
    col += get_circuit(uv, t, kick, dist_atten, true);
    
    let chip_scale = 3.0;
    let chip_id = floor(uv * chip_scale);
    let h_chip = hash22(chip_id);
    
    if (h_chip.x > 0.82 && dist_atten > 0.15) {
        let height = 0.03 + h_chip.y * 0.25;
        let size_x = 0.2 + hash(chip_id + 1.0) * 0.25;
        let size_y = 0.2 + hash(chip_id + 2.0) * 0.25;
        let parallax_offset = vec2<f32>(p_uv.x, p_uv.y) * height * perspective;
        let uv_top = uv + parallax_offset;
        let f_uv_top = (fract(uv_top * chip_scale) - 0.5);
        let top_mask = step(abs(f_uv_top.x), size_x) * step(abs(f_uv_top.y), size_y);
        let f_uv_base = (fract(uv * chip_scale) - 0.5);
        
        if (top_mask > 0.5) {
            let shade = smoothstep(-0.5, 0.5, f_uv_top.x + f_uv_top.y);
            let base_chip_col = mix(vec3<f32>(0.005, 0.02, 0.01), vec3<f32>(0.02, 0.08, 0.04), h_chip.y);
            col = mix(col, base_chip_col + shade * 0.03, dist_atten);
            let pins = step(size_x * 1.8, sin(f_uv_top.x * 30.0)) * step(size_y * 0.85, abs(f_uv_top.y));
            col = mix(col, vec3<f32>(0.2, 0.3, 0.2), pins * dist_atten);
            
            let pulse = step(0.98, hash(chip_id + floor(t * 2.0)));
            col += vec3<f32>(0.4, 1.0, 0.2) * pulse * (1.0 + kick * 2.0) * dist_atten;
        } else if (max(abs(f_uv_base.x), abs(f_uv_base.y)) < 0.45) {
             col = mix(col, vec3<f32>(0.002, 0.01, 0.005), 0.5 * dist_atten);
        }
    }
    
    let fog = smoothstep(0.0, 0.5, horizon_y);
    col = mix(vec3<f32>(0.001, 0.005, 0.002), col, fog);
    let vignette = 1.0 - length(in.uv - 0.5) * 0.7;
    col *= vignette;
    col += hash(in.uv + t) * 0.008 * fog;
    return vec4<f32>(col, 1.0);
}
