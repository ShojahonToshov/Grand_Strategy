extends PanelContainer



@onready var time_label = $Margin/HBox/RightBox/Date
@onready var pause_btn = $Margin/HBox/RightBox/TimeControls/Pause
var speed_btns = []
var session: Node

func _ready():
	var player_tag = "FRA"
	var country_name = "Франция"
	var f = FileAccess.open("res://ui_data.json", FileAccess.READ)
	if f:
		var json = JSON.new()
		if json.parse(f.get_as_text()) == OK:
			var ui_data = json.data
			if ui_data.has("countries") and ui_data["countries"].has(player_tag):
				country_name = ui_data["countries"][player_tag]
				
	var title_lbl = $Margin/HBox/LeftBox/Title
	title_lbl.text = country_name
	title_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
	title_lbl.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	title_lbl.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_show_country_modal(player_tag, country_name)
	)
	
	# The setup_session will handle data
	
	speed_btns.append($Margin/HBox/RightBox/TimeControls/Speed1)
	speed_btns.append($Margin/HBox/RightBox/TimeControls/Speed2)
	speed_btns.append($Margin/HBox/RightBox/TimeControls/Speed3)
	speed_btns.append($Margin/HBox/RightBox/TimeControls/Speed4)
	speed_btns.append($Margin/HBox/RightBox/TimeControls/Speed5)
	
	pause_btn.pressed.connect(func():
		if session:
			session.is_paused = not session.is_paused
			session.time_changed.emit()
	)
	
	for i in range(5):
		speed_btns[i].pressed.connect(func():
			if session:
				session.speed_idx = i
				session.is_paused = false
				session.time_changed.emit()
		)
		
	# Wait one frame for Main to be ready
	call_deferred("setup_session")

func setup_session():
	session = get_tree().current_scene.get_node_or_null("GameSession")
	if session:
		session.time_changed.connect(update_time_ui)
		session.resources_changed.connect(update_res_ui)
		update_time_ui()
		update_res_ui()

func update_time_ui():
	if not session: return
	
	# The user asked to format date properly and separate hours if needed.
	var ds = session.get_date_string()
	if ", " in ds:
		# e.g., "01.01.1936, 00:00" -> separate date and time.
		var parts = ds.split(", ")
		time_label.text = parts[0] + "   " + parts[1]
	else:
		time_label.text = ds
	
	if session.is_paused:
		pause_btn.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	else:
		pause_btn.remove_theme_color_override("font_color")
		
	for i in range(5):
		if i == session.speed_idx and not session.is_paused:
			speed_btns[i].add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			speed_btns[i].remove_theme_color_override("font_color")

func _format_res(val: float, allow_decimal: bool = false) -> String:
	var abs_v = abs(val)
	if abs_v >= 1000000000.0:
		return str(snapped(val / 1000000000.0, 0.01)) + "B"
	elif abs_v >= 1000000.0:
		return str(snapped(val / 1000000.0, 0.01)) + "M"
	elif abs_v >= 1000.0:
		return str(snapped(val / 1000.0, 0.1)) + "k"
	else:
		if allow_decimal and val - floor(val) > 0.001:
			return str(snapped(val, 0.1))
		return str(floor(val))

func update_res_ui():
	if not session: return
	$Margin/HBox/CenterBox/Resources/Money/Label.text = _format_res(session.money)
	$Margin/HBox/CenterBox/Resources/Gold/Label.text = _format_res(session.gold, true)
	$Margin/HBox/CenterBox/Resources/Wood/Label.text = _format_res(session.wood)
	$Margin/HBox/CenterBox/Resources/Science/Label.text = _format_res(session.science)
	$Margin/HBox/CenterBox/Resources/Iron/Label.text = _format_res(session.iron)
	$Margin/HBox/CenterBox/Resources/Steel/Label.text = _format_res(session.steel)
	$Margin/HBox/CenterBox/Resources/Oil/Label.text = _format_res(session.oil)
	
	$Margin/HBox/CenterBox/Resources/Money.tooltip_text = "Деньги"

