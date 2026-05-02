shader_type canvas_item;

uniform vec3 sky_dark : source_color = vec3(0.025, 0.045, 0.09);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void fragment() {
	vec2 uv = UV * vec2(420.0, 740.0);
	vec2 id = floor(uv);
	vec2 f = fract(uv) - 0.5;
	float h = hash(id);
	float star = smoothstep(0.978, 1.0, h) * (0.55 + 0.45 * sin(TIME * 1.7 + h * 12.0));
	float tw = star * (1.0 - length(f) * 1.8);
	vec3 col = sky_dark + vec3(tw * 0.95, tw * 0.92, tw);
	COLOR = vec4(col, 1.0);
}
