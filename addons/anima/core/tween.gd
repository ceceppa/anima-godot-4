@tool
class_name AnimaTween
extends Node

signal animation_completed

const VISIBILITY_STRATEGY_META_KEY = "__visibility_strategy"

var PROPERTIES_TO_ATTENUATE = ["rotate", "rotation", "rotation:y", "rotate:y", "y", "position:y", "x"]

var _animation_data := []
var _callbacks := {}
var _loop_strategy = ANIMA.LOOP_STRATEGY.USE_EXISTING_RELATIVE_DATA
var _tween_completed := 0
var _tween_started := 0
var _root_node: Node
var _tween: Tween

enum PLAY_MODE {
	NORMAL,
	BACKWARDS,
	LOOP_IN_CIRCLE
}

var _frame_key_checker = RegEx.new()

func _enter_tree():
	var tree: SceneTree = get_tree()

	if tree:
		_tween = tree.create_tween()

		_tween.set_parallel(true)
		_tween.pause()

func _exit_tree():
	_tween.kill()

func _ready():
	_frame_key_checker.compile("\\d")

#	print("ready", _tween.get_signal_list())
#	_tween.connect("tween_started", _on_tween_started)
	_tween.connect("finished", _on_tween_completed)

	#
	# By default Godot runs interpolate_property animation runs only once
	# this means that if you try to play again it won't work.
	# Possible solutions are:
	# - resetting the tween data and recreating all over again before starting the animation
	# - recreating the anima animation again before playing
	# - cheat
	#
	# Of the 3 I did prefer "cheating" making belive Godot that this tween is in a
	# repeat loop.
	# So, once all the animations are completed (_tween_completed == _animation_data.size())
	# we pause the tween, and next time we call play again we resume it and it works...
	# There is no need to recreating anything on each "loop"
	set_loops(0)

func play(play_speed: float):
	_tween.set_speed_scale(play_speed)

	_tween_completed = 0

	_tween.play()

func set_loops(loops: int) -> void:
	_tween.set_loops(loops)
	
func add_animation_data(animation_data: Dictionary, play_mode: int = PLAY_MODE.NORMAL) -> void:
	var index: String
	var is_backwards_animation = play_mode != PLAY_MODE.NORMAL

	_animation_data.push_back(animation_data)
	index = str(_animation_data.size())

	var duration = animation_data.duration if animation_data.has('duration') else ANIMA.DEFAULT_DURATION

	if animation_data.has('visibility_strategy'):
		_apply_visibility_strategy(animation_data)

	if animation_data.has("initial_value"):
		if not animation_data.has("initial_values"):
			animation_data.initial_values = {}

		animation_data.initial_values[animation_data.property] = animation_data.initial_value

		if animation_data.has("__debug") and (animation_data.__debug == true or animation_data.__debug == animation_data.property):
			prints("Applying initial value", animation_data.initial_value)

	var ignore_initial_values = animation_data.has("_ignore_initial_values") and animation_data._ignore_initial_values

	if animation_data.has("initial_values") and not is_backwards_animation and not ignore_initial_values:
		if animation_data.has("__debug") and (animation_data.__debug == "true" or animation_data.__debug == animation_data.property):
			prints("Applying initial values", animation_data.initial_values)

		if not animation_data.has("to"):
			printerr("When using '_initial_value' the 'to' cannot be empty!")
		else:
			_apply_initial_values(animation_data)

	var easing_points

	if animation_data.has("easing") and not animation_data.easing == null:
		if animation_data.easing is Callable or animation_data.easing is Array:
			easing_points = animation_data.easing
		elif animation_data.easing is Curve:
			easing_points = animation_data.easing
		else:
			easing_points = AnimaEasing.get_easing_points(animation_data.easing)

	animation_data._easing_points = easing_points

	var property_data: Dictionary = {}
	var node: Node = animation_data.node

	if animation_data.property is Object:
		property_data = {
			property = animation_data.property,
			key = animation_data.key
		}
	else:
		property_data = AnimaNodesProperties.map_property_to_godot_property(node, animation_data.property)

	if not property_data.has("property") and not property_data.has("callback"):
