shader_type spatial;

// Mare low-poly: onde sinusoidali nel vertex shader, normali a facce
// ricavate dalle derivate in fragment. La stessa matematica vive in
// sea.gd (get_height) per il galleggiamento: le due copie vanno
// tenute allineate.

uniform float u_time = 0.0;
// dir.x, dir.y, ampiezza, lunghezza d'onda
uniform vec4 wave_a = vec4(0.0, -1.0, 0.22, 14.0);
uniform vec4 wave_b = vec4(0.574, -0.819, 0.12, 8.0);
uniform vec4 wave_c = vec4(-0.643, -0.766, 0.06, 4.5);
uniform vec3 wave_speeds = vec3(3.0, 2.4, 1.8);

// Zone di mare a fasce parallele alla costa (terra a z < shore_z):
// risacca sulla battigia, poi acque calme -> medie -> mare aperto, dove
// l'agitazione di base cresce con la distanza (curva continua).
uniform float shore_z = -140.0;
uniform float calm_width = 110.0;
uniform float medium_width = 220.0;
uniform float zone_blend = 40.0;
// moltiplicatori: x = calme, y = medie, z = inizio largo, w = largo estremo
uniform vec4 zone_amps = vec4(0.6, 1.5, 1.7, 2.6);
uniform float open_far_distance = 700.0;
uniform float shore_lap_distance = 30.0;
uniform float shore_min_multiplier = 0.25;
// Meteo dinamico sopra le zone statiche: 1 = calmo, >1 = mosso.
uniform float weather_mult = 1.0;
// Celle di vento del WindField: xy = centro, z = raggio, w = intensità.
// Falloff identico a WindField.wind_multiplier (le copie vanno allineate).
uniform vec4 wind_cells[6];
uniform float wind_strength = 0.9;

float sea_state(vec2 p) {
	float d = p.y - shore_z;
	float open_amp = mix(zone_amps.z, zone_amps.w,
		clamp((d - medium_width) / max(open_far_distance - medium_width, 1.0), 0.0, 1.0));
	float m = mix(zone_amps.x, zone_amps.y,
		smoothstep(calm_width - zone_blend * 0.5, calm_width + zone_blend * 0.5, d));
	m = mix(m, open_amp,
		smoothstep(medium_width - zone_blend * 0.5, medium_width + zone_blend * 0.5, d));
	m *= mix(shore_min_multiplier, 1.0, smoothstep(0.0, shore_lap_distance, d));
	float wind = 0.0;
	for (int i = 0; i < 6; i++) {
		float r = wind_cells[i].z;
		if (wind_cells[i].w <= 0.0 || r <= 0.0) {
			continue;
		}
		float fall = 1.0 - smoothstep(r * 0.35, r, distance(p, wind_cells[i].xy));
		wind += wind_cells[i].w * fall;
	}
	m *= 1.0 + wind_strength * wind;
	return m * weather_mult;
}

uniform vec3 deep_color : source_color = vec3(0.02, 0.15, 0.28);
uniform vec3 shallow_color : source_color = vec3(0.13, 0.47, 0.53);
uniform vec3 crest_color : source_color = vec3(0.85, 0.95, 0.95);
// Turchese del bagnasciuga: l'acqua bassa sulla sabbia (vibe Bova Marina).
uniform vec3 beach_color : source_color = vec3(0.21, 0.62, 0.6);
uniform float beach_blend_distance = 38.0;
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
	float shore_d = v_world_pos.z - shore_z;
	col = mix(beach_color, col, smoothstep(2.0, beach_blend_distance, shore_d));
	col = mix(col, crest_color, smoothstep(0.75, 1.0, hf) * crest_amount);
	ALBEDO = col;
	ROUGHNESS = water_roughness;
	SPECULAR = 0.6;
}
