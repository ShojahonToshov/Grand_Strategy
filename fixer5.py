with open('TopBar.tscn', 'r', encoding='utf-8') as f:
    content = f.read()

ext_gp = '[ext_resource type="Texture2D" path="res://assets/ui/resources/gunpowder.jpg" id="9_gp"]'
ext_prov = '[ext_resource type="Texture2D" path="res://assets/ui/resources/provisions.jpg" id="10_prov"]'

if ext_gp not in content:
    content = content.replace('[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_bg"]', ext_gp + '\n' + ext_prov + '\n\n[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_bg"]')
    with open('TopBar.tscn', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Ext resources added successfully.')
else:
    print('Already there.')
