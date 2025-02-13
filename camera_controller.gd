extends Camera2D

@export var min_zoom: float = 1.3  # Maximum zoom in
@export var max_zoom: float = 1.8  # Maximum zoom out
@export var zoom_speed: float = 0.1  # How quickly the camera zooms
@export var margin: float = 100.0  # Padding around players in pixels

var player1: Node2D
var player2: Node2D
var timer_label: Label

func _ready() -> void:
	# Find players in the Players node
	var level = get_parent()  # The level scene
	player1 = level.get_node("Players/Player1")
	player2 = level.get_node("Players/Player2")
	
	if player1 and player2:
		print("Found both players!")
	else:
		print("Failed to find players!")
		print("Player1: ", player1)
		print("Player2: ", player2)
	
	# Setup timer label if we're in level 1
	if level.name == "Level 1":
		setup_timer_label()

func setup_timer_label() -> void:
	# Create a new Label node
	timer_label = Label.new()
	timer_label.name = "TimerLabel"
	add_child(timer_label)
	
	# Position it in the top-center of the screen
	timer_label.position = Vector2(-50, -280)  # Adjust these values as needed
	timer_label.size = Vector2(100, 30)
	
	# Style the label
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	
	# Create the Timer node
	var timer = Timer.new()
	timer.name = "GameTimer"
	add_child(timer)

func _process(_delta: float) -> void:
	if !player1 or !player2:
		# Try to find players again if we lost them
		var level = get_parent()
		player1 = level.get_node("Players/Player1")
		player2 = level.get_node("Players/Player2")
		return
	
	# Set position to midpoint between players
	global_position = (player1.global_position + player2.global_position) / 2
	
	# Calculate distance between players
	var distance = player1.global_position.distance_to(player2.global_position)
	
	# Calculate target zoom based on distance
	var target_zoom = clamp(distance / 500.0, min_zoom, max_zoom)
	
	# Smoothly adjust zoom
	zoom = zoom.lerp(Vector2(target_zoom, target_zoom), zoom_speed)
