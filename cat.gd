extends Area2D

@onready var sprite_node: Sprite2D = $Sprite2D
@onready var collision_shape_node: CollisionShape2D = $CollisionShape2D
var initial_position: Vector2
var target_position: Vector2
const MOVE_DISTANCE := 15.0  # Shorter movement distance for the cat
const MOVE_DURATION := 3.0  # Time in seconds to complete the movement
const INITIAL_DELAY := 1.0  # Wait time before moving
var move_time := 0.0
var delay_time := 0.0
var is_moving := true
var is_waiting := true
var player_in_range := false
var current_player: Node2D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if sprite_node:
		initial_position = sprite_node.position
		target_position = sprite_node.position - Vector2(MOVE_DISTANCE, 0)

func _process(delta: float) -> void:
	if is_waiting:
		delay_time += delta
		if delay_time >= INITIAL_DELAY:
			is_waiting = false
		return
		
	if is_moving and sprite_node and collision_shape_node:
		move_time += delta
		var progress = move_time / MOVE_DURATION
		
		if progress >= 1.0:
			sprite_node.position = target_position
			collision_shape_node.position = target_position
			is_moving = false
		else:
			var eased_progress = ease_in_out(progress)
			var new_pos = initial_position.lerp(target_position, eased_progress)
			sprite_node.position = new_pos
			collision_shape_node.position = new_pos
	
	# Check for spacebar input when player is in range
	if player_in_range and Input.is_action_just_pressed("ui_accept"):  # Spacebar
		if current_player and current_player.has_method("stop_carrying"):
			current_player.stop_carrying()
		if current_player and current_player.has_method("stop_being_carried"):
			current_player.stop_being_carried()
			
		# Get game manager and change to CatDialogue scene
		var game_manager = get_node("/root/Root")
		if game_manager and game_manager.has_method("change_to_dialogue"):
			game_manager.change_to_dialogue("CatDialogue")  # Changed to match exact scene name

# Custom ease in-out function
func ease_in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

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
