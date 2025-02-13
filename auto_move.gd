extends Sprite2D

@export var speed: float = 100.0  # Base movement speed in pixels per second
@export var panic_speed: float = 200.0  # Speed when running from players
@export var stop_chance: float = 0.03  # Chance to stop and rest
@export var detection_radius: float = 200.0  # How far it can "see" players

var is_moving: bool = true
var stop_timer: float = 0.0
var current_speed: float = 0.0
var flip_timer: float = 0.0

func _ready() -> void:
	# Start with random direction
	flip_h = randf() < 0.5
	_reset_flip_timer()

func _reset_flip_timer() -> void:
	flip_timer = randf_range(5.0, 20.0)

func _get_nearest_players() -> Array:
	var players = []
	var player1 = get_tree().get_first_node_in_group("Player1")
	var player2 = get_tree().get_first_node_in_group("Player2")
	
	if player1 and global_position.distance_to(player1.global_position) < detection_radius:
		players.append(player1)
	if player2 and global_position.distance_to(player2.global_position) < detection_radius:
		players.append(player2)
	
	return players

func _get_escape_direction(players: Array) -> float:
	if players.is_empty():
		return -1.0 if flip_h else 1.0
	
	# Calculate average position if multiple players
	var avg_player_pos = Vector2.ZERO
	for player in players:
		avg_player_pos += player.global_position
	avg_player_pos /= players.size()
	
	# Get direction away from players
	var away_dir = (global_position - avg_player_pos).normalized()
	# Return 1 or -1 based on which direction we should run
	return sign(away_dir.x)

func _process(delta: float) -> void:
	var nearby_players = _get_nearest_players()
	var is_panicked = !nearby_players.is_empty()
	
	# Only use normal flip timer when not panicked
	if !is_panicked:
		flip_timer -= delta
		if flip_timer <= 0:
			flip_h = !flip_h
			_reset_flip_timer()
	else:
		# When panicked, face away from threat
		var escape_dir = _get_escape_direction(nearby_players)
		flip_h = escape_dir < 0
	
	# Handle stopping and starting (only when not panicked)
	if !is_panicked:
		if is_moving:
			if randf() < stop_chance:
				is_moving = false
				stop_timer = randf_range(1.0, 2.0)
				current_speed = 0.0
		else:
			stop_timer -= delta
			if stop_timer <= 0:
				is_moving = true
	else:
		is_moving = true  # Always move when panicked
	
	# If moving, update speed and position
	if is_moving:
		var target_speed = panic_speed if is_panicked else speed
		current_speed = lerp(current_speed, target_speed, 0.1)
		
		# Only limp when not panicked
		if !is_panicked and randf() < 0.1:
			current_speed *= 0.5
		
		# Get movement direction
		var direction = _get_escape_direction(nearby_players)
		position.x += direction * current_speed * delta
		
		# Only add limping motion when not panicked
		if !is_panicked:
			position.y += sin(Time.get_ticks_msec() * 0.01) * delta * 2.0 