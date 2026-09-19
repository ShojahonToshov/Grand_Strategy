extends PanelContainer

signal close_requested

var _tween: Tween

var current_state_id: String = ""
var current_owner_name: String = ""

func _ready():
	modulate.a = 0.0
	visible = false
	
	var close_btn = $Margin/VBox/Header/CloseBtn
	close_btn.pressed.connect(func(): close_requested.emit())
	
	var vbox = $Margin/VBox
	
	# ResourceBox
	var res_box = VBoxContainer.new()
	res_box.name = "ResourceBox"
	var res_sub = Label.new()
	res_sub.text = "РЕСУРС"
	res_sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	res_sub.add_theme_font_size_override("font_size", 12)
	res_box.add_child(res_sub)
	
	var res_row = HBoxContainer.new()
	res_row.name = "ResRow"
	var res_icon = TextureRect.new()
	res_icon.name = "Icon"
	res_icon.custom_minimum_size = Vector2(24, 24)
	res_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	res_row.add_child(res_icon)
	var res_name = Label.new()
	res_name.name = "ResName"
	res_row.add_child(res_name)
	res_box.add_child(res_row)
	
	var sep1 = HSeparator.new()
	sep1.name = "ResSep"
	vbox.add_child(sep1)
	vbox.add_child(res_box)
	
	# BuildingBox
	var sep2 = HSeparator.new()
	sep2.name = "BuildSep"
	vbox.add_child(sep2)
	
	var b_box = VBoxContainer.new()
	b_box.name = "BuildingBox"
	var b_sub = Label.new()
	b_sub.text = "ПОСТРОЙКИ"
	b_sub.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	b_sub.add_theme_font_size_override("font_size", 12)
	b_box.add_child(b_sub)
	
	var b_content = VBoxContainer.new()
	b_content.name = "Content"
	b_box.add_child(b_content)
	
	vbox.add_child(b_box)
	
	call_deferred("setup_session")

func setup_session():
	var session = get_tree().current_scene.get_node_or_null("GameSession")
	if session:
		session.building_updated.connect(func(sid):
			if sid == current_state_id and current_state_id != "":
				update_buildings(current_state_id, current_owner_name)
		)
		session.time_changed.connect(func():
			if current_state_id != "" and session.building_orders.has(current_state_id):
				_update_progress_bar_only(current_state_id)
		)

func _update_progress_bar_only(state_id: String):
	var session = get_tree().current_scene.get_node_or_null("GameSession")
	var b_content = $Margin/VBox/BuildingBox/Content
	for c in b_content.get_children():
		if c is ProgressBar and session.building_orders.has(state_id):
			var order = session.building_orders[state_id]
			c.value = order.total_hours - order.hours_left

func update_country_data(owner_tag: String, owner_name: String, owner_color: Color):
	current_state_id = ""
	current_owner_name = owner_tag
	
	var vbox = $Margin/VBox
	vbox.get_node("Header/TitleBox/Subtitle").text = "СТРАНА"
	vbox.get_node("Header/TitleBox/RegionName").text = owner_name
	
	vbox.get_node("OwnerBox").visible = false
	vbox.get_node("HSeparator2").visible = false
	
	var total_pop = 0
	var main_node = get_tree().current_scene
	if main_node and main_node.get("states_data") != null:
		var st_data = main_node.states_data
		for k in st_data.keys():
			if st_data[k].has("owner") and st_data[k]["owner"] == owner_tag:
				total_pop += st_data[k].get("population", 0)
				
	var pop_str = str(int(total_pop))
	var formatted_pop = ""
	var c = 0
	for i in range(pop_str.length() - 1, -1, -1):
		formatted_pop = pop_str[i] + formatted_pop
		c += 1
		if c % 3 == 0 and i != 0:
			formatted_pop = " " + formatted_pop
			
	vbox.get_node("PopBox/Population").text = formatted_pop
	
	vbox.get_node("ResourceBox").visible = false
	vbox.get_node("ResSep").visible = false
	vbox.get_node("BuildingBox").visible = false
	vbox.get_node("BuildSep").visible = false

