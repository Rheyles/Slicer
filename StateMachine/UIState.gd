extends Control
class_name UIState

func enter_state() -> void:
	GAME.button_clicked = false
	disable_buttons(self, true)
	$AnimationPlayer.play("tween_in")
	set_visible(true)
	await $AnimationPlayer.animation_finished
	disable_buttons(self, false)
	
func exit_state() -> void:
	disable_buttons(self, true)
	$AnimationPlayer.play("tween_out")
	await $AnimationPlayer.animation_finished
	set_visible(false)
	GAME.button_clicked = false

func disable_buttons(from: Node, value: bool) -> void:
	for child in from.get_children():
		if child.get_child_count() > 0:
			disable_buttons(child, value)
		if child is Button or child is TextureButton:
			child.disabled = value
		