#		printerr("property/callback missing or not recognised for the animation: ", animation_data.property)
		return

	var object: Node = _get_animated_object_item(property_data)
	var use_method: String = "animate_linear"

	if easing_points is Array:
		use_method = 'animate_with_easing'
	elif easing_points is String:
		use_method = 'animate_with_anima_easing'
	elif easing_points is Callable:
		use_method = 'animate_with_easing_funcref'
	elif easing_points is Curve:
		use_method = 'animate_with_curve'

	var from := 0.0 if play_mode == PLAY_MODE.NORMAL else 1.0
	var to := 1.0 - from

	object.set_animation_data(animation_data, property_data, is_backwards_animation)
	var callable := Callable(object, use_method)

	if animation_data.has("__debug") and (animation_data.__debug == "true" or animation_data.__debug == animation_data.property):
		printt("use_method", use_method)

	_tween.tween_method(
		callable,
		0.0,
		1.0,
		duration
	).set_delay(animation_data._wait_time)

	add_child(object)

	if not node.is_connected("tree_exiting", _on_node_tree_exiting):
		node.connect("tree_exiting", _on_node_tree_exiting)

func set_repeat(repeat) -> void:
	# TODO: Implement
	pass

func _apply_initial_values(animation_data: Dictionary) -> void:
	var node: Node = animation_data.node

	for property in animation_data.initial_values:
		var value = animation_data.initial_values[property]
		var property_data = AnimaNodesProperties.map_property_to_godot_property(node, property)
		var is_rect2 = property_data.has("is_rect2") and property_data.is_rect2
		var is_object = property_data.has("property") and typeof(property_data.property) == TYPE_OBJECT

		if value is String:
			value = AnimaTweenUtils.maybe_calculate_value(value, animation_data)

		if is_rect2:
			push_warning("not yet implemented")
			pass
		elif is_object:
			push_warning("not yet implemented")
			pass
		elif property_data.has("callback"):
			property_data.callback.call(property_data.param, value)
			pass
		elif property_data.has('subkey'):
			node[property_data.property][property_data.key][property_data.subkey] = value
		elif property_data.has('key'):
			node[property_data.property][property_data.key] = value
		else:
			node[property_data.property] = value

		if animation_data.has("__debug") and (animation_data.__debug == "true" or animation_data.__debug == animation_data.property):
			printt("", "Initial value", property, value, property_data)

func _get_animated_object_item(property_data: Dictionary) -> Node:
	var is_rect2 = property_data.has("is_rect2") and property_data.is_rect2
	var animate_callback := property_data.has("callback")
	var is_object = property_data.has("property") and typeof(property_data.property) == TYPE_OBJECT

	if is_rect2:
		return AnimateRect2.new()
	elif is_object:
		if property_data.has("subkey"):
			return AnimateObjectWithSubKey.new()

		return AnimateObjectWithKey.new()
	elif property_data.has('subkey'):
		return AnimatedPropertyWithSubKeyItem.new()
	elif property_data.has('key'):
		return AnimatedPropertyWithKeyItem.new()
	elif animate_callback:
		if property_data.has("param"):
			return AnimatedCallbackWithParam.new()

		return AnimatedCallback.new()

	return AnimatedPropertyItem.new()

# Needed for animations created via the Visual Editor
func set_root_node(node: Node) -> void:
	_root_node = node

