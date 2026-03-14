
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
    @builtin(position) position: vec4<f32>,
    @location(0) uv: vec2<f32>,
}


@group(0) @binding(0) var<uniform> globals: Globals;


fn hash21(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(12.9898, 78.233))) * 43758.5453);
}

fn rot(a: f32) -> mat2x2<f32> {
    let s = sin(a);
    let c = cos(a);
    return mat2x2<f32>(c, -s, s, c);
}

fn smax(a: f32, b: f32, k: f32) -> f32 {
    let h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(a, b, h) + k * h * (1.0 - h);
}

fn sd_box(p: vec3<f32>, b: vec3<f32>) -> f32 {
    let q = abs(p) - b;
    return length(max(q, vec3<f32>(0.0))) + min(max(q.x, max(q.y, q.z)), 0.0);
}

const GROUND_Y: f32 = -25.0;
const CELL_SIZE: f32 = 2.5;

fn map_rings(p_in: vec3<f32>, t: f32) -> f32 {
    var d_rings = 1000.0;
    for (var i = 0; i < 4; i++) {
        let fi = f32(i);
        var rp = p_in;
        let r_xz = rot(t * (2.0 + fi * 2.0) + fi) * rp.xz;
        rp.x = r_xz.x; rp.z = r_xz.y;
        let r_xy = rot(t * (1.0 + fi * 0.5)) * rp.xy;
        rp.x = r_xy.x; rp.y = r_xy.y;
        let q = vec2<f32>(length(rp.xz) - (8.0 + fi * 3.0), rp.y);
        d_rings = min(d_rings, length(q) - 0.6);
    }
    return d_rings;
}

fn get_hole_strength(p: vec3<f32>, t: f32) -> f32 {
    var rp = p;
    let t_rot = t * 1.5;
    let r1 = rot(t_rot);
    let xz1 = r1 * vec2<f32>(rp.x, rp.z);
    rp.x = xz1.x; rp.z = xz1.y;
    let t_rot2 = t * 0.9;
    let r2 = rot(t_rot2);
    let yz2 = r2 * vec2<f32>(rp.y, rp.z);
    rp.y = yz2.x; rp.z = yz2.y;
    let val = sin(rp.x * 1.5) * sin(rp.y * 1.5) * sin(rp.z * 1.5);
    return smoothstep(0.1, 0.25, val);
}

fn map(p_in: vec3<f32>) -> vec3<f32> {
    let core_pulse = globals.kick * 0.2 + sin(globals.time * 2.0) * 0.1;
    let d_inner = length(p_in) - (4.0 + core_pulse);
    
    let core_radius = 6.0;
    var d_shell = abs(length(p_in) - core_radius) - 0.1;
    
    var rp = p_in;
    let t_rot = globals.time * 1.5;
    let r1 = rot(t_rot);
    let xz1 = r1 * vec2<f32>(rp.x, rp.z);
    rp.x = xz1.x; rp.z = xz1.y;
    let t_rot2 = globals.time * 0.9;
    let r2 = rot(t_rot2);
    let yz2 = r2 * vec2<f32>(rp.y, rp.z);
    rp.y = yz2.x; rp.z = yz2.y;
    
    let hole_val = sin(rp.x * 1.5) * sin(rp.y * 1.5) * sin(rp.z * 1.5);
    d_shell = smax(d_shell, hole_val - 0.15, 0.1); 
    
    let d_rings = map_rings(p_in, globals.time);
    
    var p_city = p_in;
    let city_rot_angle = globals.time * 0.15;
    let rot_m = rot(city_rot_angle);
    let rot_xz = rot_m * p_city.xz;
    p_city.x = rot_xz.x; p_city.z = rot_xz.y;
    
    let g_id = floor(p_city.xz / CELL_SIZE + 0.5);
    var d_city = 1000.0;
    var b_id = 0.0;
    
    let dist_to_center = length(p_in.xz);
    if dist_to_center < 350.0 {
        for (var x = -1; x <= 1; x++) {
            for (var z = -1; z <= 1; z++) {
                let offset = vec2<f32>(f32(x), f32(z));
                let cur_id = g_id + offset;
                let h = hash21(cur_id);
                let b_pos_xz = cur_id * CELL_SIZE;
                let wave = sin(b_pos_xz.x * 0.1 + globals.time * 0.8) * cos(b_pos_xz.y * 0.1 + globals.time * 0.8);
                let base_height = 4.0 + h * 8.0;
                let kick_factor = base_height * 0.8;
                let height = base_height + wave * 10.0 + globals.kick * kick_factor * h;
                let d_b = sd_box(p_city - vec3<f32>(b_pos_xz.x, GROUND_Y + height, b_pos_xz.y), vec3<f32>(0.8, height, 0.8)) - 0.02;
                if d_b < d_city {
                    d_city = d_b;
                    b_id = h;
                }
            }
        }
    }
    
    d_city = min(d_city, p_city.y - GROUND_Y);
    let sanctuary_hole = length(p_in.xz) - 25.0;
    d_city = smax(d_city, -sanctuary_hole, 3.0);
    
    var res = vec3<f32>(d_inner, 1.0, 0.0);
    if d_shell < res.x {
        res = vec3<f32>(d_shell, 4.0, 0.0);
    }
    if d_rings < res.x {
        res = vec3<f32>(d_rings, 2.0, 0.0);
    }
    if d_city < res.x {
        res = vec3<f32>(d_city, 3.0, b_id);
    }
    
    return res;
}

