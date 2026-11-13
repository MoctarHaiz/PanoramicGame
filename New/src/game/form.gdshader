shader_type canvas_item;
// Volume for a prop painted flat (the huts, the granary, the fence, the sign): its picture lit as a
// rounded form by the game's sun (upper left, golden hour), the side away from it darker and
// cooler, a warm rim on the edges that face the sun, the foot darkened by the ground's occlusion.
// `dome`: 1 for a dome or a cone (the light falls off round it), 0 for a flat front (left to right
// only). In Godot 4 COLOR already holds the texture times the modulate.

uniform float dome = 1.0;
uniform float strength = 1.0;
uniform vec3 shade_tint : source_color = vec3(0.5, 0.42, 0.64);
uniform vec3 sun_tint : source_color = vec3(1.2, 1.05, 0.86);
uniform float foot_from = 0.82;  // UV.y where the occlusion at the foot begins
uniform float rim_px = 5.0;
// One light at home (blind round 12: "a campfire burns a metre from him and nothing receives it"): away from the
// fire the prop is in the dusk's cool shade (`dusk`), near it in the fire's warm light (`fire_tint`); `fire_at` is the
// fire in the prop's own pixels, `fire_reach` how far its light carries (0: no fire, the prop as before).
uniform vec2 fire_at = vec2(0.0);
uniform float fire_reach = 0.0;
uniform vec3 dusk : source_color = vec3(0.6, 0.58, 0.82);
uniform vec3 fire_tint : source_color = vec3(1.16, 0.98, 0.8);

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	vec4 c = COLOR;
	vec2 q = (UV - vec2(0.5, 0.6)) * vec2(2.0, 1.7);
	float r = clamp(length(q), 0.0, 1.0);
	vec3 n = normalize(vec3(q.x, q.y * dome, 1.0 - 0.7 * dome * r * r));
	vec3 sun = normalize(vec3(-0.62, -0.62, 0.48));
	float l = clamp(dot(n, sun), 0.0, 1.0);
	vec3 k = mix(shade_tint, sun_tint, smoothstep(0.1, 0.9, l));
	k *= 1.0 - smoothstep(foot_from, 1.0, UV.y) * 0.5;
	c.rgb = mix(c.rgb, c.rgb * k, strength);
	float toward = texture(TEXTURE, UV + vec2(-0.7, -0.7) * TEXTURE_PIXEL_SIZE * rim_px).a;
	float rim = clamp(c.a - toward, 0.0, 1.0);
	c.rgb += vec3(1.0, 0.78, 0.48) * rim * 0.55 * strength;
	if (fire_reach > 0.0) {
		vec2 d = (local - fire_at) / fire_reach;
		c.rgb *= mix(dusk, fire_tint, exp(-dot(d, d) * 1.6));
	}
	COLOR = c;
}
