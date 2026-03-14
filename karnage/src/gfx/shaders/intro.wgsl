
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


fn hash33(p: vec3<f32>) -> vec3<f32> {
    var p3 = fract(p * vec3<f32>(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
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
    
    var col = textureSampleLevel(t_diffuse, s_diffuse, in.uv, 0.0).rgb;
    
    let forward_speed = t * 40.0;
    let ro = vec3<f32>(0.0, 0.0, forward_speed);
    var rd = normalize(vec3<f32>(p_uv, 1.2));
    let cam_rot = mat3x3<f32>(vec3<f32>(cos(t*0.2), sin(t*0.2), 0.0), vec3<f32>(-sin(t*0.2), cos(t*0.2), 0.0), vec3<f32>(0.0, 0.0, 1.0));
    rd = cam_rot * rd;
    
    if (rd.z > 0.01) {
        for (var i = 1.0; i < 20.0; i += 1.0) {
            let z_dist = fract(i / 20.0 - t * 0.4); 
            let real_z = z_dist * 100.0; 
            let p = rd * (real_z / rd.z);
            let world_p = p + ro;
            let grid_p = floor(world_p * 0.6);
            let h = hash33(grid_p);
            if (h.x > 0.98) { 
                let local_p = fract(world_p * 0.6) - 0.5;
                let star_dist = length(local_p - (h - 0.5));
                var star_size = exp(-star_dist * (18.0 + h.z * 12.0)); 
                star_size *= smoothstep(0.35, 0.1, star_dist);
                let fade = smoothstep(1.0, 0.8, z_dist) * smoothstep(0.0, 0.1, z_dist);
                col += star_size * fade * vec3<f32>(0.9, 0.95, 1.0) * (2.0 - z_dist);
            }
        }
    }
    return vec4<f32>(col, 1.0);
}
