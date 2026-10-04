import re

# 1. Update BalanceConfig.gd
with open('BalanceConfig.gd', 'r', encoding='utf-8') as f:
    bc = f.read()
if 'START_GUNPOWDER' not in bc:
    bc = bc.replace('const START_SCIENCE = 0.0', 'const START_SCIENCE = 0.0\nconst START_GUNPOWDER = 0.0\nconst START_PROVISIONS = 500.0')
    with open('BalanceConfig.gd', 'w', encoding='utf-8') as f:
        f.write(bc)

# 2. Update GameSession.gd
with open('GameSession.gd', 'r', encoding='utf-8') as f:
    gs = f.read()
if 'var gunpowder' not in gs:
    gs = gs.replace('var canvas: float = BalanceConfig.START_CANVAS', 'var canvas: float = BalanceConfig.START_CANVAS\nvar gunpowder: float = BalanceConfig.START_GUNPOWDER\nvar provisions: float = BalanceConfig.START_PROVISIONS')
    gs = gs.replace('var income_canvas: float = 0.0', 'var income_canvas: float = 0.0\n\tvar income_gunpowder: float = 0.0\n\tvar income_provisions: float = 0.0')
    gs = gs.replace('canvas += income_canvas', 'canvas += income_canvas\n\tgunpowder += income_gunpowder\n\tprovisions += income_provisions')
    with open('GameSession.gd', 'w', encoding='utf-8') as f:
        f.write(gs)

# 3. Update TopBar.gd
with open('TopBar.gd', 'r', encoding='utf-8') as f:
    tb = f.read()
if 'Gunpowder' not in tb:
    tb = tb.replace('$Margin/HBox/CenterBox/Resources/Canvas/Label.text = _format_res(session.canvas)', '$Margin/HBox/CenterBox/Resources/Canvas/Label.text = _format_res(session.canvas)\n\t$Margin/HBox/CenterBox/Resources/Gunpowder/Label.text = _format_res(session.gunpowder)\n\t$Margin/HBox/CenterBox/Resources/Provisions/Label.text = _format_res(session.provisions)')
    with open('TopBar.gd', 'w', encoding='utf-8') as f:
        f.write(tb)

# 4. Update TopBar.tscn
with open('TopBar.tscn', 'r', encoding='utf-8') as f:
    tscn = f.read()
if 'name="Gunpowder"' not in tscn:
    canvas_pattern = re.compile(r'(\[node name="Canvas" type="HBoxContainer" parent="Margin/HBox/CenterBox/Resources"\].*?(?=\n\[node))', re.DOTALL)
    match = canvas_pattern.search(tscn)
    if match:
        canvas_block = match.group(1)
        gp_block = canvas_block.replace('name="Canvas"', 'name="Gunpowder"').replace('canvas.png', 'gunpowder.jpg')
        prov_block = canvas_block.replace('name="Canvas"', 'name="Provisions"').replace('canvas.png', 'provisions.jpg')
        tscn = tscn.replace(canvas_block, canvas_block + '\n' + gp_block + '\n' + prov_block)
        with open('TopBar.tscn', 'w', encoding='utf-8') as f:
            f.write(tscn)
print('All scripts updated.')
