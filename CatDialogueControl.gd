extends Node

@onready var bottom_text = $"../FirstMessage/BottomText"  # Reference to the BottomText label
@onready var top_text = $"../FirstMessage/TopText"  # Reference to the TopText node
@onready var first_message = $"../FirstMessage"
@onready var second_message = $"../SecondMessage"
@onready var cat_sprite = $"../Cat"  # Add reference to the Cat sprite
const CHAR_DELAY = 0.1  # 100ms delay between characters
const SHAKE_AMOUNT = 1.0  # How many pixels to shake
const SHAKE_SPEED = 20.0  # How fast to shake

var dialogue_lines = [
	"HELLO THERE IS A DIALOGUE IN\nWEIRD CHARACTERS THAT MEAN"  # Single string with \n for line break
]

var current_line = 0
var current_text = ""
var current_char_index = 0
var time_since_last_char = 0.0
var is_line_finished = false
var original_positions = {}  # Dictionary to store original positions of all children
var shake_time = 0.0
var is_second_message_animating = false

# Array of letters to use
const LETTERS = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]

func _ready() -> void:
	if bottom_text and top_text:
		bottom_text.text = ""  # Clear initial text
		# Store original positions of all children
		for child in top_text.get_children():
			original_positions[child] = child.position
		# Generate random letter lines with line break
		dialogue_lines = [
			generate_random_line(25) + "\n" + generate_random_line(20)  # Two lines with a line break
		]
		# Hide SecondMessage's children initially
		if second_message:
			set_node_visibility_recursive(second_message, false)
		# Set initial cat scale
		if cat_sprite:
			cat_sprite.scale = Vector2(45, 45)
	else:
		push_error("Text nodes not found!")

func generate_random_line(length: int) -> String:
	var line = ""
	for i in range(length):
		line += LETTERS[randi() % LETTERS.size()]
	return line

func _process(delta: float) -> void:
	# First check for sequence completion input
	var sequence_data = get_node_or_null("sequence_data")
	if sequence_data:
		var waiting = sequence_data.get_meta("waiting_for_input")
		if Input.is_action_just_pressed("ui_accept"):
			print("Enter pressed, waiting_for_input: ", waiting)
		
		if waiting and Input.is_action_just_pressed("ui_accept"):
			print("Final enter pressed, changing scene")
			# Get game manager and change scene properly
			var game_manager = get_node("/root/Root")
			if game_manager:
				print("Found game manager, changing to curry house inside")
				game_manager.change_to_dialogue("curry_house_inside")
			else:
				print("No game manager found!")
			return
	
	# Then handle the dialogue states
	if current_line >= dialogue_lines.size():
		reset_positions()
		if Input.is_action_just_pressed("ui_accept") and !is_second_message_animating:
			print("Starting second message transition")
			is_second_message_animating = true
			transition_to_second_message()
		return
		
	if is_line_finished:
		reset_positions()
		if Input.is_action_just_pressed("ui_accept") and !is_second_message_animating:
			start_next_line()
			if current_line >= dialogue_lines.size():
				print("Starting second message transition from line finish")
				is_second_message_animating = true
				transition_to_second_message()
		return
	
	# Skip to end of current line if enter is pressed during typing
	if Input.is_action_just_pressed("ui_accept") and !is_line_finished:
		current_text = dialogue_lines[current_line]
		bottom_text.text = current_text
		current_char_index = current_text.length()
		is_line_finished = true
		return
	
	# Handle character typing
	time_since_last_char += delta
	if time_since_last_char >= CHAR_DELAY:
		time_since_last_char = 0
		add_next_character()
	
	# Handle text shaking
	if top_text and !is_line_finished:
		shake_time += delta * SHAKE_SPEED
		var shake_offset = Vector2(
			sin(shake_time) * SHAKE_AMOUNT,
			cos(shake_time * 1.3) * SHAKE_AMOUNT
		)
		
		for child in top_text.get_children():
			if original_positions.has(child):
				child.position = original_positions[child] + shake_offset

func reset_positions() -> void:
	if is_instance_valid(top_text):  # Check if top_text still exists
		for child in top_text.get_children():
			if original_positions.has(child):
				child.position = original_positions[child]

func add_next_character() -> void:
	var current_full_line = dialogue_lines[current_line]
	
	if current_char_index < current_full_line.length():
		var next_char = current_full_line[current_char_index]
		current_text += next_char
		bottom_text.text = current_text
		current_char_index += 1
	else:
		is_line_finished = true

func start_next_line() -> void:
	current_line += 1
	current_text = ""
	current_char_index = 0
	is_line_finished = false
	bottom_text.text = "" 

func set_node_visibility_recursive(node: Node, visible: bool) -> void:
	# Try to set visibility if the node is a CanvasItem (Sprite2D, Label, etc)
	if node is CanvasItem:
		node.visible = visible
	
	# Recursively process all children
	for child in node.get_children():
		set_node_visibility_recursive(child, visible)

func transition_to_second_message() -> void:
	if first_message and second_message:
		# Hide all FirstMessage children recursively
		set_node_visibility_recursive(first_message, false)
		# Start the sequence of showing SecondMessage children
		start_sequence_animation()

func start_sequence_animation() -> void:
	print("Starting sequence animation")
	var timer = Timer.new()
	second_message.add_child(timer)
	timer.wait_time = 0.5  # 500ms delay
	timer.one_shot = false  # Change to repeating timer
	
	var child_nodes = second_message.get_children().duplicate()
	child_nodes.erase(timer)
	print("Found ", child_nodes.size(), " children to animate")
	
	var sequence_data = Node.new()
	sequence_data.name = "sequence_data"  # Give it a name so we can find it later
	sequence_data.set_meta("current_child", 0)
	sequence_data.set_meta("child_nodes", child_nodes)
	sequence_data.set_meta("timer", timer)
	sequence_data.set_meta("waiting_for_input", false)
	add_child(sequence_data)
	print("Created sequence_data node with name: ", sequence_data.name)
	
	# Hide all children first to ensure clean state
	for child in child_nodes:
		set_node_visibility_recursive(child, false)
	
	timer.timeout.connect(
		func():
			var current_child = sequence_data.get_meta("current_child")
			var nodes_to_show = sequence_data.get_meta("child_nodes")
			
			if current_child < nodes_to_show.size():
				print("Showing child ", current_child, " of ", nodes_to_show.size())
				set_node_visibility_recursive(nodes_to_show[current_child], true)
				sequence_data.set_meta("current_child", current_child + 1)
			else:
				print("Animation complete, waiting for input")
				timer.stop()
				timer.queue_free()
				sequence_data.set_meta("waiting_for_input", true)
	)
	
	timer.start()

# Helper function to wait for input
func wait_for_input() -> void:
	while true:
		if Input.is_action_just_pressed("ui_accept"):  # Enter key
			return
		await get_tree().create_timer(0.1).timeout 
