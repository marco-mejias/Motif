shader_type canvas_item;

// Dark edges + a light film grain for the lo-fi look
uniform float strength : hint_range(0.0, 1.0) = 0.6;
uniform float grain : hint_range(0.0, 0.2) = 0.015;

void fragment() {
	vec2 c = UV - 0.5;
	float v = smoothstep(0.3, 0.85, length(c));
	float n = fract(sin(dot(UV * 1000.0 + fract(TIME * 7.0) * 100.0, vec2(12.9898, 78.233))) * 43758.5453);
	// Grain fades out where the vignette darkens, so the corners stay clean
	float grain_a = grain * (1.0 - v);
	float dark_a = v * strength;
	float alpha = grain_a + dark_a * (1.0 - grain_a);
	COLOR = vec4(vec3(n) * grain_a / max(alpha, 0.0001), alpha);
}
