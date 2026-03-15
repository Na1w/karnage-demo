
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


fn hash(p: vec2<f32>) -> f32 {
    return fract(sin(dot(p, vec2<f32>(127.1, 311.7))) * 43758.5453);
}

fn tunnel_path(z: f32) -> vec2<f32> {
    return vec2<f32>(sin(z * 0.04) * 5.0 + cos(z * 0.015) * 3.0, cos(z * 0.035) * 4.0);
}

fn rotate(p: vec2<f32>, a: f32) -> vec2<f32> {
    let s = sin(a);
    let c = cos(a);
    return vec2<f32>(p.x * c - p.y * s, p.x * s + p.y * c);
}

fn sd_hexagon(p: vec2<f32>, r: f32) -> f32 {
    let k = vec3<f32>(-0.866025404, 0.5, 0.577350269);
    var p_mut = abs(p);
    p_mut -= 2.0 * min(dot(k.xy, p_mut), 0.0) * k.xy;
    p_mut -= vec2<f32>(clamp(p_mut.x, -k.z * r, k.z * r), r);
    return length(p_mut) * sign(p_mut.y);
}

fn rotate3d(p: vec3<f32>, axis: vec3<f32>, angle: f32) -> vec3<f32> {
    let s = sin(angle);
    let c = cos(angle);
    let oc = 1.0 - c;
    let m = mat3x3<f32>(
        oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,
        oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,
        oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c
    );
    return m * p;
}

fn sd_spiky(p: vec3<f32>, morph: f32) -> f32 {
    let s = 0.7;
    let p_scaled = p / s;
    let d_sphere = length(p_scaled) - 1.0;
    
    let freq = 5.0;
    let sp_base = sin(p_scaled.x * freq) * sin(p_scaled.y * freq) * sin(p_scaled.z * freq);
    let sp = sp_base * 0.5 + 0.5; 
    
    let d_oct = (abs(p_scaled.x) + abs(p_scaled.y) + abs(p_scaled.z)) - 1.2;
    let d_cube = max(abs(p_scaled.x), max(abs(p_scaled.y), abs(p_scaled.z))) - 0.8;
    
    let d_spiky_geom = mix(d_oct, d_cube, 0.3) - sp * 0.4;
    let res = mix(d_sphere, d_spiky_geom, morph);
    
    return res * s * 0.5;
}

fn map(p: vec3<f32>) -> f32 {
    let t = globals.time;
    let path = tunnel_path(p.z);
    var q = p.xy - path;
    
    let twist = p.z * 0.05 + t * 0.2;
    q = rotate(q, twist);
    
    let angle = atan2(q.y, q.x);
    let dt = max(0.0, t - 12.0);
    let ripple_m = smoothstep(0.0, 25.0, dt) * (0.7 + 0.3 * sin(t * 0.2));
    let breathing = sin(p.z * 0.1 + t * 0.6) * 1.5 + cos(p.z * 0.05 - t * 0.3) * 1.0;
    
    let ribs = sin(p.z * 2.5 + angle * 3.0) * 0.35 * ripple_m * (1.0 + globals.sweep * 0.5);
    let muscle = sin(angle * 6.0 - p.z * 0.4) * 0.25 * ripple_m * (1.0 + globals.sweep * 0.8);
    
    let spike_pos = sin(angle * 4.0 + p.z * 0.2 + t * 0.5);
    let time_growth = smoothstep(0.0, 60.0, dt) * 1.2; 
    let spikes = pow(max(0.0, spike_pos), 8.0) * (1.5 + time_growth + 0.8 * sin(t * 1.2)) * ripple_m;
    
    let base_r = 5.5 + breathing;
    let final_r = base_r + ribs + muscle - spikes;
    
    let d_circle = length(q) - final_r;
    let d_hex = sd_hexagon(q, final_r * 0.9);
    
    let tunnel_d = -mix(d_circle, d_hex, 0.5) * 0.4;

    let dt_rot = dt * 0.07;
    let speed_boost = smoothstep(37.0, 45.0, dt) * (dt - 37.0) * 28.0;
    let ro_z = dt * 28.0 + speed_boost;
    let turn_blast = smoothstep(2.6, 2.7, dt_rot);
    let creep = mix(-120.0, -30.0, clamp((dt_rot - 1.4) / 1.0, 0.0, 1.0));
    let obj_lead = mix(creep, 45.0, turn_blast) + sin(t * 0.4) * 6.0;
    let obj_z = ro_z + obj_lead;
    let obj_off = vec2<f32>(sin(t * 1.5) * 1.5, cos(t * 1.1) * 1.2);
    let obj_pos = vec3<f32>(tunnel_path(obj_z) + obj_off, obj_z);
    var p_obj = p - obj_pos;
    
    p_obj = rotate3d(p_obj, normalize(vec3<f32>(1.0, 0.8, 0.6)), t * 2.0);
    p_obj = rotate3d(p_obj, normalize(vec3<f32>(0.2, 1.0, 0.3)), t * 1.3);
    
    let spiky_morph = (sin(t * 1.2) * 0.5 + 0.5) * smoothstep(14.0, 18.0, t);
    let spiky_d = sd_spiky(p_obj, spiky_morph);
    
    return min(tunnel_d, spiky_d);
}

