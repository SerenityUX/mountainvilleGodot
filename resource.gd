extends Area2D

# Add reference to Root instead of GameManager
@onready var game_manager = get_tree().root.get_node("Root")

# Updated to include both level 1 and level 2 ingredients
const VALID_INGREDIENTS = ["corn", "tomato", "onion", "peppers", "garlic", "water", "oil", "flour"]
@export var resource_name: String = "corn":
	set(value):
		# Validate the ingredient name (case-insensitive)
		var lowercase_value = value.to_lower()
		if lowercase_value in VALID_INGREDIENTS:
			resource_name = lowercase_value  # Store as lowercase
		else:
			push_warning("Invalid ingredient name: %s. Must be one of: %s" % [value, VALID_INGREDIENTS])
			resource_name = "corn"  # Default to corn if invalid

var eat_sound: AudioStreamPlayer
var is_collected := false  # Track if resource has been collected

func _ready() -> void:
	print("Resource: Setting up collect sound...")
	# Setup collect sound
	eat_sound = AudioStreamPlayer.new()
	add_child(eat_sound)
	
	# Load and verify sound
	var sound = load("res://eat.mp3")
	if sound:
		print("Resource: Successfully loaded eat.mp3")
		eat_sound.stream = sound
		eat_sound.volume_db = linear_to_db(0.5)  # Increased volume for better audibility
	else:
		push_error("Resource: Failed to load eat.mp3! Make sure the file exists in the res:// directory")
		return  # Exit if sound couldn't be loaded
	
	# Test play the sound
	eat_sound.play()
	print("Resource: Testing sound playback")
	
	# Connect the body entered signal
	body_entered.connect(_on_body_entered)
	print("Resource: Setup complete for ", resource_name)

func _on_body_entered(body: Node2D) -> void:
	# Prevent multiple collections
	if is_collected:
		return
		
	print("Resource: Body entered - ", body.name)
	if body.is_in_group("players"):
		is_collected = true  # Mark as collected immediately
		
		print("Resource: Player detected, attempting to play sound...")
		# Play sound
		if eat_sound and eat_sound.stream:
			eat_sound.play()
			print("Resource: Sound playing...")
			
			# Hide the sprite but keep the node alive for sound
			if has_node("Sprite2D"):
				get_node("Sprite2D").hide()
			
			# Disable collision using deferred calls
			set_deferred("monitoring", false)
			set_deferred("monitorable", false)
			
			# Add to inventory using game manager
			if game_manager:
				game_manager.add_to_inventory(resource_name)
				
				# Check if all ingredient types have been collected
				var has_all_ingredients = true
				for ingredient in VALID_INGREDIENTS:
					if not game_manager.inventory.has(ingredient):
						has_all_ingredients = false
						break
				
				# Only transport if we have all ingredient types
				if has_all_ingredients:
					# Get all players and transport them
					var players = get_tree().get_nodes_in_group("players")
					for player in players:
						if player.has_method("hit_door"):
							# First stop any carrying interactions
							if player.has_method("stop_carrying"):
								player.stop_carrying()
							if player.has_method("stop_being_carried"):
								player.stop_being_carried()
							# Then handle the door hit
							player.hit_door()
			else:
				push_warning("Root not found! Make sure the game manager node exists.")
			
			# Make sure we wait long enough for the sound
			await get_tree().create_timer(0.5).timeout
			
			# Now remove the resource
			queue_free()
		else:
			push_warning("Resource: Sound not properly setup!") 
