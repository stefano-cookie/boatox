shader_type spatial;

// Mare low-poly: onde sinusoidali nel vertex shader, normali a facce
// ricavate dalle derivate in fragment. La stessa matematica vive in
// sea.gd (get_height) per il galleggiamento: le due copie vanno
// tenute allineate.

uniform float u_time = 0.0;
// dir.x, dir.y, ampiezza, lunghezza d'onda
uniform vec4 wave_a = vec4(1.0, 0.0, 0.22, 14.0);
uniform vec4 wave_b = vec4(0.423, 0.906, 0.12, 8.0);
uniform vec4 wave_c = vec4(-0.643, 0.766, 0.06, 4.5);
uniform vec3 wave_speeds = vec3(3.0, 2.4, 1.8);

// Zone di mare: anelli concentrici dal centro mappa con moltiplicatore
// d'ampiezza crescente (calme -> medie -> mosse).
uniform float calm_radius = 110.0;
uniform float medium_radius = 180.0;
uniform float zone_blend = 30.0;
// moltiplicatori: x = calme, y = medie, z = mosse
uniform vec3 zone_amps = vec3(0.6, 1.5, 2.8);

float sea_state(vec2 p) {
	float d = length(p);
	float m = mix(zone_amps.x, zone_amps.y,
		smoothstep(calm_radius - zone_blend * 0.5, calm_radius + zone_blend * 0.5, d));
	return mix(m, zone_amps.z,
		smoothstep(medium_radius - zone_blend * 0.5, medium_radius + zone_blend * 0.5, d));
}

uniform vec3 deep_color : source_color = vec3(0.02, 0.15, 0.28);
uniform vec3 shallow_color : source_color = vec3(0.13, 0.47, 0.53);
uniform vec3 crest_color : source_color = vec3(0.85, 0.95, 0.95);
uniform float crest_amount : hint_range(0.0, 1.0) = 0.5;
uniform float water_roughness : hint_range(0.0, 1.0) = 0.12;

varying vec3 v_world_pos;
varying float v_height;

float wave_height(vec2 p, vec4 w, float speed) {
	float k = TAU / max(w.w, 0.01);
	return w.z * sin(k * (dot(w.xy, p) - speed * u_time));
}

float sea_height(vec2 p) {
	return (wave_height(p, wave_a, wave_speeds.x)
		+ wave_height(p, wave_b, wave_speeds.y)
		+ wave_height(p, wave_c, wave_speeds.z)) * sea_state(p);
}

void vertex() {
	vec3 wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float h = sea_height(wpos.xz);
	VERTEX.y += h;
	v_height = h;
	v_world_pos = vec3(wpos.x, wpos.y + h, wpos.z);
}

void fragment() {
	vec3 n = cross(dFdy(v_world_pos), dFdx(v_world_pos));
	if (n.y < 0.0) {
		n = -n;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(n), 0.0)).xyz);

	float total_amp = (wave_a.z + wave_b.z + wave_c.z) * sea_state(v_world_pos.xz);
	float hf = clamp(v_height / max(total_amp, 0.001) * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = mix(deep_color, shallow_color, hf);
	col = mix(col, crest_color, smoothstep(0.75, 1.0, hf) * crest_amount);
	ALBEDO = col;
	ROUGHNESS = water_roughness;
	SPECULAR = 0.6;
}
