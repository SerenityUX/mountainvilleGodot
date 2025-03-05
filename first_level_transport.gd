extends Button

func _ready() -> void:
	# Connect the button's pressed signal to our handler
	pressed.connect(_on_button_pressed)
	text = "Transport to Level 1"
	
	# Check level completion status
	var game_manager = get_node("/root/Root")
	if game_manager:
		if game_manager.is_level_completed(1):
			disabled = true
			modulate = Color(0.5, 0.5, 0.5, 0.5)
			text = "Level Complete!"
		elif not game_manager.is_level_completed(0):
			disabled = true
			modulate = Color(0.5, 0.5, 0.5, 0.5)
			text = "Complete Curry House First!"

func _on_button_pressed() -> void:
	var game_manager = get_node("/root/Root")
	if game_manager and game_manager.is_level_completed(0) and not game_manager.is_level_completed(1):
		game_manager.change_level(1)

func _on_transport_ready() -> void:
	var game_manager = get_node("/root/Root")
	if game_manager.is_level_completed(1):
		disabled = true
		modulate = Color(0.5, 0.5, 0.5, 0.5)
		text = "Level Complete!"
	elif not game_manager.is_level_completed(0):
		disabled = true
		modulate = Color(0.5, 0.5, 0.5, 0.5)
		text = "Complete Curry House First!"
	else:
		disabled = false
		modulate = Color(1, 1, 1, 1)
		text = "Transport to Level 1"

func _on_inventory_updated(current_count: int, required_count: int) -> void:
	_update_button_state(current_count, required_count)

func _update_button_state(current_count: int, required_count: int) -> void:
	var game_manager = get_node("/root/Root")
	if game_manager.is_level_completed(1):
		disabled = true
		modulate = Color(0.5, 0.5, 0.5, 0.5)
		text = "Level Complete!"
		return
	elif not game_manager.is_level_completed(0):
		disabled = true
		modulate = Color(0.5, 0.5, 0.5, 0.5)
		text = "Complete Curry House First!"
		return
		
	if current_count < required_count:
		disabled = true
		modulate = Color(1, 1, 1, 0.5)
		text = "Need %d more items" % (required_count - current_count)
	else:
		disabled = false
		modulate = Color(1, 1, 1, 1)
		text = "Transport to Level 1" 
