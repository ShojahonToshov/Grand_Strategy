import re

with open('TopBar.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(r'(\[node name="Canvas".*?tooltip_text = ").*?(")', r'\g<1>Парусина\g<2>', content, flags=re.DOTALL)
content = re.sub(r'(\[node name="Bronze".*?tooltip_text = ").*?(")', r'\g<1>Бронза\g<2>', content, flags=re.DOTALL)
content = re.sub(r'(\[node name="Gunpowder".*?tooltip_text = ").*?(")', r'\g<1>Порох\g<2>', content, flags=re.DOTALL)
content = re.sub(r'(\[node name="Provisions".*?tooltip_text = ").*?(")', r'\g<1>Провизия\g<2>', content, flags=re.DOTALL)

with open('TopBar.tscn', 'w', encoding='utf-8') as f:
    f.write(content)

with open('TopBar.gd', 'r', encoding='utf-8') as f:
    gd = f.read()

gd = re.sub(r'\$Margin/HBox/CenterBox/Resources/Canvas\.tooltip_text = .*', '$Margin/HBox/CenterBox/Resources/Canvas.tooltip_text = "Парусина"', gd)
gd = re.sub(r'\$Margin/HBox/CenterBox/Resources/Bronze\.tooltip_text = .*', '$Margin/HBox/CenterBox/Resources/Bronze.tooltip_text = "Бронза"', gd)
gd = re.sub(r'\$Margin/HBox/CenterBox/Resources/Gunpowder\.tooltip_text = .*', '$Margin/HBox/CenterBox/Resources/Gunpowder.tooltip_text = "Порох"', gd)
gd = re.sub(r'\$Margin/HBox/CenterBox/Resources/Provisions\.tooltip_text = .*', '$Margin/HBox/CenterBox/Resources/Provisions.tooltip_text = "Провизия"', gd)

with open('TopBar.gd', 'w', encoding='utf-8') as f:
    f.write(gd)

print('Tooltips fixed.')
