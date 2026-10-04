with open('StateInfoPanel.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('\n\t\telif b_type == "WEAVER_WORKSHOP": rname = "Парусина"', '\n\telif b_type == "WEAVER_WORKSHOP": rname = "Парусина"\n\telif b_type == "FARM": rname = "Провизия"\n\telif b_type == "POWDER_MILL": rname = "Порох"')

with open('StateInfoPanel.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed WEAVER_WORKSHOP indentation in modal.')