func _show_country_modal(tag: String, country_name: String):
	var existing = get_tree().current_scene.get_node_or_null("CountryModalLayer")
	if existing:
		existing.queue_free()
		
	var modal_layer = CanvasLayer.new()
	modal_layer.name = "CountryModalLayer"
	modal_layer.layer = 100
	get_tree().current_scene.add_child(modal_layer)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(bg)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)
	
	var pan = PanelContainer.new()
	pan.custom_minimum_size = Vector2(500, 350)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.15, 0.18)
	style.set_corner_radius_all(12)
	style.border_width_bottom = 2
	style.border_width_top = 2
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_color = Color(0.2, 0.25, 0.3)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 10
	pan.add_theme_stylebox_override("panel", style)
	center.add_child(pan)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	pan.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var title = Label.new()
	title.text = country_name.to_upper()
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	title.add_theme_font_size_override("font_size", 24)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(func(): modal_layer.queue_free())
	header.add_child(close_btn)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	var info_vbox = VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 10)
	vbox.add_child(info_vbox)
	
	# Calculate owned states, population, and base tax potential
	var total_states = 0
	var total_pop = 0
	var total_base_tax = 0.0
	var main_node = get_tree().current_scene
	if main_node.get("states_data") != null:
		var st_data = main_node.states_data
		for k in st_data.keys():
			if st_data[k].has("owner") and st_data[k]["owner"] == tag:
				total_states += 1
				var pop = st_data[k].get("population", 0)
				total_pop += pop
				var o_group = st_data[k].get("owner_group", "DEFAULT")
				var base_tax = BalanceConfig.TAX_BASE_PER_CAPITA.get(o_group, BalanceConfig.TAX_BASE_PER_CAPITA["DEFAULT"])
				total_base_tax += pop * base_tax
				
	var lbl_tag = Label.new()
	lbl_tag.text = "Тег страны: " + tag
	info_vbox.add_child(lbl_tag)
	
	var lbl_states = Label.new()
	lbl_states.text = "Количество регионов: " + str(total_states)
	info_vbox.add_child(lbl_states)
	
	var pop_str = str(int(total_pop))
	var formatted_pop = ""
	var c = 0
	for i in range(pop_str.length() - 1, -1, -1):
		formatted_pop = pop_str[i] + formatted_pop
		c += 1
		if c % 3 == 0 and i != 0:
			formatted_pop = " " + formatted_pop
			
	var lbl_pop = Label.new()
	lbl_pop.text = "Население: " + formatted_pop
	info_vbox.add_child(lbl_pop)
	
	if session:
		var active_buildings = 0
		for k in session.completed_buildings.keys():
			if main_node and main_node.get_state_owner(k) == tag:
				active_buildings += 1
		
		var b_lbl = Label.new()
		b_lbl.text = "Построено зданий: " + str(active_buildings)
		info_vbox.add_child(b_lbl)
		
		var queued_buildings = 0
		for k in session.building_orders.keys():
			if main_node and main_node.get_state_owner(k) == tag:
				queued_buildings += 1
		
		var q_lbl = Label.new()
		q_lbl.text = "Зданий в очереди: " + str(queued_buildings)
		info_vbox.add_child(q_lbl)
		
		var tax_sep = HSeparator.new()
		vbox.add_child(tax_sep)
		
		var tax_label = Label.new()
		vbox.add_child(tax_label)
		
		var slider = HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.value = session.tax_rate
		vbox.add_child(slider)
		
		var income_lbl = Label.new()
		vbox.add_child(income_lbl)
		
		var update_income_lbl = func(val):
			var daily_mult = (val / 100.0) / 365.0
			var total_daily = total_base_tax * daily_mult
			tax_label.text = "Налоги (Ставка: " + str(val) + "%)"
			if total_pop > 0:
				var avg_daily_per_person = total_daily / total_pop
				income_lbl.text = "Ср. доход с 1 чел: $%.4f / день\nОбщий доход: $%s / день" % [avg_daily_per_person, _format_res(total_daily, true)]
			else:
				income_lbl.text = "Общий доход: $0 / день"
		
		update_income_lbl.call(slider.value)
		
		slider.value_changed.connect(func(val):
			session.tax_rate = val
			update_income_lbl.call(val)
		)
