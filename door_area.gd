extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("hit_door"):
		# First stop any carrying interactions
		if body.has_method("stop_carrying"):
			body.stop_carrying()
		if body.has_method("stop_being_carried"):
			body.stop_being_carried()
		# Then handle the door hit
		body.hit_door() 
