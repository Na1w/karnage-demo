
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

struct OscData { 
    samples: array<vec4<f32>, 128>,
    y_pos: f32,
    height: f32,
    waveform_ptr: u32,
    _pad_inner: f32,
    color: vec4<f32>,
}

struct VertexOutput {
    @builtin(position) pos: vec4<f32>,
    @location(0) uv: vec2<f32>,
}


@group(0) @binding(0) var<uniform> globals: Globals;
@group(1) @binding(0) var<uniform> data: OscData;
@group(1) @binding(1) var t_diffuse: texture_2d<f32>;
@group(1) @binding(2) var s_diffuse: sampler;


fn sd_line(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
    let pa = p - a;
    let ba = b - a;
    let h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
    return length(pa - ba * h);
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

    let full_width = res.x / res.y;
    let x_rel = in.uv.x; 
    let sample_count = 511.0;
    let gain = 3.5; 

    var dist = 1.0;
    for (var off = -1; off <= 1; off++) {
        let i_base = i32(floor(x_rel * sample_count)) + off;
        if (i_base < 0 || i_base >= 511) {
            continue;
        }

        let i = (u32(i_base) + data.waveform_ptr) % 512u;
        let next_i = (u32(i_base + 1) + data.waveform_ptr) % 512u;

        let v0 = data.samples[i / 4u][i % 4u] * gain;
        let v1 = data.samples[next_i / 4u][next_i % 4u] * gain;

        let p1 = vec2<f32>((f32(i_base) / sample_count - 0.5) * full_width, data.y_pos + v0 * data.height);
        let p2 = vec2<f32>((f32(i_base + 1) / sample_count - 0.5) * full_width, data.y_pos + v1 * data.height);
        dist = min(dist, sd_line(p, p1, p2));
    }

    let beam = smoothstep(0.002, 0.0, dist); 
    let glow = exp(-dist * 120.0) * 0.6;     
    let bloom = exp(-dist * 20.0) * 0.15;    

    let osc_col = data.color.rgb * (beam + glow + bloom);
    col += osc_col;

    return vec4<f32>(col, 1.0);
}
