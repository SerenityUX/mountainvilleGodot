extends Area2D

var player_in_range := false
var current_player: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	# Check for spacebar input when player is in range
	if player_in_range and Input.is_action_just_pressed("ui_accept"):  # Spacebar
		if current_player:
			# First stop any carrying interactions
			if current_player.has_method("stop_carrying"):
				current_player.stop_carrying()
			if current_player.has_method("stop_being_carried"):
				current_player.stop_being_carried()
			
			# Get game manager and change to map navigation
			var game_manager = get_node("/root/Root")
			if game_manager:
				game_manager.load_map_navigation()

func _on_body_entered(body: Node2D) -> void:
	# Check if the body is either Player1 or Player2
	if "Player1" in body.name or "Player2" in body.name:
		player_in_range = true
		current_player = body

func _on_body_exited(body: Node2D) -> void:
	# Check if the leaving body is the current player
	if body == current_player:
		player_in_range = false
		current_player = null 
