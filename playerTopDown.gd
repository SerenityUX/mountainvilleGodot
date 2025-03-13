extends CharacterBody2D

const SPEED = 150.0
const PLAYER1_TEXTURE_PATH = "res://VeloSprite.png"
const ANIMATION_SPEED = 10.0

# Core references
@onready var sprite = $player
@onready var collision_shape = $CollisionShape2D
var carry_position: Node2D
var original_size = Vector2.ZERO

# Carrying mechanics
var carrying_player: CharacterBody2D = null
var is_being_carried = false
var carrier: CharacterBody2D = null

# State variables
@export var initial_position: Vector2
var is_active = true
var is_walking = false

# Sound effects
var walk_sound: AudioStreamPlayer
var grab_sound: AudioStreamPlayer
var death_sound: AudioStreamPlayer
var launch_sound: AudioStreamPlayer

# Animation variables
var animation_timer = 0.0
var current_frame = 0

# Compatibility signal
signal physics_process(player: CharacterBody2D)

func _ready():
	# Set up groups
	add_to_group("players")
	if name == "Player":
		add_to_group("player1")
	
	# Load texture
	var texture = load(PLAYER1_TEXTURE_PATH)
	if texture:
		sprite.texture = texture
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.hframes = 4
		sprite.frame = 0
	
	# Create carry position
	carry_position = Node2D.new()
	carry_position.name = "CarryPosition"
	add_child(carry_position)
	carry_position.position = Vector2(0, -13)
	
	# Store initial values
	if collision_shape and collision_shape.shape:
		original_size = collision_shape.shape.size
	initial_position = global_position

	# Set up sounds
	setup_sounds()

func setup_sounds():
	# Walking sound
	walk_sound = AudioStreamPlayer.new()
	add_child(walk_sound)
	var sound = load("res://walk.mp3")
	if sound:
		walk_sound.stream = sound
		walk_sound.volume_db = linear_to_db(0.3)

	# Grab sound
	grab_sound = AudioStreamPlayer.new()
	add_child(grab_sound)
	var grab_audio = load("res://grab.mp3")
	if grab_audio:
		grab_sound.stream = grab_audio
		grab_sound.volume_db = linear_to_db(0.3)

	# Death sound
	death_sound = AudioStreamPlayer.new()
	add_child(death_sound)
	var death_audio = load("res://death.mp3")
	if death_audio:
		death_sound.stream = death_audio
		death_sound.volume_db = linear_to_db(0.3)

	# Launch sound
	launch_sound = AudioStreamPlayer.new()
	add_child(launch_sound)
	var launch_audio = load("res://launch.mp3")
	if launch_audio:
		launch_sound.stream = launch_audio
		launch_sound.volume_db = linear_to_db(0.3)

func _physics_process(delta):
	if !is_active:
		return
		
	physics_process.emit(self)

	if is_being_carried:
		handle_being_carried()
		return
	
	handle_pickup()
	update_carrying()
	handle_movement(delta)
	
	move_and_slide()

func handle_being_carried():
	if Input.is_action_just_pressed("w") or Input.is_action_just_pressed("a") or Input.is_action_just_pressed("s") or Input.is_action_just_pressed("d"):
		var carrier_velocity = carrier.velocity
		stop_being_carried()
		launch_sound.play()
		velocity = carrier_velocity * 2.0

func handle_pickup():
	if Input.is_action_just_pressed("e") and !carrying_player:
		var players = get_tree().get_nodes_in_group("players")
		for player in players:
			if player != self and player.is_active:
				var distance = global_position.distance_to(player.global_position)
				if distance < 75:
					carrying_player = player
					player.call_deferred("being_carried_by", self)
					grab_sound.play()
					
					if collision_shape and collision_shape.shape:
						var current_size = collision_shape.shape.size
						collision_shape.shape.size = Vector2(current_size.x, current_size.y * 2)
						collision_shape.position.y = -current_size.y / 2
					break

func update_carrying():
	if carrying_player:
		carrying_player.global_position = carry_position.global_position
		carrying_player.velocity = velocity

func handle_movement(delta):
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("w"):
		direction.y -= 1
	if Input.is_action_pressed("s"):
		direction.y += 1
	if Input.is_action_pressed("a"):
		direction.x -= 1
	if Input.is_action_pressed("d"):
		direction.x += 1
	
	if direction.length() > 0:
		direction = direction.normalized()
		velocity = direction * SPEED
		is_walking = true
		
		if direction.x != 0:
			sprite.flip_h = direction.x > 0
			
		animation_timer += delta * ANIMATION_SPEED
		if animation_timer >= 1.0:
			animation_timer = 0.0
			current_frame = (current_frame + 1) % 4
			sprite.frame = current_frame
			
		if !walk_sound.playing:
			walk_sound.play()
	else:
		velocity = Vector2.ZERO
		is_walking = false
		current_frame = 0
		sprite.frame = 0
		animation_timer = 0.0
		walk_sound.stop()

func get_momentum():
	return velocity.length()

func hit_water():
	death_sound.play()
	global_position = initial_position
	velocity = Vector2.ZERO
	get_tree().call_group("players", "force_respawn")

func force_respawn():
	global_position = initial_position
	velocity = Vector2.ZERO

func hit_door():
	is_active = false
	get_tree().call_group("rope", "break_connection")
	set_collision_layer_value(1, false)
	set_collision_layer_value(2, false)
	set_collision_mask_value(1, false)
	set_collision_mask_value(2, false)
	call_deferred("complete_door_hit")

func complete_door_hit():
	set_physics_process(false)
	hide()
	get_node("/root/Root").player_finished()

func stop_carrying():
	if carrying_player:
		if collision_shape and collision_shape.shape:
			collision_shape.shape.size = original_size
			collision_shape.position.y = 0
		carrying_player.velocity = velocity * 2.0
		carrying_player.stop_being_carried()
		carrying_player = null

func being_carried_by(new_carrier):
	is_being_carried = true
	carrier = new_carrier
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	velocity = Vector2.ZERO

func stop_being_carried():
	if carrier:
		var temp_carrier = carrier
		carrier = null
		is_being_carried = false
		set_collision_layer_value(1, true)
		set_collision_mask_value(1, true)
		temp_carrier.stop_carrying()

func transport():
	velocity = Vector2.ZERO
	stop_carrying()
	stop_being_carried()
	
	if collision_shape and collision_shape.shape:
		collision_shape.shape.size = original_size
		collision_shape.position.y = 0

func is_involved_in_carrying():
	return is_being_carried or carrying_player != null 
