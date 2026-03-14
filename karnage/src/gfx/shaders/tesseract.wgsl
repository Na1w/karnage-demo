
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
@group(1) @binding(1) var t_diffuse: texture_2d<f32>;
@group(1) @binding(2) var s_diffuse: sampler;


fn rot4_xy(v: vec4<f32>, a: f32) -> vec4<f32> {
    let s = sin(a);
    let c = cos(a);
    return vec4<f32>(v.x*c - v.y*s, v.x*s + v.y*c, v.z, v.w);
}

fn rot4_zw(v: vec4<f32>, a: f32) -> vec4<f32> {
    let s = sin(a);
    let c = cos(a);
    return vec4<f32>(v.x, v.y, v.z*c - v.w*s, v.z*s + v.w*c);
}

fn rot4_xw(v: vec4<f32>, a: f32) -> vec4<f32> {
    let s = sin(a);
    let c = cos(a);
    return vec4<f32>(v.x*c - v.w*s, v.y, v.z, v.x*s + v.w*c);
}

fn rot4_yw(v: vec4<f32>, a: f32) -> vec4<f32> {
    let s = sin(a);
    let c = cos(a);
    return vec4<f32>(v.x, v.y*c - v.w*s, v.z, v.y*s + v.w*c);
}

fn rot4_yz(v: vec4<f32>, a: f32) -> vec4<f32> {
    let s = sin(a);
    let c = cos(a);
    return vec4<f32>(v.x, v.y*c - v.z*s, v.y*s + v.z*c, v.w);
}

fn line_dist(p: vec2<f32>, a: vec2<f32>, b: vec2<f32>) -> f32 {
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
    let kick = globals.kick;
    let res = vec2<f32>(globals.res_x, globals.res_y);
    let aspect = res.x / res.y;
    let p_uv = (in.uv - 0.5) * vec2<f32>(aspect, 1.0);
    
    let origin = vec2<f32>(0.0, -0.15);
    let uv_offset = p_uv - origin;
    
    var col = textureSampleLevel(t_diffuse, s_diffuse, in.uv, 0.0).rgb;
    let rt = globals.p3; 
    
    var p2d: array<vec2<f32>, 16>;
    var w_val: array<f32, 16>;
    
    for (var i = 0u; i < 16u; i++) {
        var v = vec4<f32>(
            f32(i & 1u) * 2.0 - 1.0,
            f32((i >> 1u) & 1u) * 2.0 - 1.0,
            f32((i >> 2u) & 1u) * 2.0 - 1.0,
            f32((i >> 3u) & 1u) * 2.0 - 1.0
        ) * 0.35;
        
        v = rot4_xy(v, rt * 0.8);
        v = rot4_zw(v, rt * 1.2);
        v = rot4_xw(v, rt * 0.5);
        v = rot4_yw(v, rt * 0.3);
        v = rot4_yz(v, rt * 1.5);
        
        let proj4 = 1.0 / (2.5 - v.w);
        let p3d = v.xyz * proj4;
        let proj3 = 1.0 / (4.0 - p3d.z);
        p2d[i] = p3d.xy * proj3 * 3.5;
        w_val[i] = v.w;
    }
    
    var edge_col_sum = vec3<f32>(0.0);
    var node_sum = 0.0;
    
    for (var i = 0u; i < 16u; i++) {
        let d_node = length(uv_offset - p2d[i]);
        node_sum += exp(-d_node * 60.0);
        
        for (var j = i + 1u; j < 16u; j++) {
            let diff = i ^ j;
            if (diff == 1u || diff == 2u || diff == 4u || diff == 8u) {
                let d = line_dist(uv_offset, p2d[i], p2d[j]);
                
                let wire = smoothstep(0.002 + kick * 0.004, 0.0, d);
                let glow = exp(-d * 35.0) * 0.2;
                
                let avg_w = (w_val[i] + w_val[j]) * 0.5;
                let edge_col = mix(vec3<f32>(0.5, 0.0, 1.0), vec3<f32>(0.0, 1.0, 1.0), avg_w * 0.5 + 0.5);
                
                edge_col_sum += edge_col * (wire + glow * (1.0 + kick * 1.5));
            }
        }
    }
    
    let nodes = node_sum * vec3<f32>(1.0, 0.9, 0.7) * (0.3 + kick * 0.7);
    col += (edge_col_sum * 0.5 + nodes * 0.6);
    
    return vec4<f32>(col, 1.0);
}
