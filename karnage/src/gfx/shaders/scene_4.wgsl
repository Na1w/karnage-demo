
struct Globals {
    time: f32,
    kick: f32,
    sweep: f32,
    res_x: f32,
    res_y: f32,
    fade: f32,
    p2: f32,
    p3: f32
}

struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>
}


@group(0) @binding(0) var<uniform> globals: Globals;
@group(1) @binding(1) var t_diffuse: texture_2d<f32>;
@group(1) @binding(2) var s_diffuse: sampler;


fn hash(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
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
    let p_uv = (in.uv - 0.5) * vec2<f32>(res.x / res.y, 1.0);
    let horizon_base = 0.05;
    
    var col = mix(vec3<f32>(0.0, 0.0, 0.0), vec3<f32>(0.02, 0.0, 0.05), smoothstep(0.5, -0.5, p_uv.y));
    
    let sun_color = vec3<f32>(0.0, 0.8, 1.0); 

    let wave1 = sin(p_uv.x * 4.0 + t * 2.0) * 0.025;
    let wave2 = sin(p_uv.x * 9.0 - t * 3.5) * 0.01;
    let wave_y = (wave1 + wave2) * (1.0 + globals.kick * 2.5);
    let horizon_wavy = horizon_base + wave_y;
    
    let depth_factor = max(0.001, p_uv.y - horizon_wavy);
    let py = 1.0 / depth_factor;
    let px = p_uv.x * py;
    let grid_uv = vec2<f32>(px * 1.5, py * 2.5 + t * 12.0);
    
    let fw_x = fwidth(grid_uv.x);
    let fw_y = fwidth(grid_uv.y);
    
    if (p_uv.y > horizon_wavy) {
        let gx = abs(fract(grid_uv.x + 0.5) - 0.5) / (fw_x + 0.001);
        let gy = abs(fract(grid_uv.y + 0.5) - 0.5) / (fw_y + 0.001);
        let grid_lines = smoothstep(0.6, 0.0, min(gx, gy));
        
        let cyan = vec3<f32>(0.0, 0.4, 0.6); 
        let distance_fade = exp(-py * 0.07) * smoothstep(0.0, 0.04, depth_factor);
        
        let specular = pow(max(0.0, 1.0 - abs(p_uv.x * 2.5)), 8.0) * sun_color * 0.4 * distance_fade;
        let reflection = exp(-abs(p_uv.x) * 3.0) * sun_color * 0.2 * distance_fade;
        col += reflection + specular;
        
        let crest_light = smoothstep(0.01, 0.04, wave_y) * cyan * 0.5;
        col += grid_lines * (cyan + crest_light) * distance_fade * (0.7 + globals.kick * 0.5);
        col += cyan * 0.05 * distance_fade * (sin(py * 0.3 - t * 5.0) * 0.5 + 0.5);
    }

    let mist = exp(-abs(p_uv.y - horizon_base) * 20.0) * vec3<f32>(0.3, 0.5, 0.8) * 0.3;
    col += mist;

    return vec4<f32>(col, 1.0);
}
