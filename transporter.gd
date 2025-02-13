extends Area2D

@onready var sprite_node: Sprite2D = $Sprite2D
@onready var collision_shape_node: CollisionShape2D = $CollisionShape2D
var initial_position: Vector2
var target_position: Vector2
const MOVE_DISTANCE := 30.0
const MOVE_DURATION := 5.0  # Time in seconds to complete the movement
const INITIAL_DELAY := 1.0  # Wait time before moving
const ZOOM_IN_AMOUNT := Vector2(3.0, 3.0)  # How much to zoom in (smaller numbers = more zoom)
const CAMERA_OFFSET := Vector2(-120, -40.0)  # Offset to the right
var move_time := 0.0
var delay_time := 0.0
var is_moving := true
var is_waiting := true
var walk_sound: AudioStreamPlayer
var camera: Camera2D
var original_camera_state := {
	"position": Vector2.ZERO,
	"zoom": Vector2.ONE
}

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	print("Transporter ready!")  # Debug print
	
	# Get and store camera's initial state
	camera = get_tree().root.get_node("Level 0/Camera2D")
	if camera:
		# Store the exact state of the camera
		original_camera_state.position = camera.global_position
		original_camera_state.zoom = camera.zoom
		print("Stored camera position:", original_camera_state.position)  # Debug print
	
	if sprite_node:
		initial_position = sprite_node.position
		target_position = sprite_node.position - Vector2(MOVE_DISTANCE, 0)

func _process(delta: float) -> void:
	if is_waiting:
		delay_time += delta
		if delay_time >= INITIAL_DELAY:
			is_waiting = false
			# Setup walk sound when we start moving
			walk_sound = AudioStreamPlayer.new()
			add_child(walk_sound)
			var audio = load("res://walk.mp3")
			if audio:
				walk_sound.stream = audio
				walk_sound.volume_db = linear_to_db(0.3)
				walk_sound.play()
			# Start zooming in and move camera
			if camera:
				var tween = create_tween()
				tween.set_parallel(true)
				tween.tween_property(camera, "zoom", ZOOM_IN_AMOUNT, MOVE_DURATION/2).set_trans(Tween.TRANS_SINE)
				tween.tween_property(camera, "global_position", global_position + CAMERA_OFFSET, MOVE_DURATION/2).set_trans(Tween.TRANS_SINE)
		return
		
	if is_moving and sprite_node and collision_shape_node:
		move_time += delta
		var progress = move_time / MOVE_DURATION
		
		if progress >= 1.0:
			sprite_node.position = target_position
			collision_shape_node.position = target_position
			is_moving = false
			if walk_sound and walk_sound.playing:
				walk_sound.stop()
			# Zoom back out and reset camera position to original values
			if camera:
				print("Restoring camera to:", original_camera_state.position)  # Debug print
				var tween = create_tween()
				tween.set_parallel(true)
				tween.tween_property(camera, "zoom", original_camera_state.zoom, MOVE_DURATION/2).set_trans(Tween.TRANS_SINE)
				tween.tween_property(camera, "global_position", original_camera_state.position, MOVE_DURATION/2).set_trans(Tween.TRANS_SINE)
		else:
			var eased_progress = ease_in_out(progress)
			var new_pos = initial_position.lerp(target_position, eased_progress)
			sprite_node.position = new_pos
			collision_shape_node.position = new_pos

# Custom ease in-out function
func ease_in_out(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)

func _on_body_entered(body: Node2D) -> void:
	print("Body entered:", body.name)  # Debug print
	# Check if the body's path contains Player1 or Player2
	var path = body.get_path()
	print("Body path:", path)  # Debug print
	
	if "Player1" in body.name or "Player2" in body.name:
		print("Player entered transporter!")  # Debug print
		# First stop any carrying interactions
		if body.has_method("stop_carrying"):
			body.stop_carrying()
		if body.has_method("stop_being_carried"):
			body.stop_being_carried()
		
		# Get game manager (using Root instead of GameManager)
		var game_manager = get_node("/root/Root")
		if game_manager:
			print("Found game manager")  # Debug print
			game_manager.change_level(1)
		else:
			print("No game manager found!")  # Debug print
