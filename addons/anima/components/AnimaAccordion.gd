@tool
extends AnimaAnimatable
class_name AnimaAccordion

signal animation_completed

export var label := "Accordion" setget set_label
export (Font) var font setget set_font
export var expanded := true setget set_expanded
export var set_size_flags := true
export var button_min_height := 32.0 setget set_button_min_height

var _title: AnimaButton
var _wrapper: VBoxContainer
var _icon: Sprite
var _content_control: Control
var _is_animating := false

const BASE_COLOR = Color("663169")

const CUSTOM_PROPERTIES := {
	# Animation
	ANIMATION_NAME = {
		name = "Animation/Name",
		type = TYPE_STRING,
		default = "fadeIn"
	},
	# Panel
	PANEL_FILL_COLOR = {
		name = "Panel/FillColor",
		type = TYPE_COLOR,
		default = Color("1b212e")
	}
}

var _all_properties: Dictionary = AnimaButton.BUTTON_BASE_PROPERTIES.duplicate()
var _is_ready := false

var _button_colors = {
	NORMAL_FILL_COLOR = BASE_COLOR,
	FOCUSED_FILL_COLOR = BASE_COLOR.lightened(0.1),
	HOVERED_FILL_COLOR = BASE_COLOR.lightened(0.2),
	PRESSED_FILL_COLOR = BASE_COLOR.lightened(0.1),
}

func _enter_tree():
	set_expanded(expanded, false)
	set_button_min_height(button_min_height)

func _init():
	._init()

	_init_layout()

	for color_key in _button_colors:
		_all_properties[color_key].default = _button_colors[color_key]

	_add_properties(CUSTOM_PROPERTIES)
	_add_properties(_all_properties)

	rect_clip_content = true

func _ready():
	_content_control = get_child(get_child_count() - 1)

	set_expanded(expanded)
	set_label(label)

	_is_ready = true
	
	connect("item_rect_changed", self, "_on_resized")

func _draw():
	draw_rect(Rect2(Vector2(0, 0), rect_size), get_property(CUSTOM_PROPERTIES.PANEL_FILL_COLOR.name), true)

func _get_configuration_warning():
	if get_child_count() > 3:
		if _content_control:
			_on_content_control_removed()

		return "AnimaAccordion can only have 1 child component"

	_content_control = get_child(get_child_count() - 1)
	_on_content_control_added()

	return ""

func _init_layout() -> void:
	_wrapper = VBoxContainer.new()
	_icon = Sprite.new()

	_title = AnimaButton.new()

	_icon.texture = load("res://addons/anima/icons/collapse.svg")
	_icon.position = Vector2(16, 16)

	_title.anchor_right = 1
	_title.anchor_bottom = 1
	_title.rect_min_size.y = button_min_height
	_title.rect_size.y = button_min_height
	_title.set(_title.BUTTON_BASE_PROPERTIES.BUTTON_ALIGN.name, 1)
	_title.connect("pressed", self, "_on_Title_pressed")
	_title.connect("mouse_entered", self, "_on_mouse_entered")
	_title.connect("mouse_exited", self, "_on_mouse_exited")

	_title.add_child(_icon)

	for color_key in _button_colors:
		_title.set(AnimaButton.BUTTON_BASE_PROPERTIES[color_key].name, _button_colors[color_key])

	_wrapper.anchor_right = 1
	_wrapper.add_child(_title)

	add_child(_wrapper)

func set_button_min_height(min_height: float) -> void:
	button_min_height = min_height

	if not is_inside_tree():
		return

	_title.rect_min_size.y = button_min_height
	_title.rect_size.y = button_min_height

	var icon_size: Vector2 = AnimaNodesProperties.get_size(_icon)
	_icon.position.y = (_title.rect_size.y - icon_size.y) / 2

	_update_size()

