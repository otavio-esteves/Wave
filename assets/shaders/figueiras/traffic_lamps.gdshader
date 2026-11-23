shader_type spatial;
render_mode unshaded, shadows_disabled;

varying vec4 lens;

void vertex() {
	lens = INSTANCE_CUSTOM;
}

void fragment() {
	ALBEDO = lens.rgb * (0.37 + lens.a);
}
