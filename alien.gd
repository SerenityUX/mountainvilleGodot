extends Area2D

@onready var sprite_node: Sprite2D = $Sprite2D
@onready var collision_shape_node: CollisionShape2D = $CollisionShape2D
var initial_position: Vector2
var target_position: Vector2
const MOVE_DISTANCE := 120.0  # Tripled from 40 to 120 for much longer movement
const MOVE_DURATION := 2.0  # Faster movement speed
const INITIAL_DELAY := 1.0  # Wait time before moving
const PACE_DISTANCE := 3.0  # Reduced from 10 to 3 for subtler side-to-side movement
const PACE_SPEED := 5.0  # Speed of pacing
const JUMP_HEIGHT := 4.0  # Height of angry jumps
const HAPPY_MOVE_SPEED := 50.0  # Slower, happy movement speed
var move_time := 0.0
var delay_time := 0.0
var pace_time := 0.0
var is_moving := true
var is_waiting := true
var is_pacing := false
var is_happy := false
var player_in_range := false
var current_player: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if sprite_node:
		initial_position = sprite_node.position
		target_position = sprite_node.position + Vector2(MOVE_DISTANCE, 0)

func _process(delta: float) -> void:
	if is_waiting:
		delay_time += delta
		if delay_time >= INITIAL_DELAY:
			is_waiting = false
		return
	
	if is_happy:
		# Happy exit movement
		sprite_node.flip_h = true
		sprite_node.position.x -= HAPPY_MOVE_SPEED * delta
		collision_shape_node.position.x -= HAPPY_MOVE_SPEED * delta
		
		# Smoothly return to ground level if needed
		if sprite_node.position.y != initial_position.y:
			var y_diff = initial_position.y - sprite_node.position.y
			sprite_node.position.y += y_diff * delta * 5.0  # Adjust speed as needed
			collision_shape_node.position.y = sprite_node.position.y
		
		# Remove when off screen
		if sprite_node.position.x < -100:
			queue_free()
		return
		
	if is_moving and sprite_node and collision_shape_node:
		move_time += delta
		var progress = move_time / MOVE_DURATION
		
		if progress >= 1.0:
			sprite_node.position = target_position
			collision_shape_node.position = target_position
			is_moving = false
			is_pacing = true
		else:
			var eased_progress = ease_in_out(progress)
			var new_pos = initial_position.lerp(target_position, eased_progress)
			sprite_node.position = new_pos
			collision_shape_node.position = new_pos
	
	# Anxious pacing behavior
	if is_pacing and sprite_node and collision_shape_node:
		pace_time += delta * PACE_SPEED
		
		# Calculate side-to-side movement
		var side_movement = sin(pace_time) * PACE_DISTANCE
		# Calculate up-down movement (faster, smaller bounces)
		var vertical_movement = abs(sin(pace_time * 2.0)) * JUMP_HEIGHT
		
		var pace_position = target_position + Vector2(side_movement, -vertical_movement)
		sprite_node.position = pace_position
		collision_shape_node.position = pace_position
	
	# Check for spacebar input when player is in range
	if player_in_range and Input.is_action_just_pressed("ui_accept"):
		var game_manager = get_node("/root/Root")
		if game_manager:
			# Check if player has basic curry
			if "basic_curry" in game_manager.curry_inventory:
				# Remove curry from inventory with visual update
				game_manager.remove_curry_from_inventory("basic_curry")
				# Start happy exit animation
				is_happy = true
				is_pacing = false
				is_moving = false
				return

func ease_in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

func _on_body_entered(body: Node2D) -> void:
	if "Player1" in body.name or "Player2" in body.name:
		player_in_range = true
		current_player = body

func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		player_in_range = false
		current_player = null 