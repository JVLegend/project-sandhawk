shader_type spatial;
render_mode cull_back, diffuse_burley, specular_disabled;

// Detalhe de areia gerado no shader. A cor base vem do vertex color (dunas,
// rocha e cascalho), e aqui entram grao fino, manchas medias e as ondulacoes
// de vento, que sao o que faz o deserto parar de parecer um lencol liso.
// Tudo procedural: nenhuma textura em disco, coerente com a politica de assets.

uniform float grain_scale = 3.2;
uniform float grain_strength = 0.16;
uniform float macro_scale = 0.09;
uniform float macro_strength = 0.22;
uniform float ripple_scale = 1.25;
uniform float ripple_strength = 0.09;
uniform float detail_fade_start = 34.0;
uniform float detail_fade_end = 70.0;
uniform vec3 macro_tint : source_color = vec3(0.62, 0.45, 0.3);

varying vec3 world_position;


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
}


void fragment() {
	vec3 base = COLOR.rgb;

	// Manchas grandes de mineral, na escala de dezenas de metros.
	float macro = fbm(world_position.xz * macro_scale);
	base = mix(base, base * macro_tint * 2.0, clamp((macro - 0.45) * macro_strength * 4.0, 0.0, macro_strength));

	// Grao fino, que some com a distancia para nao virar ruido na tela.
	float distance_fade = 1.0 - smoothstep(detail_fade_start, detail_fade_end, length(VERTEX));

	float grain = value_noise(world_position.xz * grain_scale);
	base *= 1.0 + (grain - 0.5) * grain_strength * 2.0 * distance_fade;

	// Ondulacoes de vento: bandas curvadas pelo ruido, nao linhas retas.
	float wave_phase = world_position.x * ripple_scale + world_position.z * ripple_scale * 0.35;
	wave_phase += fbm(world_position.xz * 0.22) * 9.0;
	float ripple = sin(wave_phase) * 0.5 + 0.5;
	base *= 1.0 - ripple_strength * (1.0 - ripple) * distance_fade;

	ALBEDO = base;
	ROUGHNESS = 0.94;
	METALLIC = 0.0;
}
