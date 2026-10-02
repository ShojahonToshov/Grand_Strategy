extends Window

var camera: Camera2D
var map_presentation: Node

var slider_max_in: HSlider
var slider_margin: HSlider
var slider_state_thresh: HSlider
var slider_country_thresh: HSlider

var lbl_max_in: Label
var lbl_margin: Label
var lbl_state_thresh: Label
var lbl_country_thresh: Label

# Internal property for the margin logic (default 0.5 in CameraController)
var current_margin: float = 0.5

func _ready():
	title = "Настройки Камеры и Режимов"
	size = Vector2(450, 420)
	min_size = Vector2(400, 350)
	close_requested.connect(hide)
	
	var bg = Panel.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 16)
	margin_container.add_theme_constant_override("margin_right", 16)
	margin_container.add_theme_constant_override("margin_top", 16)
	margin_container.add_theme_constant_override("margin_bottom", 16)
	margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin_container)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin_container.add_child(vbox)
	
	# Max Zoom In
	var hb_max_in = HBoxContainer.new()
	var lbl_title1 = Label.new()
	lbl_title1.text = "Макс. приближение:"
	lbl_title1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_max_in.add_child(lbl_title1)
	
	lbl_max_in = Label.new()
	hb_max_in.add_child(lbl_max_in)
	vbox.add_child(hb_max_in)
	
	slider_max_in = HSlider.new()
	slider_max_in.min_value = 1.0
	slider_max_in.max_value = 10.0
	slider_max_in.step = 0.1
	slider_max_in.value_changed.connect(_on_max_in_changed)
	vbox.add_child(slider_max_in)
	
	vbox.add_child(HSeparator.new())
	
	# Max Zoom Out (Margin)
	var hb_margin = HBoxContainer.new()
	var lbl_title2 = Label.new()
	lbl_title2.text = "Макс. отдаление (отступ):"
	lbl_title2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_margin.add_child(lbl_title2)
	
	lbl_margin = Label.new()
	hb_margin.add_child(lbl_margin)
	vbox.add_child(hb_margin)
	
	slider_margin = HSlider.new()
	slider_margin.min_value = 0.0
	slider_margin.max_value = 2.0
	slider_margin.step = 0.05
	slider_margin.value_changed.connect(_on_margin_changed)
	vbox.add_child(slider_margin)
	
	vbox.add_child(HSeparator.new())
	
	# State Threshold (Transition to Province)
	var hb_state = HBoxContainer.new()
	var lbl_title3 = Label.new()
	lbl_title3.text = "Порог перехода (Провинции):"
	lbl_title3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_state.add_child(lbl_title3)
	
	lbl_state_thresh = Label.new()
	hb_state.add_child(lbl_state_thresh)
	vbox.add_child(hb_state)
	
	slider_state_thresh = HSlider.new()
	slider_state_thresh.min_value = 0.05
	slider_state_thresh.max_value = 1.0
	slider_state_thresh.step = 0.01
	slider_state_thresh.value_changed.connect(_on_state_thresh_changed)
	vbox.add_child(slider_state_thresh)
	
	# Country Threshold (Transition to Country)
	var hb_country = HBoxContainer.new()
	var lbl_title4 = Label.new()
	lbl_title4.text = "Порог перехода (Государства):"
	lbl_title4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb_country.add_child(lbl_title4)
	
	lbl_country_thresh = Label.new()
	hb_country.add_child(lbl_country_thresh)
	vbox.add_child(hb_country)
	
	slider_country_thresh = HSlider.new()
	slider_country_thresh.min_value = 0.05
	slider_country_thresh.max_value = 1.0
	slider_country_thresh.step = 0.01
	slider_country_thresh.value_changed.connect(_on_country_thresh_changed)
	vbox.add_child(slider_country_thresh)
	
	vbox.add_child(HSeparator.new())
	
	# Real-time info
	var info_title = Label.new()
	info_title.text = "Текущие параметры (Реальное время):"
	info_title.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	vbox.add_child(info_title)
	
	lbl_current_zoom = Label.new()
	vbox.add_child(lbl_current_zoom)
	
	lbl_current_ratio = Label.new()
	vbox.add_child(lbl_current_ratio)
	
	# Refresh UI initially
	call_deferred("load_initial_values")

var lbl_current_zoom: Label
var lbl_current_ratio: Label

func _process(_delta):
	if camera and is_instance_valid(camera):
		lbl_current_zoom.text = "Текущий Zoom: " + str(snapped(camera.zoom.x, 0.001))
	if map_presentation and is_instance_valid(map_presentation):
		lbl_current_ratio.text = "Overview Ratio (для порогов): " + str(snapped(map_presentation.overview_ratio, 0.001))

func setup(p_camera: Camera2D, p_map_presentation: Node):
	camera = p_camera
	map_presentation = p_map_presentation
	load_initial_values()

func load_initial_values():
	if not is_inside_tree() or not camera or not map_presentation:
		return
		
	slider_max_in.set_block_signals(true)
	slider_max_in.value = camera.max_physical_pixels_per_map_pixel
	lbl_max_in.text = str(slider_max_in.value)
	slider_max_in.set_block_signals(false)
	
	slider_margin.set_block_signals(true)
	slider_margin.value = current_margin
	lbl_margin.text = str(current_margin)
	slider_margin.set_block_signals(false)
	
	slider_state_thresh.set_block_signals(true)
	slider_state_thresh.value = map_presentation.states_threshold
	lbl_state_thresh.text = str(slider_state_thresh.value)
	slider_state_thresh.set_block_signals(false)
	
	slider_country_thresh.set_block_signals(true)
	slider_country_thresh.value = map_presentation.countries_threshold
	lbl_country_thresh.text = str(slider_country_thresh.value)
	slider_country_thresh.set_block_signals(false)

func _on_max_in_changed(val: float):
	lbl_max_in.text = str(val)
	if camera:
		camera.max_physical_pixels_per_map_pixel = val
		camera.calc_limits()

func _on_margin_changed(val: float):
	lbl_margin.text = str(val)
	current_margin = val
	if camera:
		# We need to communicate margin back to camera.
		# Camera currently uses hardcoded 0.5 for margin.
		if camera.has_method("set_zoom_margin"):
			camera.set_zoom_margin(val)

func _on_state_thresh_changed(val: float):
	lbl_state_thresh.text = str(val)
	if map_presentation:
		map_presentation.states_threshold = val
		
func _on_country_thresh_changed(val: float):
	lbl_country_thresh.text = str(val)
	if map_presentation:
		map_presentation.countries_threshold = val