#
# Given an CSS-Keyframe like Dictionary of frames generates the animation frames
#
#	0: {
#		opacity = 0,
#		scale = Vector2(0.3, 0.3),
#		y = 100,
#		easing = [0.55, 0.055, 0.675, 0.19],
#	},
#	60: {
#		opacity = 1,
#		scale = Vector2(0.475, 0.475),
#		y = 100,
#		easing = [0.55, 0.055, 0.675, 0.19]
#	},
#	100: {
#		scale = Vector2(1, 1),
#		y = 0
#	}
#
func add_frames(animation_data: Dictionary, full_keyframes_data: Dictionary) -> float:
	var last_duration := 0.0
	var relative_properties: Array = ["x", "y", "z", "position", "position:x", "position:z", "position:y"]
	var pivot = full_keyframes_data.pivot if full_keyframes_data.has("pivot") else null
	var easing = full_keyframes_data.easing if full_keyframes_data.has("easing") else null

	if animation_data.has("_ignore_relative") and animation_data._ignore_relative:
		relative_properties = []

	if full_keyframes_data.has("relative"):
		relative_properties = full_keyframes_data.relative

	animation_data._relative_to = ANIMA.RELATIVE_TO.INITIAL_VALUE

	if full_keyframes_data.has("relativeTo"):
		animation_data._relative_to = full_keyframes_data.relativeTo

	# Flattens the keyframe_data
	var keyframes_data = AnimaTweenUtils.flatten_keyframes_data(full_keyframes_data)

	var previous_key_value := {}
	var wait_time: float = animation_data._wait_time if animation_data.has('_wait_time') else 0.0

	if pivot:
		animation_data.pivot = pivot

	if keyframes_data.has("initial_values"):
		animation_data.initial_values = keyframes_data.initial_values

	if easing:
		animation_data.easing = easing

	keyframes_data.erase("initial_values")

	var frame_keys: Array = keyframes_data.keys()
	frame_keys.sort_custom(_sort_frame_index)

	var base_data = animation_data.duplicate()
	var node: Node = animation_data.node
	var real_duration := 0.0
	var first_frame_data: Dictionary = keyframes_data["0"] if keyframes_data.has("0") else {}

	var all_properties_to_animate := []

	for key in keyframes_data:
		if ["from", "to"].has(key) or _is_valid_frame_key(key):
			for property_key in keyframes_data[key]:
				if not all_properties_to_animate.has(property_key) and not property_key == "easing":
					all_properties_to_animate.push_back(property_key)

	for property_to_animate in all_properties_to_animate:
		var current_value = AnimaNodesProperties.get_property_value(node, {}, property_to_animate)
		var value = first_frame_data[property_to_animate] if first_frame_data.has(property_to_animate) else current_value

		if value is String:
			value = AnimaTweenUtils.maybe_calculate_value(value, base_data)

		if relative_properties.has(property_to_animate) and first_frame_data.has(property_to_animate):
			value += AnimaNodesProperties.get_property_value(animation_data.node, animation_data, property_to_animate)

		var data := { percentage = 0, value = value }

		base_data.property = property_to_animate
		previous_key_value[property_to_animate] = data
		# node.set_meta("__initial_" + str(property_to_animate), current_value)

		if current_value != value and relative_properties.find(property_to_animate) < 0:
			data.initial_value = value

	frame_keys.pop_front()

	#
	# Sometimes we want to be able to define the duration of each single step.
	# For example for "typewrite" we want to specify the duration of the animation of the single
	# character, instead of the full sentences, otherwise different string length will
	# have different speed.
	# In those cases we can define a special key called "_duration" where we can specify a formula
	# using the "dynamic value" capability.
	#
	if full_keyframes_data.has("_duration"):
		var duration_formula = full_keyframes_data._duration.replace("{duration}", animation_data.duration)
		real_duration = AnimaTweenUtils.maybe_calculate_value(duration_formula, animation_data)

		animation_data.duration = real_duration

	if animation_data.has("__debug"):
		prints("add_frames", animation_data)
		printt("", "keys", frame_keys)

	var is_first_frame := true
	for frame_key in frame_keys:
		var is_valid_frame_key = _is_valid_frame_key(frame_key)
		var frame_key_value = str(frame_key).to_float()

		if not is_valid_frame_key or frame_key_value > 100:
			continue

		var keyframe_data: Dictionary = keyframes_data[frame_key]

		animation_data._is_first_frame = is_first_frame
		animation_data._is_last_frame = frame_key_value == 100

		var is_relative: bool = relative_properties.find(frame_key)

		_calculate_frame_data(
			wait_time,
			animation_data,
			relative_properties,
			frame_key_value,
			keyframes_data[frame_key],
			previous_key_value
		)

		animation_data.erase("initial_values")

		is_first_frame= false

	return real_duration

