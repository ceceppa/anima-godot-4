@tool
extends Node

enum PORT {
	INPUT,
	OUTPUT
}

enum PORT_TYPE {
	LABEL_ONLY,
	ANIMATION,
	EVENT,
	ACTION,
}

enum NODE_TYPE {
	START,
	ANIMATION,
	ACTION,
	MUSIC
}

enum VISUAL_ANIMATION_TYPE {
	ANIMATION,
	PROPERTY
}
# Used to get Godot Icons
var _godot_base_control: Control
var _anima_visual_node: Node

var _custom_animations := {}
var _animations_list := []

const _is_debug_enabled := false

const MAPPED_ICONS := {
	TYPE_FLOAT: 'float',
	TYPE_INT: 'int',
	TYPE_VECTOR2: 'Vector2',
	TYPE_VECTOR3: 'Vector3',
	TYPE_COLOR: 'Color',
	TYPE_RECT2: 'Rect2'
}

func get_dpi_scale() -> float:
	return 1.0
#	return OS.get_screen_dpi() / 256.0

func set_godot_gui(base_control: Control) -> void:
	_godot_base_control = base_control

func get_godot_icon(name: String) -> Texture:
	if _godot_base_control:
		return _godot_base_control.get_icon(name, "EditorIcons")

	return null

func get_node_icon(node: Node) -> Texture:
	var node_icon: Texture = get_godot_icon(node.get_class())

	if node.has_method('get_editor_icon'):
		node_icon = node.get_editor_icon()

	return node_icon

func debug(caller, v1: String, v2 = "", v3 = "", v4 = "", v5 = "", v6 = "") -> void:
	if not _is_debug_enabled:
		return

	printt(caller, v1, v2, v3, v4, v5, v6)

func get_godot_icon_for_type(type: int) -> Texture:
	if MAPPED_ICONS.has(type):
		return get_godot_icon(MAPPED_ICONS[type])

	return get_godot_icon('KeyValue')
	
