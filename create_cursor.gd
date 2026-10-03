extends SceneTree

func _init():
	var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	
	# Draw first sword (top-left to bottom-right)
	for i in range(4, 28):
		img.set_pixel(i, i, Color(1, 0, 0, 1))
		img.set_pixel(i+1, i, Color(0.8, 0, 0, 1))
		img.set_pixel(i, i+1, Color(0.8, 0, 0, 1))
		
		# Outlines
		img.set_pixel(i-1, i, Color(0, 0, 0, 1))
		img.set_pixel(i, i-1, Color(0, 0, 0, 1))
		img.set_pixel(i+2, i, Color(0, 0, 0, 1))
		img.set_pixel(i, i+2, Color(0, 0, 0, 1))

	# Draw second sword (bottom-left to top-right)
	for i in range(4, 28):
		var y = 31 - i
		img.set_pixel(i, y, Color(1, 0, 0, 1))
		img.set_pixel(i+1, y, Color(0.8, 0, 0, 1))
		img.set_pixel(i, y-1, Color(0.8, 0, 0, 1))
		
		# Outlines
		img.set_pixel(i-1, y, Color(0, 0, 0, 1))
		img.set_pixel(i, y+1, Color(0, 0, 0, 1))
		img.set_pixel(i+2, y, Color(0, 0, 0, 1))
		img.set_pixel(i, y-2, Color(0, 0, 0, 1))
		
	# Handles
	for x in range(3, 7):
		for y in range(3, 7):
			img.set_pixel(x, y, Color(0.2, 0.2, 0.2, 1))
			img.set_pixel(31-x, y, Color(0.2, 0.2, 0.2, 1))
			img.set_pixel(x, 31-y, Color(0.2, 0.2, 0.2, 1))
			img.set_pixel(31-x, 31-y, Color(0.2, 0.2, 0.2, 1))

	img.save_png(\
res://attack_cursor.png\)
	print(\Cursor
generated
successfully.\)
	quit()

