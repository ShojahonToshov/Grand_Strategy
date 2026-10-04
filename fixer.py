import re

with open('TopBar.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

ext_gp = '[ext_resource type="Texture2D" uid="uid://x" path="res://assets/ui/resources/gunpowder.jpg" id="9_gp"]\n'
ext_prov = '[ext_resource type="Texture2D" uid="uid://y" path="res://assets/ui/resources/provisions.jpg" id="10_prov"]\n'

if '9_gp' not in content:
    content = content.replace('[node name="Main"', ext_gp + ext_prov + '\n[node name="Main"')

missing_nodes_gp = '''
[node name="Icon" type="TextureRect" parent="Margin/HBox/CenterBox/Resources/Gunpowder"]
custom_minimum_size = Vector2(28, 28)
layout_mode = 2
size_flags_vertical = 4
texture = ExtResource("9_gp")
expand_mode = 1
stretch_mode = 5

[node name="Label" type="Label" parent="Margin/HBox/CenterBox/Resources/Gunpowder"]
custom_minimum_size = Vector2(48, 0)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "0"
vertical_alignment = 1
'''

missing_nodes_prov = '''
[node name="Icon" type="TextureRect" parent="Margin/HBox/CenterBox/Resources/Provisions"]
custom_minimum_size = Vector2(28, 28)
layout_mode = 2
size_flags_vertical = 4
texture = ExtResource("10_prov")
expand_mode = 1
stretch_mode = 5

[node name="Label" type="Label" parent="Margin/HBox/CenterBox/Resources/Provisions"]
custom_minimum_size = Vector2(48, 0)
layout_mode = 2
theme_override_font_sizes/font_size = 20
text = "0"
vertical_alignment = 1
'''

if 'parent="Margin/HBox/CenterBox/Resources/Gunpowder"' not in content:
    content += missing_nodes_gp + missing_nodes_prov
    with open('TopBar.tscn', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Nodes added to TopBar.tscn')
