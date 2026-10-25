shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blend : hint_range(0.0, 1.0) = 0.0;
uniform float blur_amount = 2.0;
uniform float saturation = 0.35;
void fragment() {
	vec3 scene = textureLod(screen_texture, SCREEN_UV, blur_amount).rgb;
	float grey = dot(scene, vec3(0.2126, 0.7152, 0.0722));
	vec3 muted = mix(vec3(grey), scene, saturation);
	float vignette = smoothstep(0.25, 0.8, length((SCREEN_UV - 0.5) * vec2(1.2, 1.0)));
	COLOR = vec4(muted * (0.38 - 0.17 * vignette), blend);
}
