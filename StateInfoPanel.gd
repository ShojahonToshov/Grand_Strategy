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

func update_data(region_name: String, owner_name: String, owner_color: Color, resource_name: String = "", state_id: String = ""):
	current_state_id = state_id
	current_owner_name = owner_name
	
	var vbox = $Margin/VBox
	vbox.get_node("Header/TitleBox/RegionName").text = region_name
	vbox.get_node("OwnerBox/OwnerRow/OwnerName").text = owner_name
	vbox.get_node("OwnerBox/OwnerRow/ColorRect").color = owner_color
	vbox.get_node("PopBox/Population").text = "0"
	
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
	for c in b_content.get_children():
		c.queue_free()
		
	if not session: return
	
	var is_fra = (owner_name == "FRA" or owner_name == "Франция")
	if not is_fra: return
		
	if session.completed_buildings.has(state_id):
		var b = session.completed_buildings[state_id]
		var title = Label.new()
		title.text = "Шахта" if b.type == "GOLD_MINE" else "Лесозаготовка"
		title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
		b_content.add_child(title)
		
		var status = Label.new()
		var res_type = session.main_node.resource_distribution.get_resource_for_state(state_id)
		var is_match = (b.type == "GOLD_MINE" and res_type == 1) or (b.type == "LOGGING_CAMP" and res_type == 2)
		if is_match:
			status.text = "Работает (Добыча: " + str(1 if b.type == "GOLD_MINE" else 10) + ")"
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
		title.text = "Строится: " + ("Шахта" if order.type == "GOLD_MINE" else "Лесозаготовка")
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
	# Create a CanvasLayer so it stays on top of everything
	var modal_layer = CanvasLayer.new()
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
	title.text = "Лесозаготовка" if b_type == "LOGGING_CAMP" else "Шахта"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	vb.add_child(title)
	
	var match_lbl = Label.new()
	match_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if is_match:
		match_lbl.text = "Ресурс найден"
		match_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
	else:
		match_lbl.text = "Нет ресурса (Добыча 0)"
		match_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	vb.add_child(match_lbl)
	
	var cost_m = BalanceConfig.LOGGING_CAMP_COST_MONEY if b_type == "LOGGING_CAMP" else BalanceConfig.GOLD_MINE_COST_MONEY
	var cost_w = BalanceConfig.LOGGING_CAMP_COST_WOOD if b_type == "LOGGING_CAMP" else BalanceConfig.GOLD_MINE_COST_WOOD
	var days = BalanceConfig.LOGGING_CAMP_DAYS if b_type == "LOGGING_CAMP" else BalanceConfig.GOLD_MINE_DAYS
	var prod = BalanceConfig.LOGGING_CAMP_PROD_WOOD if b_type == "LOGGING_CAMP" else BalanceConfig.GOLD_MINE_PROD_GOLD
	
	var info = Label.new()
	info.text = "Цена: %d $\nДерево: %d\nВремя: %d дн.\nДобыча: %d/д." % [cost_m, cost_w, days, prod if is_match else 0]
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
	dialog.confirmed.connect(func():
		session.start_building(state_id, b_type)
		modal.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()

func _confirm_cancel(state_id: String, order: Dictionary):
	var session = get_tree().current_scene.get_node_or_null("GameSession")
	var progress = 1.0 - (float(order.hours_left) / float(order.total_hours))
	var rm = int(floor(order.cost_m * (1.0 - progress)))
	var rw = int(floor(order.cost_w * (1.0 - progress)))
	
	var dialog = ConfirmationDialog.new()
	dialog.title = "Отмена строительства"
	dialog.dialog_text = "Вернётся ресурсов:\nДеньги: %d\nДревесина: %d\n\nПродолжить?" % [rm, rw]
	dialog.confirmed.connect(func():
		session.cancel_building(state_id)
	)
	add_child(dialog)
	dialog.popup_centered()

func _confirm_demolish(state_id: String, b_name: String):
	var session = get_tree().current_scene.get_node_or_null("GameSession")
	var dialog = ConfirmationDialog.new()
	dialog.title = "Снос здания"
	dialog.dialog_text = "Снести %s в регионе %s?" % [b_name, state_id]
	dialog.confirmed.connect(func():
		session.demolish_building(state_id)
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
