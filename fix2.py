with open('StateInfoPanel.gd', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('\t\t_create_build_card_modal("WEAVER_WORKSHOP"', '\t_create_build_card_modal("WEAVER_WORKSHOP"')

with open('StateInfoPanel.gd', 'w', encoding='utf-8') as f:
    f.write(content)
print('Fixed WEAVER_WORKSHOP indentation.')
