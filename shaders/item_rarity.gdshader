shader_type canvas_item;

// Shifts an item's art towards its rarity's colour, keeping the shading.
// Dark pixels, the item's outline, are left alone so it keeps its edge.

uniform vec4 rarity_color : source_color = vec4(1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	float luma = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	vec3 recoloured = min(rarity_color.rgb * (0.4 + luma), vec3(1.0));
	float body = smoothstep(0.15, 0.35, luma);
	COLOR.rgb = mix(COLOR.rgb, recoloured, strength * body);
}