func _is_valid_frame_key(key) -> bool:
	if typeof(key) == TYPE_INT or typeof(key) == TYPE_FLOAT:
		return true

	return _frame_key_checker.search(key) != null

func _sort_frame_index(a, b) -> bool:
	return str(a).to_float() < str(b).to_float()

func _calculate_frame_data(wait_time: float, animation_data: Dictionary, relative_properties: Array, current_frame_key: float, frame_data: Dictionary, previous_key_value: Dictionary) -> void:
	var duration: float = animation_data.duration if animation_data.has('duration') else 0.0
	var easing = null
	var pivot = null

	if animation_data.has("easing"):
		easing = animation_data.easing

	if frame_data.has("easing"):
		easing = frame_data.easing

	var node: Node = animation_data.node
	var is_mesh = node is MeshInstance3D
	var keys := []

	for key in frame_data.keys():
		if key == "easing" or key == "pivot":
			continue

		if key == "skew":
			var skew: Vector2 = frame_data[key]

			frame_data["skew:x"] = skew.x / 32
			frame_data["skew:y"] = skew.y / 32

			if previous_key_value.skew and not previous_key_value.has("skew:x"):
				var p: Dictionary = previous_key_value.skew

				previous_key_value["skew:x"] = { percentage = p.percentage, value = p.value.x }
				previous_key_value["skew:y"] = { percentage = p.percentage, value = p.value.y }

			keys.push_back("skew:x")
			key = "skew:y"

		keys.push_back(key)

	for property_to_animate in keys:
		var data = animation_data.duplicate()
		var start_percentage = previous_key_value[property_to_animate].percentage if previous_key_value.has(property_to_animate) else 0
		var percentage = (current_frame_key - start_percentage) / 100.0
		var frame_duration = max(ANIMA.MINIMUM_DURATION, duration * percentage)
		var percentage_delay := 0.0
		var relative = relative_properties.find(property_to_animate) >= 0

		if start_percentage > 0:
			percentage_delay += (start_percentage/ 100.0) * duration

		var from_value

		if previous_key_value.has(property_to_animate):
			from_value = previous_key_value[property_to_animate].value
		else:
			from_value = AnimaNodesProperties.get_property_value(node, animation_data, property_to_animate)

		var to_value = frame_data[property_to_animate]

		#
		# To have generic animations that works with 2D and 3D Nodes
		# we always define scale as Vector3. But for 2D Nodes we can
		# only use Vector2, so in this case we have to "convert" the property
		# internally
		var node_property = AnimaNodesProperties.map_property_to_godot_property(node, property_to_animate)

		var should_convert_to_vector2: bool = not node_property.has("key") and node_property.has("property") and node_property.property in node and node[node_property.property] is Vector2
		if should_convert_to_vector2:
			if from_value is Vector3:
				from_value = Vector2(from_value.x, from_value.y)

			if to_value is Vector3:
				to_value = Vector2(to_value.x, to_value.y)

		var property_name: String = property_to_animate

		data.to = AnimaTweenUtils.maybe_calculate_value(to_value, data)

		if relative:
			if previous_key_value[property_to_animate].has("to"):
				from_value = previous_key_value[property_to_animate].to

			data.to += from_value

		data.property = property_name
		data.duration = frame_duration
		data._wait_time = wait_time + percentage_delay
		data.easing = easing
		data.from = from_value

		if property_name == "opacity" or property_name.begins_with("shader_param"):
			data.easing = null

		if animation_data.has("__debug") and (animation_data.__debug == "true" or animation_data.__debug == data.property):
			prints("\n=== FRAME", data.property, ":", data.from, " --> ", data.to, "wait time:", data._wait_time, "duration:", data.duration, "easing:", data.easing, " is relative:", str(relative))

		if previous_key_value.has(property_to_animate) and previous_key_value[property_to_animate].has("initial_value"):
			if not data.has("initial_values"):
				data.initial_values = {}

			data.initial_values[property_to_animate] = previous_key_value[property_to_animate].initial_value

			_apply_initial_values(data)

		if typeof(from_value) != typeof(data.to) or from_value != data.to:
			add_animation_data(data)
		elif animation_data.has("__debug") and (animation_data.__debug == "true" or animation_data.__debug == data.property):
			prints("\t SKIPPING, from == to", from_value, data.to)

		previous_key_value[property_to_animate] = { percentage = current_frame_key, value = frame_data[property_to_animate], to = data.to }

