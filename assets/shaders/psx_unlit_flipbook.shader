shader_type spatial;
render_mode unshaded, cull_back, shadows_disabled, depth_draw_opaque;

uniform float precision_multiplier : hint_range(0.0, 1.0) = 1.0;
uniform sampler2D texture_albedo : hint_albedo;
uniform float frames = 4.0;
uniform float speed = 1.0;

// https://github.com/dsoft20/psx_retroshader/blob/master/Assets/Shaders/psx-vertexlit.shader
vec4 get_snapped_pos(vec4 base_pos, vec2 base_snap_res)
{
	vec4 snapped_pos = base_pos;
	snapped_pos.xyz = base_pos.xyz / base_pos.w; // convert to normalised device coordinates (NDC)
	vec2 snap_res = floor(base_snap_res * precision_multiplier);  // increase \"snappy-ness\"
	snapped_pos.x = floor(snap_res.x * snapped_pos.x) / snap_res.x;  // snap the base_pos to the lower-vertex_resolution grid
	snapped_pos.y = floor(snap_res.y * snapped_pos.y) / snap_res.y;
	snapped_pos.xyz *= base_pos.w;  // convert back to projection-space
	return snapped_pos;
}

void vertex()
{
	float frame_offset = floor(mod(TIME * speed, frames));
	UV.x = (UV.x + frame_offset) / frames;

	POSITION = get_snapped_pos(PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0), VIEWPORT_SIZE);  // snap position to grid
	POSITION /= abs(POSITION.w);  // discard depth for affine mapping

	VERTEX = VERTEX;  // it breaks without this - not sure why
}

void fragment() {
	vec4 albedo_tex = texture(texture_albedo, UV);
	ALBEDO = albedo_tex.rgb * COLOR.rgb;
}