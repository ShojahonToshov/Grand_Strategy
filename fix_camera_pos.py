import re

with open('CameraController.gd', 'r', encoding='utf-8') as f:
    content = f.read()

pattern = r'position = Vector2\(cap_res\.data\["FRA"\]\["x"\], cap_res\.data\["FRA"\]\["y"\]\)'
replacement = '''var vsize = get_viewport_rect().size / zoom
		position = Vector2(cap_res.data["FRA"]["x"], cap_res.data["FRA"]["y"]) - vsize / 2.0'''

content = re.sub(pattern, replacement, content)

with open('CameraController.gd', 'w', encoding='utf-8') as f:
    f.write(content)