fn get_normal(p: vec3<f32>) -> vec3<f32> {
    let e = vec2<f32>(0.005, 0.0);
    return normalize(vec3<f32>(
        map(p + e.xyy) - map(p - e.xyy), 
        map(p + e.yxy) - map(p - e.yxy), 
        map(p + e.yyx) - map(p - e.yyx)
    ));
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
    var bg_col = textureSampleLevel(t_diffuse, s_diffuse, in.uv, 0.0).rgb;

    if (t < 8.0) {
        return vec4<f32>(bg_col, 1.0);
    }

    let p_uv = (in.uv - 0.5) * vec2<f32>(res.x / res.y, 1.0);
    let dt = t - 12.0;
    let speed_boost = smoothstep(37.0, 45.0, dt) * (dt - 37.0) * 28.0;
    let ro_z_cam = dt * 28.0 + speed_boost;
    let ro = vec3<f32>(tunnel_path(ro_z_cam), ro_z_cam);
    let look_at = vec3<f32>(tunnel_path(ro_z_cam + 10.0), ro_z_cam + 10.0);
    let forward = normalize(look_at - ro);
    let right = normalize(cross(vec3<f32>(0.0, 1.0, 0.0), forward));
    let up = normalize(cross(forward, right));
    
    let dt_rot = dt * 0.07;
    let rot_stop = min(dt_rot, 2.6); 
    let current_yaw = (smoothstep(0.4, 0.6, fract(rot_stop)) + floor(rot_stop) + 1.0) * 3.14159265;
    let roll = sin(dt * 0.2) * 0.7 + (sin(dt * 0.6) * 2.0 * smoothstep(0.6, 1.0, sin(dt * 0.08 * 3.1415))); 
    var rd = normalize(right * p_uv.x + up * p_uv.y + forward * 1.3);
    let c_y = cos(current_yaw);
    let s_y = sin(current_yaw);
    rd = rd * c_y + cross(up, rd) * s_y + up * dot(up, rd) * (1.0 - c_y);
    let c_r = cos(roll);
    let s_r = sin(roll);
    rd = rd * c_r + cross(forward, rd) * s_r + forward * dot(forward, rd) * (1.0 - c_r);

    let cam_forward = normalize(forward * c_y + cross(up, forward) * s_y + up * dot(up, forward) * (1.0 - c_y));
    let cam_right_base = normalize(right * c_y + cross(up, right) * s_y + up * dot(up, right) * (1.0 - c_y));
    let cam_right = normalize(cam_right_base * c_r + cross(cam_forward, cam_right_base) * s_r + cam_forward * dot(cam_forward, cam_right_base) * (1.0 - c_r));

    var d = 0.1;
    var hit = false;
    for (var i = 0; i < 192; i++) {
        let dist = map(ro + rd * d);
        if (dist < (0.0005 + d * 0.0001)) {
            hit = true;
            break;
        }
        d += dist; 
        if (d > 100.0) {
            break;
        }
    }
    
    var col = bg_col;
    if (hit) {
        let p = ro + rd * d;
        let n = get_normal(p);
        let ld = normalize(ro - p);
        
        let turn_blast = smoothstep(2.6, 2.7, dt_rot);
        let creep = mix(-120.0, -30.0, clamp((dt_rot - 1.4) / 1.0, 0.0, 1.0));
        let obj_lead = mix(creep, 45.0, turn_blast) + sin(t * 0.4) * 6.0;
        let obj_z = ro_z_cam + obj_lead;
        let obj_off = vec2<f32>(sin(t * 1.5) * 1.5, cos(t * 1.1) * 1.2);
        let obj_pos = vec3<f32>(tunnel_path(obj_z) + obj_off, obj_z);
        
        var p_obj_hit = p - obj_pos;
        p_obj_hit = rotate3d(p_obj_hit, normalize(vec3<f32>(1.0, 0.8, 0.6)), t * 2.0);
        p_obj_hit = rotate3d(p_obj_hit, normalize(vec3<f32>(0.2, 1.0, 0.3)), t * 1.3);
        let spiky_morph = (sin(t * 1.2) * 0.5 + 0.5) * smoothstep(14.0, 18.0, t);
        let d_spiky_hit = sd_spiky(p_obj_hit, spiky_morph);
        
        let hit_spiky = d_spiky_hit < 0.05;

        let spiky_color = vec3<f32>(0.1, 0.8, 0.2); 

        let l_dir_l = normalize(cam_forward - cam_right * 0.12);
        let l_dir_r = normalize(cam_forward + cam_right * 0.12);
        let searchlight = (pow(max(0.0, dot(rd, l_dir_l)), 160.0) + pow(max(0.0, dot(rd, l_dir_r)), 160.0)) * 2.0;
        let flicker = (hash(vec2<f32>(t * 20.0, 0.0)) * 0.1 + 0.95) * (1.0 - globals.kick * 0.15);
        let atten = exp(-d * 0.12);
        let diff = max(0.0, dot(n, ld));
        let spec = pow(max(0.0, dot(rd, reflect(-ld, n))), 64.0);
        
        let color_cycle = t * 0.1;
        let p_fract = smoothstep(0.0, 1.0, fract(color_cycle));
        let p_idx = floor(color_cycle % 4.0);
        let p0_glow = vec3<f32>(1.0, 0.35, 0.0);
        let p0_light = vec3<f32>(0.9, 0.95, 1.0);
        let p1_glow = vec3<f32>(0.4, 1.0, 0.1);
        let p1_light = vec3<f32>(1.0, 1.0, 0.8);
        let p2_glow = vec3<f32>(1.0, 0.1, 0.05);
        let p2_light = vec3<f32>(1.0, 0.9, 0.9);
        let p3_glow = vec3<f32>(0.0, 0.8, 1.0);
        let p3_light = vec3<f32>(0.95, 1.0, 1.0);
        var cur_glow: vec3<f32>;
        var cur_light: vec3<f32>;
        if (p_idx < 1.0) {
            cur_glow = mix(p0_glow, p1_glow, p_fract);
            cur_light = mix(p0_light, p1_light, p_fract);
        } else if (p_idx < 2.0) {
            cur_glow = mix(p1_glow, p2_glow, p_fract);
            cur_light = mix(p1_light, p2_light, p_fract);
        } else if (p_idx < 3.0) {
            cur_glow = mix(p2_glow, p3_glow, p_fract);
            cur_light = mix(p2_light, p3_light, p_fract);
        } else {
            cur_glow = mix(p3_glow, p0_glow, p_fract);
            cur_light = mix(p3_light, p0_light, p_fract);
        }

        if (hit_spiky) {
            let fresnel = pow(1.0 - max(0.0, dot(n, -rd)), 3.0);
            let metal_spec = pow(max(0.0, dot(rd, reflect(-ld, n))), 128.0) * 1.5;
            let grain = hash(p.xz * 100.0) * 0.03;
            let glow_term = spiky_color * (0.4 + fresnel * 0.6);
            col = (vec3<f32>(0.2) + grain + cur_light * metal_spec) * atten * flicker + glow_term;
        } else {
            let q_h = p.xy - tunnel_path(p.z);
            let angle = atan2(q_h.y, q_h.x);
            let snake_m = smoothstep(12.0, 35.0, t);
            let snaking = sin(p.z * 0.3 - t * 6.0) * 2.5 * snake_m;
            let circuit = smoothstep(0.98, 1.0, sin(angle * 10.0 + snaking));
            
            let ld_obj = normalize(obj_pos - p);
            let dist_obj = length(obj_pos - p);
            let atten_obj = exp(-dist_obj * 0.5); 
            let diff_obj = max(0.0, dot(n, ld_obj));
            let spiky_light_cast = spiky_color * diff_obj * atten_obj * 4.0;
            
            let glow_col = cur_glow * circuit * (0.2 + globals.kick * 2.0);
            let light_intensity = (diff + spec) * atten * searchlight * flicker * 4.0;
            col = vec3<f32>(0.002, 0.003, 0.005) + glow_col + cur_light * light_intensity + spiky_light_cast;
        }
        
        if (t > 25.0 && t < 60.0) {
            let orb_interval = 8.0; 
            let orb_t = t - 25.0;
            let orb_cycle = floor(orb_t / orb_interval);
            let orb_fract = fract(orb_t / orb_interval);
            let z_at_spawn = (orb_cycle * orb_interval + 25.0 - 12.0) * 28.0;
            let orb_z = z_at_spawn + 400.0 - orb_fract * orb_interval * 120.0;
            let dist_to_orb = length(p - vec3<f32>(tunnel_path(orb_z), orb_z));
            col += vec3<f32>(0.2, 1.0, 1.0) * (smoothstep(0.8, 0.0, dist_to_orb) * 5.0 + exp(-dist_to_orb * 0.4) * 2.5);
        }
        col *= smoothstep(100.0, 60.0, d);
    }
    return vec4<f32>(col, 1.0);
}
