extends Node2D

var side_a_armies: Array = []
var side_b_armies: Array = []

var side_a_tag: String
var side_b_tag: String

var prog: float = 0.5 
var duration_hours_passed: float = 0.0

var color_a: Color
var color_b: Color

var lbl_a: Label
var lbl_b: Label

var is_ending: bool = false
var end_timer: float = 0.0

func setup(first_a, first_b):
	side_a_armies.append(first_a)
	side_b_armies.append(first_b)
	
	first_a.in_combat = true
	first_a.is_moving = false
	first_a.target_army = null
	
	first_b.in_combat = true
	first_b.is_moving = false
	first_b.target_army = null
	
	side_a_tag = first_a.owner_tag
	side_b_tag = first_b.owner_tag
	
	color_a = get_tag_color(side_a_tag)
	color_b = get_tag_color(side_b_tag)
	
	scale = Vector2(0.25, 0.25)
	
	position = first_b.position
	position.y -= 25
	
	z_index = 60
	
	var ls = LabelSettings.new()
	ls.font_size = 32
	ls.font_color = Color(1, 1, 1)
	ls.outline_size = 4
	ls.outline_color = Color(0, 0, 0, 0.8)
	
	lbl_a = Label.new()
	lbl_a.label_settings = ls
	lbl_a.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl_a.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_a.scale = Vector2(0.25, 0.25)
	add_child(lbl_a)
	
	lbl_b = Label.new()
	lbl_b.label_settings = ls
	lbl_b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_b.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl_b.scale = Vector2(0.25, 0.25)
	add_child(lbl_b)
	
	_update_labels()
	queue_redraw()

func get_tag_color(tag: String) -> Color:
	if tag == "FRA": return Color(0.12, 0.2, 0.45)
	if tag == "GER": return Color(0.15, 0.15, 0.15)
	if tag == "ENG": return Color(0.8, 0.1, 0.1)
	return Color(0.5, 0.5, 0.5)

func has_army(army) -> bool:
	return side_a_armies.has(army) or side_b_armies.has(army)

func add_army(army):
	if army.owner_tag == side_a_tag:
		if not side_a_armies.has(army): side_a_armies.append(army)
	else:
		if not side_b_armies.has(army): side_b_armies.append(army)
		
	army.in_combat = true
	army.is_moving = false
	army.target_army = null

func _process(delta):
	if is_ending:
		end_timer += delta
		modulate.a = max(0.0, 1.0 - end_timer * 2.0)
		if end_timer >= 0.5:
			queue_free()
		return
		
	# Clean up dead or invalid armies
	for i in range(side_a_armies.size() - 1, -1, -1):
		if not is_instance_valid(side_a_armies[i]) or side_a_armies[i].is_dying or not side_a_armies[i].in_combat:
			if is_instance_valid(side_a_armies[i]): side_a_armies[i].in_combat = false
			side_a_armies.remove_at(i)
			
	for i in range(side_b_armies.size() - 1, -1, -1):
		if not is_instance_valid(side_b_armies[i]) or side_b_armies[i].is_dying or not side_b_armies[i].in_combat:
			if is_instance_valid(side_b_armies[i]): side_b_armies[i].in_combat = false
			side_b_armies.remove_at(i)
			
	if side_a_armies.size() == 0 or side_b_armies.size() == 0:
		end_battle()
		return
		
	# Arrange visually
	for i in range(side_a_armies.size()):
		var a = side_a_armies[i]
		a.combat_pos = position + Vector2(-12.0 - (i*24.0), 25.0)
		
	for i in range(side_b_armies.size()):
		var b = side_b_armies[i]
		b.combat_pos = position + Vector2(12.0 + (i*24.0), 25.0)
		
	var main = get_tree().current_scene
	var gs = main.get_node_or_null("GameSession")
	if not gs or gs.is_paused:
		return
		
	var game_speed = gs.speed_hours_per_sec[gs.speed_idx]
	var hours = delta * game_speed
	
	duration_hours_passed += hours
	
	var a_pop = 0.0
	for a in side_a_armies: a_pop += float(a.population)
	
	var b_pop = 0.0
	for b in side_b_armies: b_pop += float(b.population)
	
	# Distribute damage proportionally
	var a_dmg_total = (b_pop * 0.05) * (hours / 24.0)
	var b_dmg_total = (a_pop * 0.05) * (hours / 24.0)
	
	for a in side_a_armies:
		var ratio = float(a.population) / max(a_pop, 1.0)
		a.population = max(0, int(a.population - (a_dmg_total * ratio)))
		a.set_data(a.state_id, a.population, a.owner_tag)
		if a.population <= 0:
			a.die()
			
	for b in side_b_armies:
		var ratio = float(b.population) / max(b_pop, 1.0)
		b.population = max(0, int(b.population - (b_dmg_total * ratio)))
		b.set_data(b.state_id, b.population, b.owner_tag)
		if b.population <= 0:
			b.die()
			
	var new_a_pop = 0.0
	for a in side_a_armies: new_a_pop += float(a.population)
	var new_b_pop = 0.0
	for b in side_b_armies: new_b_pop += float(b.population)
	
	var total = new_a_pop + new_b_pop
	if total > 0:
		prog = new_a_pop / total
		
	_update_labels()
	queue_redraw()

func _update_labels():
	var pct_a = round(prog * 100.0)
	var pct_b = 100.0 - pct_a
	
	lbl_a.text = str(pct_a) + "%"
	lbl_b.text = str(pct_b) + "%"
	
	var bar_w = 70.0
	var bar_h = 12.0
	
	lbl_a.size = Vector2(bar_w / 2 - 4, bar_h) * 4.0
	lbl_a.position = Vector2(-bar_w/2 + 2, -bar_h/2)
	
	lbl_b.size = Vector2(bar_w / 2 - 4, bar_h) * 4.0
	lbl_b.position = Vector2(2, -bar_h/2)

func end_battle():
	is_ending = true
	for a in side_a_armies:
		if is_instance_valid(a):
			a.in_combat = false
			a.target_army = null
	for b in side_b_armies:
		if is_instance_valid(b):
			b.in_combat = false
			b.target_army = null

func _draw():
	var bar_w = 70.0
	var bar_h = 12.0
	var bar_rect = Rect2(-bar_w/2, -bar_h/2, bar_w, bar_h)
	
	draw_rect(bar_rect.grow(2.0), Color(0.8, 0.8, 0.8))
	draw_rect(bar_rect.grow(1.0), Color(0.1, 0.1, 0.1))
	
	var w_a = bar_w * prog
	if w_a > 0:
		draw_rect(Rect2(-bar_w/2, -bar_h/2, w_a, bar_h), color_a)
		
	var w_b = bar_w * (1.0 - prog)
	if w_b > 0:
		draw_rect(Rect2(-bar_w/2 + w_a, -bar_h/2, w_b, bar_h), color_b)
		
	draw_line(Vector2(-bar_w/2 + w_a, -bar_h/2), Vector2(-bar_w/2 + w_a, bar_h/2), Color(1,1,1), 1.0)
