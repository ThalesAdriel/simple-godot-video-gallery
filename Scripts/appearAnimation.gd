extends Node
class_name AppearAnimation

func animateButtons(buttons : Array, forward : bool = true, delayBetweenButtons : float = 0.16, moveOffset : Vector2 = Vector2(-20, 0), scaleOffset : Vector2 = Vector2.ZERO, animationLength : float = 0.5) -> void:
	if !forward:
		buttons.reverse()

	for btn in buttons:
		btn.modulate.a = 0.0 if forward else 1.0
		btn.pivot_offset.y = btn.size.y / 2.0
		btn.scale = scaleOffset if forward else Vector2.ONE

	for i in buttons.size():
		var tweenEase : int = Tween.EASE_OUT if forward else Tween.EASE_IN
		var posTween : Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(tweenEase)
		var modulateTween : Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(tweenEase)
		var scaleTween : Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(tweenEase)
		var targetPos : Vector2 = buttons[i].position - moveOffset if forward else buttons[i].position + moveOffset
		var targetModulate : float = 1.0 if forward else 0.0
		var targetScale : Vector2 = Vector2.ONE if forward else scaleOffset

		posTween.tween_property(buttons[i], "position", targetPos, animationLength)
		modulateTween.tween_property(buttons[i], "modulate:a", targetModulate, animationLength)
		scaleTween.tween_property(buttons[i], "scale", targetScale, animationLength)

		await get_tree().create_timer(delayBetweenButtons).timeout

func buttonsArraySorting(a : Button, b : Button) -> bool:
	if a.global_position.y == b.global_position.y:
		return a.global_position.x < b.global_position.x
	return a.global_position.y < b.global_position.y

func getAllButtons(node : Node) -> Array:
	var buttons : Array = []
	for child in node.get_children():
		if child is Button:
			buttons.append(child)
		if child.get_child_count() > 0:
			buttons += getAllButtons(child)
	return buttons
