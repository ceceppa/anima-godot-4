class_name AnimaDeclarationForAnimation
extends AnimaDeclarationBase

# We can't use _init otherwise Godot complains with this nonsense
# Too few arguments for "_init()". Expected at least 1
func _init_me(data: Dictionary) -> AnimaDeclarationForAnimation:
	super._init_me(data)

	return self

func anima_delay(value: float) -> AnimaDeclarationForAnimation:
	super.anima_delay(value)

	return self

func anima_visibility_strategy(value: int) -> AnimaDeclarationForAnimation:
	super.anima_visibility_strategy(value)

	return self

func anima_on_started(on_started: Callable, on_started_value, on_backwards_completed_value = null) -> AnimaDeclarationForAnimation:
	self.anima_on_started(on_started, on_started_value, on_backwards_completed_value)

	return self

func anima_on_completed(on_completed: Callable, on_completed_value, on_backwards_started_value = null) -> AnimaDeclarationForAnimation:
	self.anima_on_completed(on_completed, on_completed_value, on_backwards_started_value)

	return self
