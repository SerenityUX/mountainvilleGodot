extends Node2D

# This script demonstrates how to use the PopInEffect

func _ready():
	# Example of triggering pop-in effects with different delays
	for i in range(5):
		var sprite = $Sprites.get_child(i)
		if sprite and sprite.has_node("PopInEffect"):
			var effect = sprite.get_node("PopInEffect")
			# Override delay to create a sequential effect
			effect.play_custom(i * 0.2)

# Button press handler (for demonstration)
func _on_replay_button_pressed():
	# Reset and replay all pop-in effects
	for sprite in $Sprites.get_children():
		if sprite.has_node("PopInEffect"):
			var effect = sprite.get_node("PopInEffect")
			effect.reset()
			effect.play_custom(sprite.get_index() * 0.2) 