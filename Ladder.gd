extends Area2D

class_name Ladder

const CLIMB_SPEED = 200.0

# List of players currently on the ladder
var players_on_ladder: Array[CharacterBody2D] = []

func _ready() -> void:
	# Connect area signals
	connect("body_entered", _on_body_entered)
	connect("body_exited", _on_body_exited)
	
	# Add "s" input action if it doesn't exist
	if not InputMap.has_action("s"):
		InputMap.add_action("s")
		var event = InputEventKey.new()
		event.keycode = KEY_S
		InputMap.action_add_event("s", event)

func _on_body_entered(body: Node2D) -> void:
	# Check if the entering body is a player
	if body is CharacterBody2D and body.is_in_group("players"):
		players_on_ladder.append(body)
		# Connect to player's physics_process signal to override movement
		body.physics_process.connect(_handle_player_on_ladder)

func _on_body_exited(body: Node2D) -> void:
	# Check if the exiting body is a player
	if body is CharacterBody2D and body.is_in_group("players"):
		# Disconnect from player's physics signal
		if body.physics_process.is_connected(_handle_player_on_ladder):
			body.physics_process.disconnect(_handle_player_on_ladder)
		# Remove from tracking array
		players_on_ladder.erase(body)

func _handle_player_on_ladder(player: CharacterBody2D) -> void:
	# If player is being carried or carrying someone, don't handle ladder physics
	if player.is_involved_in_carrying():
		return
		
	# Determine which input to check based on player
	var up_action = "w" if player.name == "Player1" else "ui_up"
	
	# Apply ladder climbing
	if Input.is_action_pressed(up_action):
		# Override gravity and move the player up
		player.velocity.y = -CLIMB_SPEED
		# Reset jumps so player can jump after climbing
		player.jumps_remaining = player.MAX_JUMPS
	elif Input.is_action_pressed("s" if player.name == "Player1" else "ui_down"):
		# Allow climbing down
		player.velocity.y = CLIMB_SPEED
	else:
		# When not actively climbing, slow descent but don't stop completely
		player.velocity.y = 50.0 