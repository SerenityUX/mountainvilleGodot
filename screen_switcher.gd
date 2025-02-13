extends Sprite2D

var current_screen := 1
const TOTAL_SCREENS := 3

func _ready() -> void:
	update_screen()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):  # This is the Enter/Return key
		if current_screen < TOTAL_SCREENS:
			current_screen += 1
			update_screen()
		else:
			# Try different ways to find the game manager
			var game_manager = get_tree().root.get_node_or_null("Root")
			if !game_manager:
				# If not found, try finding it as an autoload
				game_manager = get_node("/root/GameManager")
			
			if game_manager:
				game_manager.change_level(1)
			else:
				push_error("Could not find game manager! Make sure it's properly set up in the scene tree.")

func update_screen() -> void:
	var path = "res://screen" + str(current_screen) + ".png"
	var texture = load(path)
	if texture:
		self.texture = texture
	else:
		push_error("Could not load texture from path: " + path) 
