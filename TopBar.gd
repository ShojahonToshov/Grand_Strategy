extends PanelContainer

var time_label: Label
var pause_btn: Button
var speed_btns = []
var session: Node

func _ready():
	var hbox = $Margin/HBox
	$Margin/HBox/Title.text = "Франция"
	
	var time_hbox = HBoxContainer.new()
	time_hbox.name = "TimeControls"
	time_hbox.add_theme_constant_override("separation", 8)
	time_hbox.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	hbox.add_child(time_hbox)
	
	time_label = Label.new()
	time_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	time_label.custom_minimum_size.x = 140
	time_hbox.add_child(time_label)
	
	pause_btn = Button.new()
	pause_btn.text = "||"
	pause_btn.custom_minimum_size = Vector2(32, 32)
	pause_btn.pressed.connect(func():
		if session:
			session.is_paused = not session.is_paused
			session.time_changed.emit()
	)
	time_hbox.add_child(pause_btn)
	
	for i in range(5):
		var b = Button.new()
		b.text = str(i + 1)
		b.custom_minimum_size = Vector2(32, 32)
		b.pressed.connect(func():
			if session:
				session.speed_idx = i
				session.is_paused = false
				session.time_changed.emit()
		)
		speed_btns.append(b)
		time_hbox.add_child(b)
		
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
	time_label.text = session.get_date_string()
	
	if session.is_paused:
		pause_btn.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
	else:
		pause_btn.remove_theme_color_override("font_color")
		
	for i in range(5):
		if i == session.speed_idx and not session.is_paused:
			speed_btns[i].add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		else:
			speed_btns[i].remove_theme_color_override("font_color")

func update_res_ui():
	if not session: return
	$Margin/HBox/Resources/Money/Label.text = str(session.money)
	$Margin/HBox/Resources/Gold/Label.text = str(session.gold)
	$Margin/HBox/Resources/Wood/Label.text = str(session.wood)
	
	$Margin/HBox/Resources/Money.tooltip_text = "Деньги\nБазовый бюджет: +10 / день"