func get_animation_data() -> Array:
	return _animation_data

func get_animations_count() -> int:
	return _animation_data.size()

func has_data() -> bool:
	return _animation_data.size() > 0

func stop() -> void:
	_tween.stop()

func clear_animations() -> void:
	_tween.stop()
	_tween.kill()
	
	_enter_tree()

	for child in get_children():
		child.queue_free()

	_callbacks = {}
	_animation_data.clear()

func set_visibility_strategy(strategy: int) -> void:
	for animation_data in _animation_data:
		_apply_visibility_strategy(animation_data, strategy)

func set_loop_strategy(strategy: int) -> void:
	_loop_strategy = strategy

func reverse_animation(animation_data: Array, animation_length: float, default_duration: float):
	clear_animations()

	var data: Array = _flip_animations(animation_data.duplicate(true), animation_length, default_duration)

	for new_data in data:
		add_animation_data(new_data, PLAY_MODE.BACKWARDS)

#
# In order to flip "nested relative" animations we need to calculate what all the
# property as it would be if the animation is played normally. Only then we can calculate
# the correct relative positions, by also looking at the previous frames.
# Otherwise we would end up with broken animations when animating the same property more than
# once
func _flip_animations(data: Array, animation_length: float, default_duration: float) -> Array:
	var new_data := []
	var previous_frames := {}
	var length: float = animation_length

	data.reverse()
	for animation in data:
		if animation.has("_ignore_for_backwards"):
			continue

		var animation_data = animation.duplicate(true)

		var duration: float = float(animation_data.duration) if animation_data.has('duration') else default_duration
		var wait_time: float = animation_data._wait_time
		var node = animation_data.node
		var new_wait_time: float = length - duration - wait_time
		var property = animation_data.property
		var is_relative = animation_data.has("relative") and animation_data.relative

		if animation_data.has("initial_value"):
			animation_data.erase("initial_value")

		if animation_data.has("initial_values"):
			animation_data.erase("initial_values")

		if not is_relative:
			var temp = animation_data.to

			if animation_data.has("from"):
				animation_data.to = animation_data.from

			animation_data.from = temp

		animation_data._wait_time = max(ANIMA.MINIMUM_DURATION, new_wait_time)

		var old_on_completed = animation_data.on_completed if animation_data.has("on_completed") else null
		var erase_on_completed := true

		if animation_data.has("on_started"):
			animation_data.on_completed = animation_data.on_started
			animation_data.erase("on_started")

			erase_on_completed = false

		if old_on_completed:
			animation_data.on_started = old_on_completed

			if erase_on_completed:
				animation_data.erase('on_completed')

		animation_data.erase("initial_values")
		animation_data.erase("initial_value")

		new_data.push_back(animation_data)

	return new_data

func _apply_visibility_strategy(animation_data: Dictionary, strategy: int = ANIMA.VISIBILITY.IGNORE):
	if not animation_data.has('_is_first_frame'):
		return

	var should_hide_nodes := false
	var should_make_nodes_transparent := false

	if animation_data.has("visibility_strategy"):
		strategy = animation_data.visibility_strategy

	if strategy == ANIMA.VISIBILITY.HIDDEN_ONLY:
		should_hide_nodes = true
	elif strategy == ANIMA.VISIBILITY.HIDDEN_AND_TRANSPARENT:
		should_hide_nodes = true
		should_make_nodes_transparent = true
	elif strategy == ANIMA.VISIBILITY.TRANSPARENT_ONLY:
		should_make_nodes_transparent = true

	var node: Node = animation_data.node

	if should_hide_nodes:
		node.show()

	if should_make_nodes_transparent and 'modulate' in node:
		var modulate = node.modulate
		var transparent = modulate

		transparent.a = 0
		node.set_meta('_old_modulate', modulate)

		node.modulate = transparent

	node.set_meta(VISIBILITY_STRATEGY_META_KEY, strategy)


