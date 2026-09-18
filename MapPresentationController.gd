extends Node

signal mode_changed(new_mode)
signal theme_changed(new_theme)

enum MapMode {
	STATES,
	COUNTRIES
}

enum MapTheme {
	POLITICAL,
	RESOURCES
}

var current_theme: MapTheme = MapTheme.POLITICAL
var current_mode: MapMode = MapMode.STATES
var overview_ratio: float = 0.0

var country_labels_alpha: float = 0.0
var capital_stars_alpha: float = 1.0
var internal_borders_alpha: float = 1.0

@export var states_threshold: float = 0.36
@export var countries_threshold: float = 0.42

var map_width: float = 5632.0 # Default HOI4 map width

func set_theme(theme: MapTheme):
	if current_theme != theme:
		current_theme = theme
		theme_changed.emit(current_theme)
		_process(0.0) # force update

func _process(_delta):
	var camera = get_viewport().get_camera_2d()
	if not camera: return
	
	var view_rect = get_viewport().get_visible_rect()
	var visible_map_width = view_rect.size.x / camera.zoom.x
	
	overview_ratio = visible_map_width / map_width
	
	var new_mode = current_mode
	
	if current_theme == MapTheme.RESOURCES:
		new_mode = MapMode.STATES
	else:
		if overview_ratio > countries_threshold:
			new_mode = MapMode.COUNTRIES
		elif overview_ratio < states_threshold:
			new_mode = MapMode.STATES
		
	if new_mode != current_mode:
		current_mode = new_mode
		mode_changed.emit(current_mode)
		
	var fade = smoothstep(0.30, 0.48, overview_ratio)
	
	if current_theme == MapTheme.RESOURCES:
		country_labels_alpha = 0.0
		capital_stars_alpha = 0.0
		internal_borders_alpha = 1.0
	else:
		country_labels_alpha = fade
		capital_stars_alpha = 1.0 - fade
		internal_borders_alpha = 1.0 - fade

