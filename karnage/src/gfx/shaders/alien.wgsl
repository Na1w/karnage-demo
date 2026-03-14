
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


fn rotate(p: vec2<f32>, a: f32) -> vec2<f32> {
    let s = sin(a);
    let c = cos(a);
    return vec2<f32>(p.x * c - p.y * s, p.x * s + p.y * c);
}

fn gyroid(p: vec3<f32>, scale: f32) -> f32 {
    let s_p = p * scale;
    return (abs(dot(sin(s_p), cos(s_p.zxy))) - 0.1) / scale;
}

fn map(p: vec3<f32>) -> f32 {
    let d1 = gyroid(p, 0.6);
    let d2 = gyroid(p, 2.5);
    return max(d1, -d2 * 0.5) * 0.8;
}

fn get_normal(p: vec3<f32>) -> vec3<f32> {
    let e = vec2<f32>(0.01, 0.0);
    return normalize(vec3<f32>(
        map(p + e.xyy) - map(p - e.xyy),
        map(p + e.yxy) - map(p - e.yxy),
        map(p + e.yyx) - map(p - e.yyx)
    ));
}

fn get_safe_path(z: f32) -> vec3<f32> {
    return vec3<f32>(sin(z * 0.4) * 1.5, cos(z * 0.3) * 1.5, z);
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
    let uv = (in.uv - 0.5) * vec2<f32>(globals.res_x / globals.res_y, 1.0);
    
    let ro_z = t * 3.0;
    let ro = get_safe_path(ro_z);
    
    let look_at = get_safe_path(ro_z + 2.0);
    let forward = normalize(look_at - ro);
    let right = normalize(cross(vec3<f32>(0.0, 1.0, 0.0), forward));
    let up = normalize(cross(forward, right));
    
    var rd = normalize(forward + right * uv.x + up * uv.y);
    
    var d = 0.01;
    var hit = false;
    var glow = 0.0;
    
    for(var i=0; i<100; i++) {
        let p = ro + rd * d;
        let dist = map(p);
        
        glow += exp(-dist * 5.0) * 0.02;
        
        if (dist < 0.02) {
            hit = true;
            break;
        }
        d += dist;
        if (d > 40.0) {
            break;
        }
    }
    
    var col = vec3<f32>(0.005, 0.0, 0.015);
    
    let base_color = vec3<f32>(0.9, 0.3, 0.6); 
    let sec_color = vec3<f32>(0.2, 0.8, 1.0);  
    
    col += mix(base_color, sec_color, sin(t * 0.2) * 0.5 + 0.5) * glow * (1.0 + globals.kick * 2.0);
    
    if (hit) {
        let p = ro + rd * d;
        let n = get_normal(p);
        let ld = normalize(look_at - p);
        
        let diff = max(0.0, dot(n, ld));
        let fresnel = pow(1.0 - max(0.0, dot(n, -rd)), 4.0);
        
        col += base_color * diff * 0.4;
        col += sec_color * fresnel * 0.8;
        col += vec3<f32>(1.0) * pow(fresnel, 8.0) * 2.0;
    }
    
    col = mix(col, vec3<f32>(0.005, 0.0, 0.015), smoothstep(15.0, 40.0, d));
    
    return vec4<f32>(col, 1.0);
}