func update_data(region_name: String, owner_name: String, owner_color: Color, resource_name: String = "", state_id: String = ""):
	current_state_id = state_id
	current_owner_name = owner_name
	
	var vbox = $Margin/VBox
	vbox.get_node("Header/TitleBox/Subtitle").text = "РЕГИОН"
	vbox.get_node("Header/TitleBox/RegionName").text = region_name
	vbox.get_node("OwnerBox").visible = true
	vbox.get_node("HSeparator2").visible = true
	vbox.get_node("OwnerBox/OwnerRow/OwnerName").text = owner_name
	vbox.get_node("OwnerBox/OwnerRow/ColorRect").color = owner_color
	var pop = 0
	var main_node = get_tree().current_scene
	if main_node and main_node.get("states_data") and main_node.states_data.has(state_id):
		pop = main_node.states_data[state_id].get("population", 0)
	
	var pop_str = str(int(pop))
	var formatted_pop = ""
	var c = 0
	for i in range(pop_str.length() - 1, -1, -1):
		formatted_pop = pop_str[i] + formatted_pop
		c += 1
		if c % 3 == 0 and i != 0:
			formatted_pop = " " + formatted_pop
			
	vbox.get_node("PopBox/Population").text = formatted_pop
	
	var res_box = vbox.get_node("ResourceBox")
	var res_sep = vbox.get_node("ResSep")
	if resource_name == "" or resource_name == "Ничего":
		res_box.visible = false
		res_sep.visible = false
	else:
		res_box.visible = true
		res_sep.visible = true
		var res_row = res_box.get_node("ResRow")
		res_row.get_node("ResName").text = resource_name
		if resource_name == "Золото":
			res_row.get_node("Icon").texture = load("res://assets/ui/resources/gold.png")
		elif resource_name == "Древесина":
			res_row.get_node("Icon").texture = load("res://assets/ui/resources/wood.png")
		elif resource_name == "Железо":
			res_row.get_node("Icon").texture = load("res://assets/ui/resources/iron.png")
		else:
			res_row.get_node("Icon").texture = null
		
	var b_box = vbox.get_node("BuildingBox")
	var b_sep = vbox.get_node("BuildSep")
	var is_fra = (owner_name == "FRA" or owner_name == "Франция")
	if not is_fra:
		b_box.visible = false
		b_sep.visible = false
	else:
		b_box.visible = true
		b_sep.visible = true
		if state_id != "":
			update_buildings(state_id, owner_name)

func update_buildings(state_id: String, owner_name: String):
	var session = get_tree().current_scene.get_node_or_null("GameSession")
	var b_content = $Margin/VBox/BuildingBox/Content
	for child in b_content.get_children():
		child.queue_free()
		
	if not session: return
	
	var is_fra = (owner_name == "FRA" or owner_name == "Франция")
	if not is_fra: return
		
	if session.completed_buildings.has(state_id):
		var b = session.completed_buildings[state_id]
		var title = Label.new()
		var b_name = "Постройка"
		if b.type == "GOLD_MINE": b_name = "Золотая Шахта"
		elif b.type == "LOGGING_CAMP": b_name = "Лесозаготовка"
		elif b.type == "IRON_MINE": b_name = "Железный Рудник"
		elif b.type == "STEEL_MILL": b_name = "Сталелитейный Завод"
		elif b.type == "UNIVERSITY": b_name = "Университет"
		title.text = b_name
		title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		b_content.add_child(title)
		
		var status = Label.new()
		var res_type = session.main_node.resource_distribution.get_resource_for_state(state_id)
		var is_match = (b.type == "GOLD_MINE" and res_type == 1) or (b.type == "LOGGING_CAMP" and res_type == 2) or (b.type == "IRON_MINE" and res_type == 3) or b.type == "STEEL_MILL" or b.type == "UNIVERSITY"
		if is_match:
			var prod_val = 0.0

			if b.type == "GOLD_MINE": prod_val = BalanceConfig.GOLD_MINE_PROD_GOLD
			elif b.type == "LOGGING_CAMP": prod_val = BalanceConfig.LOGGING_CAMP_PROD_WOOD
			elif b.type == "IRON_MINE": prod_val = BalanceConfig.IRON_MINE_PROD_IRON
			elif b.type == "STEEL_MILL": prod_val = BalanceConfig.STEEL_MILL_PROD_STEEL
			elif b.type == "UNIVERSITY": prod_val = BalanceConfig.UNIVERSITY_PROD_SCIENCE
			status.text = "Работает (Добыча: " + str(prod_val) + ")"
			status.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			status.text = "Простаивает (Нет ресурса)"
			status.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		b_content.add_child(status)
		
		var btn = Button.new()
		btn.text = "Снести"
		btn.custom_minimum_size.y = 30
		btn.pressed.connect(func(): _confirm_demolish(state_id, title.text))
		b_content.add_child(btn)
		
	elif session.building_orders.has(state_id):
		var order = session.building_orders[state_id]
		var title = Label.new()
		var b_name = "Постройка"
		if order.type == "GOLD_MINE": b_name = "Золотая Шахта"
		elif order.type == "LOGGING_CAMP": b_name = "Лесозаготовка"
		elif order.type == "IRON_MINE": b_name = "Железный Рудник"
		elif order.type == "STEEL_MILL": b_name = "Сталелитейный Завод"
		elif order.type == "UNIVERSITY": b_name = "Университет"
		title.text = "Строится: " + b_name
		b_content.add_child(title)
		
		var prog = ProgressBar.new()
		prog.max_value = order.total_hours
		prog.value = order.total_hours - order.hours_left
		prog.custom_minimum_size.y = 10
		b_content.add_child(prog)
		
		var btn = Button.new()
		btn.text = "Отменить"
		btn.custom_minimum_size.y = 30
		btn.pressed.connect(func(): _confirm_cancel(state_id, order))
		b_content.add_child(btn)
		
	else:
		var btn = Button.new()
		btn.text = "Построить"
		btn.custom_minimum_size.y = 30
		btn.pressed.connect(func(): _show_build_modal(state_id))
		b_content.add_child(btn)

