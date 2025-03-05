extends CharacterBody2D

@export var chase_speed: float = 100.0
@export var detection_radius: float = 300.0
@export var charge_distance: float = 100.0  # Distance to trigger charge
@export var kill_distance: float = 30.0     # Distance at which it kills player
@export var charge_speed: float = 500.0     # Much faster when charging
@export var stop_chance: float = 0.01
@export var stop_duration: float = 1.0
@export var player1_path: NodePath  # Add this to select Player1
@export var player2_path: NodePath  # Add this to select Player2
@export var gravity: float = 980.0  # Added gravity parameter

@onready var bark_sound: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var area: Area2D = $Area2D
@onready var player1: Node2D = get_node_or_null(player1_path)  # Get Player1 reference
@onready var player2: Node2D = get_node_or_null(player2_path)  # Get Player2 reference
@onready var sprite: Sprite2D = $Sprite2D  # Add reference to the Sprite2D node
var stop_timer: float = 0.0
var is_moving: bool = true
var is_charging: bool = false
var current_player: Node2D = null

func _ready() -> void:
	# Setup bark sound
	add_child(bark_sound)
	var sound = load("res://bark.mp3")
	if sound:
		bark_sound.stream = sound
		bark_sound.volume_db = linear_to_db(0.3)
	
	# Connect Area2D signals
	if area:
		area.body_entered.connect(_on_body_entered)
		area.body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if (body == player1 or body == player2) and body.has_method("hit_water"):
		current_player = body
		if is_charging:  # If we're charging when we hit the player
			bark_sound.play()
			body.hit_water()  # Kill the player we touched

func _on_body_exited(body: Node2D) -> void:
	if body == current_player:
		current_player = null
		is_charging = false

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if !is_moving and !is_charging:
		stop_timer -= delta
		if stop_timer <= 0:
			is_moving = true
		velocity.x = 0
		move_and_slide()
		return
		
	if !is_charging and randf() < stop_chance:
		is_moving = false
		stop_timer = stop_duration
		velocity.x = 0
		move_and_slide()
		return
		
	# Find the closest active player
	var closest_player = get_closest_player()
	if closest_player:
		var distance = global_position.distance_to(closest_player.global_position)
		var player_pos = closest_player.global_position
		var height_diff = global_position.y - player_pos.y
		
		# Kill player if they're close enough
		if distance < kill_distance and is_charging:
			bark_sound.play()
			closest_player.hit_water()
			return
			
		# Start charging if player is close OR above
		if distance < charge_distance or (height_diff > 0 and height_diff < 100 and abs(player_pos.x - global_position.x) < 100):
			if !is_charging:
				bark_sound.play()
			is_charging = true
			
		chase_player(closest_player, delta)
	else:
		is_charging = false
		velocity.x = 0
	
	move_and_slide()

# New function to find closest player
func get_closest_player() -> Node2D:
	var closest_distance := INF
	var closest: Node2D = null
	
	# Check player1
	if player1 and player1.is_active:
		closest_distance = global_position.distance_to(player1.global_position)
		closest = player1
	
	# Check if player2 is closer
	if player2 and player2.is_active:
		var distance = global_position.distance_to(player2.global_position)
		if distance < closest_distance:
			closest = player2
	
	return closest

func chase_player(player: Node2D, delta: float) -> void:
	var to_player = player.global_position - global_position
	var current_speed = charge_speed if is_charging else chase_speed
	
	# If player is above, try to get directly under them first
	if to_player.y < -20:  # Player is above
		var x_diff = abs(to_player.x)
		if x_diff > 10:  # Not directly under player
			if to_player.x > 0:
				velocity.x = current_speed * 1.5  # Move faster when trying to get under player
				sprite.flip_h = false
			else:
				velocity.x = -current_speed * 1.5
				sprite.flip_h = true
		else:
			velocity.x = 0  # Stop when under player
	else:
		# Normal horizontal chase
		if to_player.x > 0:
			velocity.x = current_speed
			sprite.flip_h = false
		else:
			velocity.x = -current_speed
			sprite.flip_h = true
