with open('CameraController.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('''	var cap_res = load("res://capitals.json") as JSON
	if cap_res and cap_res.data.has("FRA"):
		position = Vector2(cap_res.data["FRA"]["x"], cap_res.data["FRA"]["y"])''', '''	var cap_res = load("res://capitals.json") as JSON
	if cap_res and cap_res.data.has("FRA"):
		position = Vector2(cap_res.data["FRA"]["x"], cap_res.data["FRA"]["y"])
		clamp_position()''')

with open('CameraController.gd', 'w', encoding='utf-8') as f:
    f.write(content)
