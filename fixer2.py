with open('TopBar.tscn', 'r', encoding='utf-8') as f:
    lines = f.read().split('\n')

clean_lines = []
for line in lines:
    if line.startswith('[node name="Icon" type="TextureRect" parent="Margin/HBox/CenterBox/Resources/Gunpowder"]'):
        break
    clean_lines.append(line)

content = '\n'.join(clean_lines)

pattern = '[node name="Label" type="Label" parent="Margin/HBox/CenterBox/Resources/Canvas"]\ncustom_minimum_size = Vector2(48, 0)\nlayout_mode = 2\ntheme_override_font_sizes/font_size = 20\ntext = "0"\nvertical_alignment = 1'

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

if pattern in content:
    content = content.replace(pattern, pattern + '\n' + missing_nodes_gp + '\n' + missing_nodes_prov)
    with open('TopBar.tscn', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Fixed tscn ordering.')
else:
    print('Pattern not found!')
