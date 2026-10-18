shader_type canvas_item;

// Draws a one-pixel outline in the rarity's colour just outside the art's
// silhouette, for the weapon in the hero's hand. Needs a transparent margin
// around the art, which the 64x64 weapon frames have.

uniform vec4 outline_color : source_color = vec4(1.0);
uniform float pulse_depth : hint_range(0.0, 1.0) = 0.0;
uniform float pulse_speed = 3.0;

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float neighbours = 0.0;
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			neighbours = max(neighbours, texture(TEXTURE, UV + vec2(float(dx), float(dy)) * px).a);
		}
	}
	float pulse = 1.0 - pulse_depth * (0.5 + 0.5 * sin(TIME * pulse_speed));
	float edge = neighbours * (1.0 - COLOR.a);
	COLOR = mix(COLOR, vec4(outline_color.rgb, pulse), edge);
}
