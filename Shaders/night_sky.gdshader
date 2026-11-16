shader_type canvas_item;

// 0 = 5:00 AM deep night, 1 = first light. Main raises it as the night is resolved.
uniform float dawn : hint_range(0.0, 1.0) = 0.0;
uniform float aspect = 0.5625; // width / height of the rect, set by Scenery.gd

uniform vec3 night_top : source_color = vec3(0.025, 0.03, 0.08);
uniform vec3 night_bottom : source_color = vec3(0.17, 0.10, 0.29);
uniform vec3 dawn_top : source_color = vec3(0.19, 0.22, 0.46);
uniform vec3 dawn_bottom : source_color = vec3(1.0, 0.63, 0.53);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	float y = 1.0 - uv.y; // 0 at the bottom

	// Sky gradient
	vec3 top = mix(night_top, dawn_top, dawn);
	vec3 bottom = mix(night_bottom, dawn_bottom, dawn);
	vec3 col = mix(top, bottom, pow(uv.y, 1.7));

	// Twinkling stars, fading with the dawn and near the horizon
	vec2 sp = vec2(uv.x * aspect, uv.y) * 160.0;
	vec2 cell = floor(sp);
	float h = hash(cell);
	if (h > 0.982) {
		vec2 f = fract(sp) - 0.5;
		float twinkle = 0.55 + 0.45 * sin(TIME * (0.8 + h * 3.0) + h * 50.0);
		float star = smoothstep(0.2, 0.0, length(f)) * twinkle;
		col += vec3(0.9, 0.9, 1.0) * star * (1.0 - dawn) * smoothstep(0.25, 0.7, y);
	}

	// Moon, sinking a bit as the night goes on
	vec2 moon_pos = vec2(0.78, 0.16 + dawn * 0.12);
	float md = length((uv - moon_pos) * vec2(aspect, 1.0));
	col += vec3(1.0, 0.95, 0.85) * smoothstep(0.035, 0.03, md) * (1.0 - dawn * 0.6);
	col += vec3(0.6, 0.55, 0.9) * smoothstep(0.18, 0.0, md) * 0.12 * (1.0 - dawn);

	// Far skyline
	float far_id = floor(uv.x * aspect * 34.0);
	float far_h = 0.17 + hash(vec2(far_id, 7.0)) * 0.11;
	vec3 far_col = mix(vec3(0.075, 0.06, 0.15), vec3(0.42, 0.30, 0.44), dawn);
	if (y < far_h) {
		col = far_col;
	}

	// Near skyline with lit windows (people who also can't sleep)
	float bx = uv.x * aspect * 16.0;
	float id = floor(bx);
	float near_h = 0.08 + hash(vec2(id, 1.0)) * 0.15;
	if (y < near_h) {
		col = mix(vec3(0.03, 0.028, 0.06), vec3(0.18, 0.12, 0.2), dawn);
		vec2 wp = vec2(fract(bx) * 5.0, y * 70.0);
		vec2 wc = floor(wp);
		vec2 wf = fract(wp);
		float window_shape = step(0.3, wf.x) * step(wf.x, 0.7) * step(0.3, wf.y) * step(wf.y, 0.72);
		float inside = step(0.5, wc.x) * step(wc.x, 3.5) * step(y, near_h - 0.012);
		float lit = step(0.8, hash(wc + id * 17.0 + floor(TIME * 0.03 + hash(wc + id))));
		col = mix(col, vec3(1.0, 0.8, 0.48), window_shape * inside * lit * (1.0 - dawn * 0.6));
	}

	COLOR = vec4(col, 1.0);
}