func _show_build_modal(state_id: String):
	var existing = get_tree().current_scene.get_node_or_null("BuildModalLayer")
	if existing: existing.queue_free()

	# Create a CanvasLayer so it stays on top of everything
	var modal_layer = CanvasLayer.new()
	modal_layer.name = "BuildModalLayer"
	modal_layer.layer = 100
	get_tree().current_scene.add_child(modal_layer)
	
	# Dark overlay background
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(bg)
	
	# Centered Panel
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.add_child(center)
	
	var pan = PanelContainer.new()
	pan.custom_minimum_size = Vector2(400, 300)
	
	# Aesthetic style for the modal
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
	
	# Header with title and X button
	var header = HBoxContainer.new()
	vbox.add_child(header)
	
	var title = Label.new()
	title.text = "ВЫБОР ПОСТРОЙКИ"
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	# Make X button look nice
	var c_style = StyleBoxFlat.new()
	c_style.bg_color = Color(0.2, 0.2, 0.25)
	c_style.set_corner_radius_all(15)
	close_btn.add_theme_stylebox_override("normal", c_style)
	close_btn.pressed.connect(func(): modal_layer.queue_free())
	header.add_child(close_btn)
	
	var sep = HSeparator.new()
	vbox.add_child(sep)
	
	var cards_box = HBoxContainer.new()
	cards_box.add_theme_constant_override("separation", 16)
	cards_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(cards_box)
	
	var session = get_tree().current_scene.get_node_or_null("GameSession")
	var res_type = session.main_node.resource_distribution.get_resource_for_state(state_id)
	

	_create_build_card_modal("LOGGING_CAMP", state_id, res_type == 2, cards_box, session, modal_layer)
	_create_build_card_modal("GOLD_MINE", state_id, res_type == 1, cards_box, session, modal_layer)
	_create_build_card_modal("IRON_MINE", state_id, res_type == 3, cards_box, session, modal_layer)
	_create_build_card_modal("STEEL_MILL", state_id, true, cards_box, session, modal_layer)
	_create_build_card_modal("UNIVERSITY", state_id, true, cards_box, session, modal_layer)

