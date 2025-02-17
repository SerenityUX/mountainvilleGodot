extends Node

const MIN_X := 0.0  # Left boundary
const MAX_X := 1000.0   # Right boundary

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get all players when the scene starts
	var players = get_tree().get_nodes_in_group("players")
	# Connect to their physics process
	for player in players:
		if not player.is_connected("physics_process", Callable(self, "_enforce_boundary")):
			player.connect("physics_process", Callable(self, "_enforce_boundary"))

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

# Called by the players' physics process
func _enforce_boundary(player: CharacterBody2D) -> void:
	if player.global_position.x < MIN_X:
		player.global_position.x = MIN_X
		player.velocity.x = 0
	elif player.global_position.x > MAX_X:
		player.global_position.x = MAX_X
		player.velocity.x = 0
