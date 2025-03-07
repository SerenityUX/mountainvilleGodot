extends Camera2D

@export var viewport_size := Vector2(640, 400)  # Your target viewport size
var current_zoom := Vector2.ONE

func _ready() -> void:
	get_tree().root.size_changed.connect(_on_viewport_size_changed)
	_on_viewport_size_changed()

func _on_viewport_size_changed() -> void:
	var window_size = get_viewport_rect().size
	
	# Calculate zoom needed to maintain same view at different window sizes
	var zoom_x = window_size.x / viewport_size.x
	var zoom_y = window_size.y / viewport_size.y
	
	# Use the smaller zoom value to ensure content fits
	var new_zoom = min(zoom_x, zoom_y)
	zoom = Vector2(new_zoom, new_zoom) 
