
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

struct TwistscrollerData { 
    num_chars: i32,
    y_pos: f32,
    height: f32,
    speed: f32,
    twistscroller_amount: f32,
    start_time: f32,
    _pad: vec2<f32>,
}

struct TwistscrollerStatic {
    char_ids: array<vec4<i32>, 256>,
    font_chars: array<vec4<u32>, 16>,
}

struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
}


@group(0) @binding(0) var<uniform> globals: Globals;
@group(1) @binding(0) var<uniform> data: TwistscrollerData;
@group(1) @binding(1) var t_diffuse: texture_2d<f32>;
@group(1) @binding(2) var s_diffuse: sampler;
@group(1) @binding(4) var<uniform> static_data: TwistscrollerStatic;


fn get_char(c: i32, p: vec2<i32>) -> f32 {
    if (p.x < 0 || p.x > 7 || p.y < 0 || p.y > 7 || c < 0 || c > 31) {
        return 0.0;
    }
    let bit_idx = u32(p.x + p.y * 8);
    let u32_idx = u32(c) * 2u + (bit_idx / 32u);
    let local_bit = bit_idx % 32u;
    let v = static_data.font_chars[u32_idx / 4u];
    var val = 0u;
    let comp = u32_idx % 4u;
    if (comp == 0u) {
        val = v.x;
    } else if (comp == 1u) {
        val = v.y;
    } else if (comp == 2u) {
        val = v.z;
    } else {
        val = v.w;
    }
    return f32((val >> local_bit) & 1u);
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
    let res = vec2<f32>(globals.res_x, globals.res_y);
    var col = textureSampleLevel(t_diffuse, s_diffuse, in.uv, 0.0).rgb;
    
    let p = (in.uv - 0.5) * vec2<f32>(res.x / res.y, 1.0);
    let rel_t = t - data.start_time;
    
    if (rel_t < 0.0) {
        return vec4<f32>(col, 1.0);
    }

    let wave_fast = sin(p.x * 4.0 + t * 3.0) * 0.1;
    let wave_slow = sin(p.x * 1.5 + t * 0.8) * 0.2;
    let py = p.y - (data.y_pos + wave_fast + wave_slow);
    
    let angle = p.x * 2.5 + t * 2.5;
    let cos_t = cos(angle);
    let h = data.height;
    let projected_h = h * abs(cos_t);
    
    let scroll_x = (p.x - 1.0) * 60.0 + rel_t * data.speed * 80.0;
    let idx = i32(floor(scroll_x / 9.0));
    let is_active = (idx >= 0 && idx < data.num_chars);

    if (is_active && abs(py) < projected_h) {
        var ty = 0.0;
        var brightness = 0.0;
        
        if (cos_t > 0.0) {
            ty = (py / abs(cos_t)) / h * 4.0 + 4.0;
            brightness = cos_t;
        } else {
            ty = 8.0 - ((py / abs(cos_t)) / h * 4.0 + 4.0);
            brightness = abs(cos_t) * 0.35;
        }
        
        let ty_idx = i32(floor(ty));
        if (ty_idx >= 0 && ty_idx <= 8) {
            let char_id = static_data.char_ids[idx / 4][idx % 4];
            let local_p = vec2<i32>(i32(floor(scroll_x % 9.0)), ty_idx);
            let text_bit = get_char(char_id, local_p);
            
            var bar_col = mix(vec3<f32>(0.01, 0.05, 0.2), vec3<f32>(0.2, 0.5, 1.0), brightness);
            bar_col += vec3<f32>(0.8, 0.9, 1.0) * text_bit * brightness;
            let spec = pow(max(0.0, 1.0 - abs(py / projected_h)), 4.0) * brightness;
            bar_col += vec3<f32>(1.0) * spec * 0.4;
            col = bar_col;
        }
    } else if (is_active) {
        let glow = smoothstep(h * 1.5, projected_h, abs(py)) * abs(cos_t);
        col += vec3<f32>(0.1, 0.2, 0.4) * glow * 0.2;
    }
    
    return vec4<f32>(col, 1.0);
}
