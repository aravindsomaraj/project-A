class_name SurfacePhaseView
extends TextureRect
## Dissolves a live source viewport over the live destination view.
## Replace this component to change the phase presentation independently of timing.
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform float progress = 0.0;
void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float radius = length((UV - vec2(0.5, 0.65)) * vec2(1.7778, 1.0));
	float wave = exp(-pow((radius - progress * 1.5) * 45.0, 2.0));
	COLOR = vec4(mix(source.rgb, vec3(0.25, 0.85, 1.0), wave * 0.25), 1.0 - progress);
}
"""
	var effect := ShaderMaterial.new()
	effect.shader = shader
	material = effect
	visible = false

func capture(source_texture: Texture2D) -> void:
	texture = source_texture
	(material as ShaderMaterial).set_shader_parameter("progress", 0.0)
	visible = true
func update_phase(active: bool, weight: float) -> void:
	visible = active and texture != null
	(material as ShaderMaterial).set_shader_parameter("progress", weight)
	if not active:
		texture = null

