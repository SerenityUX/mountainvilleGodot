extends Area2D

@export var fruit_name: String = "apple"  # Default to apple, can be changed in editor
var eat_sound: AudioStreamPlayer

func _ready() -> void:
	print("Fruit: Setting up eat sound...")
	# Setup eat sound
	eat_sound = AudioStreamPlayer.new()
	add_child(eat_sound)
	var sound = load("res://eat.mp3")
	if sound:
		print("Fruit: Successfully loaded eat.mp3")
		eat_sound.stream = sound
		eat_sound.volume_db = linear_to_db(0.3)  # Adjust volume as needed
	else:
		push_error("Fruit: Failed to load eat.mp3! Make sure the file exists in the res:// directory")
	
	# Connect the body entered signal
	body_entered.connect(_on_body_entered)
	print("Fruit: Setup complete for ", fruit_name)

func _on_body_entered(body: Node2D) -> void:
	print("Fruit: Body entered - ", body.name)
	if body.is_in_group("players"):
		print("Fruit: Player detected, playing sound...")
		# Play sound
		if eat_sound and eat_sound.stream:
			eat_sound.play()
			print("Fruit: Sound playing...")
			
			# Hide the fruit sprite but keep the node alive for sound
			if has_node("Sprite2D"):
				get_node("Sprite2D").hide()
			
			# Disable collision
			monitoring = false
			monitorable = false
			
			# Add to inventory
			if Engine.has_singleton("GameManager"):
				var game_manager = Engine.get_singleton("GameManager")
				game_manager.inventory.append(fruit_name)
				print("Added ", fruit_name, " to inventory. Current inventory: ", game_manager.inventory)
			else:
				push_warning("GameManager not found! Make sure it's set up as an Autoload in Project Settings.")
			
			# Wait for sound to finish playing
			await eat_sound.finished
			
			# Now remove the fruit
			queue_free()
		else:
			push_warning("Fruit: Sound not properly setup!")
