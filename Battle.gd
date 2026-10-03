extends Node2D

var army_a
var army_b

var prog: float = 0.5 
var duration_hours_passed: float = 0.0

var color_a: Color
var color_b: Color

var lbl_a: Label
var lbl_b: Label

var is_ending: bool = false
var end_timer: float = 0.0

func setup(a, b):
	army_a = a
	army_b = b
	
	color_a = get_tag_color(army_a.owner_tag)
	color_b = get_tag_color(army_b.owner_tag)
	
	scale = Vector2(0.25, 0.25)
	position = (army_a.position + army_b.position) / 2.0
	position.y -= 18 # closer to flags
	
	z_index = 60
	
	# Setup labels using high font size and internal downscaling for crispness
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

func _process(delta):
	if is_ending:
		end_timer += delta
		modulate.a = max(0.0, 1.0 - end_timer * 2.0)
		if end_timer >= 0.5:
			queue_free()
		return
		
	if not is_instance_valid(army_a) or not is_instance_valid(army_b):
		queue_free()
		return
		
	var main = get_tree().current_scene
	var gs = main.get_node_or_null("GameSession")
	if not gs or gs.is_paused:
		return
		
	var game_speed = gs.speed_hours_per_sec[gs.speed_idx]
	var hours = delta * game_speed
	
	duration_hours_passed += hours
	
	var a_pop = float(army_a.population)
	var b_pop = float(army_b.population)
	
	var a_dmg = (b_pop * 0.05) * (hours / 24.0)
	var b_dmg = (a_pop * 0.05) * (hours / 24.0)
	
	army_a.population = max(0, int(a_pop - a_dmg))
	army_b.population = max(0, int(b_pop - b_dmg))
	
	var total = float(army_a.population + army_b.population)
	if total > 0:
		prog = float(army_a.population) / total
		
	army_a.set_data(army_a.state_id, army_a.population, army_a.owner_tag)
	army_b.set_data(army_b.state_id, army_b.population, army_b.owner_tag)
	
	_update_labels()
	queue_redraw()
	
	if army_a.population <= 0:
		end_battle(army_b, army_a)
	elif army_b.population <= 0:
		end_battle(army_a, army_b)

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

func end_battle(winner, loser):
	is_ending = true
	winner.in_combat = false
	winner.target_army = null
	if loser.has_method("die"):
		loser.die()

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