# We don't want the user to specify the from/to value as color
# we animate opacity.
# So this function converts the "from = #" -> Color(.., .., .., #)
# same for the to value
#
func _maybe_adjust_modulate_value(animation_data: Dictionary, value):
	var property = animation_data.property
	var node = animation_data.node

	if not property == 'opacity':
		return value

	if value is int or value is float:
		var color = node.modulate

		color.a = value

		return color

	return value

func _on_tween_completed() -> void:
#	node.on_completed()

	_tween_completed += 1

	if _tween_completed >= _animation_data.size():
		_tween.stop()
#		stop_all()

		emit_signal("animation_completed")

func _on_tween_started(node, _ignore) -> void:
	node.on_started()

func _on_node_tree_exiting() -> void:
	_tween.stop()

class AnimatedItem extends Node:
	var _node: Node
	var _callback: Callable
	var _callback_param
	var _property
	var _key
	var _subKey
	var _animation_data: Dictionary
	var _loop_strategy: int = ANIMA.LOOP_STRATEGY.USE_EXISTING_RELATIVE_DATA
	var _is_backwards_animation: bool = false
	var _root_node: Node
	var _property_data: Dictionary
	var _easing_curve: Curve

	func on_started() -> void:
		var visibility_strategy = _node.get_meta(VISIBILITY_STRATEGY_META_KEY) if _node.has_meta(VISIBILITY_STRATEGY_META_KEY) else null

		if _node.has_meta("_visibility_strategy_reverted") or visibility_strategy == null:
			return

		_node.set_meta("_visibility_strategy_reverted", true)

		if _animation_data.has("visibility_strategy"):
			visibility_strategy = _animation_data.visibility_strategy

		var should_restore_visibility := false
		var should_restore_modulate := false

		if visibility_strategy == ANIMA.VISIBILITY.HIDDEN_ONLY:
			should_restore_visibility = true
		elif visibility_strategy == ANIMA.VISIBILITY.HIDDEN_AND_TRANSPARENT:
			should_restore_modulate = true
			should_restore_visibility = true
		elif visibility_strategy == ANIMA.VISIBILITY.TRANSPARENT_ONLY:
			should_restore_modulate = true

		if should_restore_modulate:
			var old_modulate

			if _node.has_meta('_old_modulate'):
				old_modulate = _node.get_meta('_old_modulate')
				old_modulate.a = 1.0

			if old_modulate:
				_node.modulate = old_modulate

		if should_restore_visibility:
			_node.show()

		var should_trigger_on_started: bool = _animation_data.has('_is_first_frame') and \
												_animation_data._is_first_frame and \
												_animation_data.has('on_started')

		if should_trigger_on_started:
			_execute_callback(_animation_data.on_started)

	func on_completed() -> void:
		if _loop_strategy == ANIMA.LOOP_STRATEGY.RECALCULATE_RELATIVE_DATA:
			_property_data.clear()

		var should_trigger_on_completed = _animation_data.has('on_completed') and _animation_data.has('_is_last_frame')

		if should_trigger_on_completed:
			_execute_callback(_animation_data.on_completed)

	func set_animation_data(data: Dictionary, property_data: Dictionary, is_backwards_animation: bool) -> void:
		_animation_data = data
		_is_backwards_animation = is_backwards_animation

		if property_data.has("callback"):
			_callback = property_data.callback

		if property_data.has("param"):
			_callback_param = property_data.param

		if property_data.has("property"):
			_property = property_data.property

		if data.has("easing") and data.easing is Curve:
			_easing_curve = data.easing

		_key = property_data.key if property_data.has("key") else null
		_subKey = property_data.subkey if property_data.has("subkey") else null

		_node = data.node
		_node.remove_meta("_visibility_strategy_reverted")

		if _animation_data.has("__debug") and (_animation_data.__debug == "true" or _animation_data.__debug == _animation_data.property):
			print("Using:")
			printt("", property_data)
			printt("", "AnimatedPropertyItem:", self is AnimatedPropertyItem)
			printt("", "AnimatedPropertyWithKeyItem:", self is AnimatedPropertyWithKeyItem)
			printt("", "AnimatedPropertyWithSubKeyItem:", self is AnimatedPropertyWithSubKeyItem)
			printt("", "AnimateObjectWithKey:", self is AnimateObjectWithKey)
			printt("", "AnimateObjectWithSubKey:", self is AnimateObjectWithSubKey)
			printt("", "AnimateRect2:", self is AnimateRect2)

	func animate(elapsed: float) -> void:
		if _property_data.size() == 0:
			_property_data = AnimaTweenUtils.calculate_from_and_to(_animation_data, _is_backwards_animation)

			if _animation_data.has("__debug") and (_animation_data.__debug == "true" or _animation_data.__debug == _animation_data.property):
				printt("_property_data", _property_data)
				print("")

		var from = _property_data.from
		var diff = _property_data.diff

		var value = from + (diff * elapsed)

		apply_value(value)

	func apply_value(value) -> void:
		printerr("Please use LinearAnimatedItem or EasingAnimatedItem class intead!!!")

	func animate_with_easing(elapsed: float):
		var easing_points = _animation_data._easing_points
		var p1 = easing_points[0]
		var p2 = easing_points[1]
		var p3 = easing_points[2]
		var p4 = easing_points[3]

		var easing_elapsed = _cubic_bezier(Vector2.ZERO, Vector2(p1, p2), Vector2(p3, p4), Vector2(1, 1), elapsed)

		animate(easing_elapsed)

	func animate_with_anima_easing(elapsed: float) -> void:
		var easing_points_function = _animation_data._easing_points
		var easing_callback = Callable(AnimaEasing, easing_points_function)
		var easing_elapsed = easing_callback.call(elapsed)

		animate(easing_elapsed)

	func animate_with_easing_funcref(elapsed: float) -> void:
		var easing_callback = _animation_data._easing_points
		var easing_elapsed = easing_callback.call(elapsed)

		animate(easing_elapsed)

	func animate_with_curve(elapsed: float) -> void:
		var easing_elapsed = _easing_curve.interpolate(elapsed)

		animate(easing_elapsed)

	func animate_linear(elapsed: float) -> void:
		animate(elapsed)

	func _cubic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> float:
		var q0 := p0.lerp(p1, t)
		var q1 := p1.lerp(p2, t)
		var q2 := p2.lerp(p3, t)

		var r0 := q0.lerp(q1, t)
		var r1 := q1.lerp(q2, t)

		return r0.lerp(r1, t).y

	func _execute_callback(callback) -> void:
		var fn: Callable
		var args: Array = []

		if callback is Array:
			fn = callback[0]
			args = callback[1]

			if _is_backwards_animation:
				args = callback[2]
		else:
			fn = callback

		fn.call(args)

