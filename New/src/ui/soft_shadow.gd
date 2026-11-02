class_name SoftShadow
extends CanvasGroup
## Draws its children with a soft shadow falling down-right, as if lit from the upper left like the
## rest of the game (docs/art/STYLE.md). Offset and blur are in design units and follow the
## screen's scale. (In the Compatibility renderer a CanvasGroup's mipmaps don't blur, so the shader
## blurs with a few taps.)

static var _shader: Shader

var offset := Vector2(8, 12)
var blur := 5.0
var _material := ShaderMaterial.new()


func _init(shadow_offset := Vector2(8, 12), shadow_blur := 5.0, colour := Color(0.11, 0.08, 0.2, 0.34)) -> void:
	offset = shadow_offset
	blur = shadow_blur
	if not _shader:
		_shader = load("res://src/ui/soft_shadow.gdshader")
	_material.shader = _shader
	_material.set_shader_parameter(&"shadow", colour)
	material = _material
	fit_margin = offset.length() + blur * 2.0
	clear_margin = fit_margin


func _process(_delta: float) -> void:
	var k := get_viewport().get_final_transform().get_scale().x * get_global_transform_with_canvas().get_scale().x
	_material.set_shader_parameter(&"offset", offset * k)
	_material.set_shader_parameter(&"radius", blur * k)