func _create_build_card_modal(b_type: String, state_id: String, is_match: bool, container: Node, session: Node, modal: Node):
	var pan = PanelContainer.new()
	pan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.18, 0.22)
	style.set_corner_radius_all(8)
	pan.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	pan.add_child(margin)
	
	var vb = VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	margin.add_child(vb)
	
	var title = Label.new()
	var b_name = ""
	var cost_m = 0
	var cost_w = 0
	var days = 0
	var prod = 0.0
	var prod_name = ""

	
	match b_type:
		"LOGGING_CAMP":
			b_name = "Лесозаготовка"
			cost_m = BalanceConfig.LOGGING_CAMP_COST_MONEY
			cost_w = BalanceConfig.LOGGING_CAMP_COST_WOOD
			days = BalanceConfig.LOGGING_CAMP_DAYS
			prod = BalanceConfig.LOGGING_CAMP_PROD_WOOD
			prod_name = "Дерево"
		"GOLD_MINE":
			b_name = "Золотая Шахта"
			cost_m = BalanceConfig.GOLD_MINE_COST_MONEY
			cost_w = BalanceConfig.GOLD_MINE_COST_WOOD
			days = BalanceConfig.GOLD_MINE_DAYS
			prod = BalanceConfig.GOLD_MINE_PROD_GOLD
			prod_name = "Золото"
		"IRON_MINE":
			b_name = "Железный Рудник"
			cost_m = BalanceConfig.IRON_MINE_COST_MONEY
			cost_w = BalanceConfig.IRON_MINE_COST_WOOD
			days = BalanceConfig.IRON_MINE_DAYS
			prod = BalanceConfig.IRON_MINE_PROD_IRON
			prod_name = "Железо"
		"STEEL_MILL":
			b_name = "Сталелитейный Завод"
			cost_m = BalanceConfig.STEEL_MILL_COST_MONEY
			cost_w = BalanceConfig.STEEL_MILL_COST_WOOD
			days = BalanceConfig.STEEL_MILL_DAYS
			prod = BalanceConfig.STEEL_MILL_PROD_STEEL
			prod_name = "Сталь (-10 Жел)"
		"UNIVERSITY":
			b_name = "Университет"
			cost_m = BalanceConfig.UNIVERSITY_COST_MONEY
			cost_w = BalanceConfig.UNIVERSITY_COST_WOOD
			days = BalanceConfig.UNIVERSITY_DAYS
			prod = BalanceConfig.UNIVERSITY_PROD_SCIENCE
			prod_name = "Наука"
			
	title.text = b_name
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vb.add_child(title)
	
	var match_lbl = Label.new()
	match_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_match:
		match_lbl.text = "Подходит"
		match_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		match_lbl.text = "Нет ресурса"
		match_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	vb.add_child(match_lbl)
	
	var info = Label.new()
	info.text = "Цена: %d $\nДерево: %d\nВремя: %d дн.\n%s: %.1f/д." % [cost_m, cost_w, days, prod_name, prod if is_match else 0]
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	vb.add_child(info)
	
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(spacer)
	
	var btn = Button.new()
	btn.text = "Выбрать"
	btn.custom_minimum_size.y = 35
	btn.disabled = not session.can_build(state_id, b_type)
	btn.pressed.connect(func():
		if not is_match:
			_confirm_build_mismatch_modal(state_id, b_type, cost_m, cost_w, modal)
		else:
			session.start_building(state_id, b_type)
			modal.queue_free()
	)
	vb.add_child(btn)
	container.add_child(pan)

func _confirm_build_mismatch_modal(state_id: String, b_type: String, cost_m: int, cost_w: int, modal: Node):
	var session = get_tree().current_scene.get_node_or_null("GameSession")
	var dialog = ConfirmationDialog.new()
	dialog.title = "Внимание"
	var rname = "деревьев" if b_type == "LOGGING_CAMP" else "золота"
	dialog.dialog_text = "Здесь нет %s. Построить за %d денег и %d древесины?" % [rname, cost_m, cost_w]
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func():
		session.start_building(state_id, b_type)
		modal.queue_free()
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()

func _confirm_cancel(state_id: String, order: Dictionary):
	var session = get_tree().current_scene.get_node_or_null("GameSession")
	var progress = 1.0 - (float(order.hours_left) / float(order.total_hours))
	var rm = int(floor(order.cost_m * (1.0 - progress)))
	var rw = int(floor(order.cost_w * (1.0 - progress)))
	var rg = int(floor(order.cost_g * (1.0 - progress)))
	
	var dialog = ConfirmationDialog.new()
	dialog.title = "Отмена строительства"
	dialog.dialog_text = "Вернётся ресурсов:\nДеньги: %d\nДревесина: %d\nЗолото: %d\n\nПродолжить?" % [rm, rw, rg]
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func():
		session.cancel_building(state_id)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()

func _confirm_demolish(state_id: String, b_name: String):
	var session = get_tree().current_scene.get_node_or_null("GameSession")
	var dialog = ConfirmationDialog.new()
	dialog.title = "Снос здания"
	dialog.dialog_text = "Снести %s в регионе %s?" % [b_name, state_id]
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.confirmed.connect(func():
		session.demolish_building(state_id)
		dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()
	
func show_panel():
	if visible and position.x == 24.0 and modulate.a == 1.0:
		return # Already fully visible, do nothing
		
	if not visible:
		visible = true
		modulate.a = 0.0
		position.x = -10.0 # slight slide
	
	if _tween and _tween.is_valid():
		_tween.kill()
		
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.15).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "position:x", 24.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func hide_panel():
	if not visible:
		return
		
	if _tween and _tween.is_valid():
		_tween.kill()
		
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 0.0, 0.15).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "position:x", -10.0, 0.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func(): visible = false)