class AnimatedPropertyItem extends AnimatedItem:
	func apply_value(value) -> void:
		_node.set(_property, value)

class AnimatedPropertyWithKeyItem extends AnimatedItem:
	func apply_value(value) -> void:
		_node[_property][_key] = value

class AnimatedPropertyWithSubKeyItem extends AnimatedItem:
	func apply_value(value) -> void:
		_node[_property][_key][_subKey] = value

class AnimateObjectWithKey extends AnimatedItem:
	func apply_value(value) -> void:
		_property[_key] = value

class AnimateObjectWithSubKey extends AnimatedItem:
	func apply_value(value) -> void:
		_property[_key][_subKey] = value

class AnimatedCallback extends AnimatedItem:
	func apply_value(value) -> void:
		_callback

class AnimatedCallbackWithParam extends AnimatedItem:
	func apply_value(value) -> void:
		_callback.call(_callback_param, value)

class AnimateRect2 extends AnimatedItem:
	func animate(elapsed: float) -> void:
		if _property_data.size() == 0:
			_property_data = AnimaTweenUtils.calculate_from_and_to(_animation_data, _is_backwards_animation)

		apply_value(Rect2(
			_property_data.from.position + (_property_data.diff.position * elapsed),
			_property_data.from.size + (_property_data.diff.size * elapsed)
		))

	func apply_value(value: Rect2) -> void:
		_node.set(_property, value)
