extends Node

# =============================================================================
# HOW TO USE THIS SCRIPT:
# =============================================================================
# 1. Attach this script to a Node in your scene
# 2. In the Inspector, assign a Sprite2D to the "background_sprite" property
# 3. Optional: Enable "test_door" to automatically test door opening
#
# EXAMPLE - Calling from another script:
#
# func _on_player_interact():
#     # Get reference to the door controller
#     var door_controller = get_node("../DoorController")
#     
#     # Call the open_door function
#     door_controller.open_door()
#
# SETUP EXAMPLE:
# - Create a Node named "DoorController"
# - Attach this script to that Node
# - Add a Sprite2D with your CurryHouse.png texture
# - Drag the Sprite2D into the background_sprite property in the Inspector
# =============================================================================

# Exported variables that can be set in the Inspector
@export var background_sprite: Sprite2D
@export var test_door: bool = false
@export var door_open_duration: float = 2.0
@export var test_door_interval: float = 5.0

# Preload textures and audio
var closed_door_texture = preload("res://CurryHouse.png")
var open_door_texture = preload("res://CurryHouse-openDoor.png")
var door_sound = preload("res://openDoorSound.mp3")

# Timer for closing the door and testing
var door_timer: Timer
var test_timer: Timer
var audio_player: AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Setup audio player
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.stream = door_sound
	
	# Setup door timer
	door_timer = Timer.new()
	door_timer.one_shot = true
	door_timer.wait_time = door_open_duration
	door_timer.timeout.connect(_on_door_timer_timeout)
	add_child(door_timer)
	
	# Setup test timer if needed
	if test_door:
		test_timer = Timer.new()
		test_timer.wait_time = test_door_interval
		test_timer.timeout.connect(_on_test_timer_timeout)
		add_child(test_timer)
		test_timer.start()
	
	# Set default texture if sprite is assigned
	if background_sprite:
		background_sprite.texture = closed_door_texture

# Opens the door, plays sound, and starts the timer to close it
func open_door() -> void:
	if not background_sprite:
		push_error("BackgroundSprite is not assigned to DoorController")
		return
	
	# Change texture to open door
	background_sprite.texture = open_door_texture
	
	# Play sound
	audio_player.play()
	
	# Start timer to close door
	door_timer.start()

# Called when the door timer expires - close the door
func _on_door_timer_timeout() -> void:
	if background_sprite:
		background_sprite.texture = closed_door_texture

# Called when the test timer expires - open the door for testing
func _on_test_timer_timeout() -> void:
	open_door()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