fn get_normal(p: vec3<f32>, t: f32) -> vec3<f32> {
    let e = vec2<f32>(0.001 + t * 0.0005, 0.0);
    return normalize(vec3<f32>(
        map(p + e.xyy).x - map(p - e.xyy).x,
        map(p + e.yxy).x - map(p - e.yxy).x,
        map(p + e.yyx).x - map(p - e.yyx).x
    ));
}


@vertex
fn vs_main(@builtin(vertex_index) vertex_index: u32) -> VertexOutput {
    let x = f32(i32(vertex_index & 1u) << 2u) - 1.0;
    let y = f32(i32(vertex_index & 2u) << 1u) - 1.0;
    var out: VertexOutput;
    out.position = vec4<f32>(x, y, 0.0, 1.0);
    out.uv = vec2<f32>(x, y) * 0.5 + 0.5;
    return out;
}

@fragment
fn fs_main(in: VertexOutput) -> @location(0) vec4<f32> {
    let aspect = globals.res_x / globals.res_y;
    var uv = in.uv * 2.0 - 1.0;
    uv.x *= aspect;
    
    let cam_angle = globals.time * 0.03;
    let ro = vec3<f32>(cos(cam_angle) * 100.0, 65.0, sin(cam_angle) * 100.0);
    let ta = vec3<f32>(0.0, -20.0, 0.0);
    let ww = normalize(ta - ro);
    let uu = normalize(cross(ww, vec3<f32>(0.0, 1.0, 0.0)));
    let vv = normalize(cross(uu, ww));
    let rd = normalize(uv.x * uu + uv.y * vv + 3.5 * ww);
    
    var t_geo = 0.0;
    var res_geo = vec3<f32>(0.0);
    for (var i = 0; i < 240; i++) {
        res_geo = map(ro + rd * t_geo);
        if res_geo.x < (0.001 + t_geo * 0.001) {
            break;
        }
        t_geo += res_geo.x * 0.4;
        if t_geo > 500.0 {
            break;
        }
    }
    
    let sky_col = vec3<f32>(0.0);
    var col = sky_col;
    
    if t_geo < 500.0 {
        let p = ro + rd * t_geo;
        let n = get_normal(p, t_geo);
        let core_pos = vec3<f32>(0.0, 0.0, 0.0);
        let light_dir = normalize(core_pos - p);
        let dist_to_core = length(core_pos - p);
        let light_atten = 1.0 / (1.0 + dist_to_core * dist_to_core * 0.005);
        let diff = max(dot(n, light_dir), 0.0) * light_atten * 5.0;
        let view_dir = -rd;
        let half_vec = normalize(light_dir + view_dir);
        let spec = pow(max(dot(n, half_vec), 0.0), 128.0) * light_atten * 5.0;
        let fre = pow(clamp(1.0 - max(dot(n, view_dir), 0.0), 0.0, 1.0), 4.0);
        
        if res_geo.y == 1.0 {
            col = vec3<f32>(500.0, 450.0, 350.0) * (1.0 + globals.kick * 1.5);
        } else if res_geo.y == 4.0 {
            col = vec3<f32>(0.02, 0.02, 0.02) * diff + vec3<f32>(0.2, 0.4, 0.8) * fre;
        } else if res_geo.y == 2.0 {
            let metal_base = vec3<f32>(0.01, 0.015, 0.02);
            let core_reflection = vec3<f32>(1.0, 0.95, 0.8) * spec * 15.0;
            col = metal_base * diff + core_reflection + vec3<f32>(0.2, 0.5, 1.0) * fre * 2.0;
        } else {
            let city_rot_m = rot(globals.time * 0.15);
            let p_rot_xz = city_rot_m * p.xz;
            let g_id = floor(p_rot_xz / CELL_SIZE + 0.5);
            let h = hash21(g_id);
            let b_pos_xz = g_id * CELL_SIZE;
            let wave = sin(b_pos_xz.x * 0.1 + globals.time * 0.8) * cos(b_pos_xz.y * 0.1 + globals.time * 0.8);
            let base_height = 4.0 + h * 8.0;
            let kick_factor = base_height * 0.8;
            let max_height = base_height + wave * 10.0 + globals.kick * kick_factor * h;
            let local_y = p.y - GROUND_Y;
            let h_rel = clamp(local_y / max_height, 0.0, 1.0);
            let mat_base = vec3<f32>(0.01, 0.012, 0.015);
            let mat_top = mix(mat_base, vec3<f32>(0.05, 0.15, 0.3), clamp(max_height / 35.0, 0.0, 1.0));
            col = mix(mat_base, mat_top, pow(h_rel, 3.0));
            let local_p_xz = (fract(p_rot_xz / CELL_SIZE + 0.5) - 0.5) * CELL_SIZE;
            let edge_dist = max(abs(local_p_xz.x), abs(local_p_xz.y)) / (CELL_SIZE * 0.5);
            let edge_mask = step(0.95, edge_dist);
            col = mix(col, col + vec3<f32>(0.05, 0.1, 0.2), edge_mask * h_rel);
            let grid_y = step(0.98, fract(p.y * 0.25));
            col += vec3<f32>(0.02, 0.05, 0.1) * grid_y * h_rel;
            col *= (diff * 0.8 + 0.2);
        }
        col = mix(sky_col, col, exp(-t_geo * 0.015));
    }
    
    var god_rays = 0.0;
    let t_closest = dot(-ro, rd);
    let t_start = max(0.0, t_closest - 25.0);
    let t_end = t_closest + 25.0;
    let vol_steps = 50.0;
    let v_step = (t_end - t_start) / vol_steps;
    let dither = hash21(in.uv + globals.time) * 0.5;
    
    for (var i = 0.0; i < 50.0; i += 1.0) {
        let t_vol = t_start + (i + dither) * v_step;
        if (t_vol > t_geo) {
            break;
        }
        let p_vol = ro + rd * t_vol;
        let r_dist = length(p_vol);
        if (r_dist > 6.1) {
            let dir_from_core = p_vol / r_dist;
            let surface_p = dir_from_core * 6.0;
            let hole_strength = get_hole_strength(surface_p, globals.time);
            if (hole_strength > 0.0) {
                var scatter = 1.0 / (1.0 + r_dist * r_dist * 0.05);
                var ring_occ = 1.0;
                for (var j = 0; j < 4; j++) {
                    let fj = f32(j);
                    let ring_radius = 8.0 + fj * 3.0;
                    if (r_dist > ring_radius) {
                        let intersect_p = dir_from_core * ring_radius;
                        let d_to_ring = map_rings(intersect_p, globals.time);
                        if (d_to_ring < 0.6) {
                            ring_occ = 0.0;
                            break;
                        }
                    }
                }
                god_rays += scatter * ring_occ * hole_strength;
            }
        }
    }
    god_rays = god_rays * v_step * 0.4;
    col += vec3<f32>(0.3, 0.7, 1.0) * god_rays * (1.5 + globals.kick * 2.0);
    
    return vec4<f32>(col, 1.0);
}
