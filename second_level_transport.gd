extends Button

func _ready() -> void:
	# Connect the button's pressed signal to our handler
	pressed.connect(_on_button_pressed)
	text = "Transport to Level 2"
	
	# Set default appearance
	self_modulate = Color(1, 1, 1, 1)  # Full opacity
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	# Connect to game manager signals
	var game_manager = get_node("/root/Root")
	if game_manager:
		game_manager.inventory_updated.connect(_on_inventory_updated)
		game_manager.transport_ready.connect(_on_transport_ready)
		game_manager.level_completed.connect(_on_level_completed)
		
		# Initial state check
		update_button_state()

func update_button_state() -> void:
	var game_manager = get_node("/root/Root")
	if game_manager.is_level_completed(2):
		disabled = true
		self_modulate = Color(0.5, 0.5, 0.5, 0.5)
		text = "Level Complete!"
	elif game_manager.is_level_completed(1):
		disabled = false
		self_modulate = Color(1, 1, 1, 1)
		text = "Transport to Level 2"
		# Force button to be fully visible and enabled
		modulate = Color(1, 1, 1, 1)
		mouse_filter = Control.MOUSE_FILTER_STOP
		focus_mode = Control.FOCUS_ALL
	else:
		disabled = true
		self_modulate = Color(0.5, 0.5, 0.5, 0.5)
		text = "Complete Level 1 First!"

func _on_button_pressed() -> void:
	var game_manager = get_node("/root/Root")
	if game_manager and game_manager.is_level_completed(1) and not game_manager.is_level_completed(2):
		game_manager.change_level(2)

func _on_transport_ready() -> void:
	update_button_state()

func _on_inventory_updated(_current_count: int, _required_count: int) -> void:
	update_button_state()

func _on_level_completed(_level_num: int) -> void:
	update_button_state() 