func set_expanded(is_expanded: bool, animate := true) -> void:
	expanded = is_expanded

	if not is_inside_tree():
		if not expanded:
			_icon.rotate(- PI / 2)

		return

	if _is_ready and animate:
		_on_content_control_added()
		_animate_height_change()

		return

	_update_size()

func _update_size() -> void:
	var y: float = _get_expanded_height() if expanded else _get_collapsed_height()

	rect_min_size.y = y
	rect_size.y = y
	# In case there was a fading animation applied
	if _content_control:
		_content_control.modulate.a = 1.0
		_content_control.rect_scale = Vector2.ONE

func _get_collapsed_height() -> float:
	return button_min_height

func _get_expanded_height() -> float:
	if _content_control == null:
		for child in get_children():
			if child is VBoxContainer and not child == _wrapper:
				_content_control = child
				
				break

	if not _content_control:
		return _get_collapsed_height()

	_content_control.margin_bottom = 0
	return _get_collapsed_height() + _content_control.rect_size.y

func _set(property: String, value):
	._set(property, value)

	if _title and property == "label":
		_title.set(property, value)
		_title._on_mouse_exited()
	elif property.begins_with("Button"):
		var p = property.replace("Button", "");

		_title.set(p, value)

func _animate_height_change() -> void:
	var anima: AnimaNode = Anima.begin_single_shot(self, "accordion")
	var easing: int = get_easing()
	var duration = get_duration()
	_is_animating = true

	if not should_animate_property_change():
		duration = ANIMA.MINIMUM_DURATION

	anima.set_default_duration(duration)

	var to_height := _get_expanded_height()
	var from_height := _get_collapsed_height()

	anima.then(
		Anima.Node(self) \
			.anima_property("min_size:y", to_height) \
			.anima_from(from_height) \
			.anima_easing(easing)
	)
	anima.with(
		Anima.Node(self) \
			.anima_property("size:y", to_height) \
			.anima_from(from_height) \
			.anima_easing(easing)
	)

	anima.with(
		Anima.Node(_content_control) \
			.anima_animation(get_property(CUSTOM_PROPERTIES.ANIMATION_NAME.name), null, true)
	)
	anima.with(
		Anima.Node(_icon) \
			.anima_property("rotate", 0) \
			.anima_from(-90) \
			.anima_pivot(ANIMA.PIVOT.CENTER) \
			.anima_easing(easing)
	)

	if expanded:
		anima.play()
	else:
		anima.play_backwards_with_speed(1.5)

	yield(anima, "animation_completed")

	if not should_animate_property_change() and not expanded:
		rect_size.y = from_height

	_is_animating = false

	emit_signal("animation_completed")

func set_label(new_label: String) -> void:
	label = new_label

	_title.set(AnimaButton.BUTTON_BASE_PROPERTIES.BUTTON_LABEL.name, label)

func set_font(new_font: Font) -> void:
	font = new_font

	_title.set(AnimaButton.BUTTON_BASE_PROPERTIES.BUTTON_FONT.name, font)

func _on_Title_pressed():
	set_expanded(!expanded)

func _on_content_control_added() -> void:
	if _content_control == null:
		return

	_content_control.set_position(Vector2(0, _title.rect_min_size.y))

	if set_size_flags:
		_content_control.size_flags_horizontal = SIZE_EXPAND_FILL
		_content_control.size_flags_vertical = SIZE_EXPAND_FILL

		_content_control.anchor_right = 1
		_content_control.anchor_bottom = 1
		_content_control.margin_right = 0
		_content_control.margin_bottom = 0

	_content_control.margin_top = _title.rect_min_size.y

func _on_content_control_removed() -> void:
	_content_control = null

func _on_mouse_entered() -> void:
	emit_signal("mouse_entered")

func _on_mouse_exited() -> void:
	emit_signal("mouse_exited")

func _on_resized() -> void:
	var c: Node = get_child(2)

	c.rect_size.x = rect_size.x
