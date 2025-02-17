extends Node

@onready var bottom_text = $"../BottomText"  # Reference to the BottomText label
@onready var top_text = $"../TopText"  # Reference to the TopText node
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
	else:
		push_error("Text nodes not found!")

func generate_random_line(length: int) -> String:
	var line = ""
	for i in range(length):
		line += LETTERS[randi() % LETTERS.size()]
	return line

func _process(delta: float) -> void:
	if current_line >= dialogue_lines.size():
		# Reset all children positions when finished
		reset_positions()
		return  # All dialogue is finished
		
	if is_line_finished:
		# Reset all children positions when line is finished
		reset_positions()
		if Input.is_action_just_pressed("ui_accept"):  # Space bar
			start_next_line()
		return
		
	time_since_last_char += delta
	if time_since_last_char >= CHAR_DELAY:
		time_since_last_char = 0
		add_next_character()
	
	# Shake all children of TopText while typing
	if top_text and !is_line_finished:
		shake_time += delta * SHAKE_SPEED
		var shake_offset = Vector2(
			sin(shake_time) * SHAKE_AMOUNT,
			cos(shake_time * 1.3) * SHAKE_AMOUNT  # Different frequency for y axis
		)
		
		# Apply shake to all children
		for child in top_text.get_children():
			if original_positions.has(child):
				child.position = original_positions[child] + shake_offset

func reset_positions() -> void:
	if top_text:
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
