shader_type spatial;
render_mode cull_back, diffuse_burley;

// Areia com textura real por cima da direcao de arte procedural.
//
// A cor base continua vindo do vertex color (duna, rocha, cascalho, argila),
// que e o que define a leitura do mapa. As texturas entram como DETALHE:
// micro-variacao de cor, relevo de verdade via normal map e rugosidade
// variavel. Assim a paleta continua sob controle e o chao para de parecer
// plastico liso sob o sol.
//
// Texturas: ambientCG Ground054 (CC0). Ver assets/CREDITS.md.
//
// O normal mapping monta a base tangente no proprio fragment a partir da
// normal do mundo. A malha do terreno nao tem tangentes (e gerada em codigo),
// e para um terreno com UV alinhado ao plano XZ essa base e exata.

uniform sampler2D sand_color : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_roughness : hint_default_white, filter_linear_mipmap, repeat_enable;

// Escala escolhida para o texel cair perto de 1:1 na tela nesta camera: mais
// fino que isso o mipmap engole o detalhe e a areia vira borrao liso.
uniform float detail_uv_scale = 0.06;
uniform float macro_uv_scale = 0.013;
uniform float detail_color_strength = 0.6;
uniform float macro_color_strength = 0.34;
uniform float normal_strength = 1.5;
uniform float roughness_min = 0.72;
uniform float roughness_max = 0.99;

uniform float ripple_scale = 1.25;
uniform float ripple_strength = 0.07;
uniform float detail_fade_start = 42.0;
uniform float detail_fade_end = 95.0;

varying vec3 world_position;
varying vec3 world_normal;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float total = 0.0;
	float amplitude = 0.5;
	for (int i = 0; i < 3; i++) {
		total += value_noise(p) * amplitude;
		p *= 2.03;
		amplitude *= 0.5;
	}
	return total;
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}


void fragment() {
	vec2 detail_uv = world_position.xz * detail_uv_scale;
	vec2 macro_uv = world_position.xz * macro_uv_scale;

	float distance_fade = 1.0 - smoothstep(detail_fade_start, detail_fade_end, length(VERTEX));

	// A textura entra como modulacao em torno de 1.0, nao como cor absoluta:
	// o vertex color continua mandando na paleta.
	vec3 detail_sample = texture(sand_color, detail_uv).rgb;
	vec3 macro_sample = texture(sand_color, macro_uv).rgb;

	float detail_luma = dot(detail_sample, vec3(0.299, 0.587, 0.114));
	float macro_luma = dot(macro_sample, vec3(0.299, 0.587, 0.114));

	vec3 base = COLOR.rgb;
	base *= 1.0 + (detail_luma - 0.5) * detail_color_strength * 2.0 * distance_fade;
	base *= 1.0 + (macro_luma - 0.5) * macro_color_strength * 2.0;

	// Leve puxada para o matiz da textura, sem deixar ela dominar.
	vec3 tinted = base * (detail_sample / max(detail_luma, 0.001));
	base = mix(base, tinted, 0.25 * distance_fade);

	// Ondulacoes de vento continuam procedurais: acompanham a duna, nao a UV.
	float wave_phase = world_position.x * ripple_scale + world_position.z * ripple_scale * 0.35;
	wave_phase += fbm(world_position.xz * 0.22) * 9.0;
	float ripple = sin(wave_phase) * 0.5 + 0.5;
	base *= 1.0 - ripple_strength * (1.0 - ripple) * distance_fade;

	ALBEDO = base;

	// Base tangente construida a partir da normal do mundo. Sem isso o normal
	// map so funcionaria com tangentes na malha, que o terreno gerado nao tem.
	vec3 n = normalize(world_normal);
	vec3 t = vec3(1.0, 0.0, 0.0);
	t = normalize(t - n * dot(n, t));
	vec3 b = cross(n, t);

	vec3 tangent_normal = texture(sand_normal, detail_uv).xyz * 2.0 - 1.0;
	tangent_normal.xy *= normal_strength * distance_fade;
	vec3 perturbed = normalize(t * tangent_normal.x + b * tangent_normal.y + n * tangent_normal.z);

	NORMAL = normalize((VIEW_MATRIX * vec4(perturbed, 0.0)).xyz);

	float rough_sample = texture(sand_roughness, detail_uv).r;
	ROUGHNESS = mix(roughness_min, roughness_max, rough_sample);
	METALLIC = 0.0;
	SPECULAR = 0.25;
}
