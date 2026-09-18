extends SceneTree
func _init():
    var main = load("res://Main.tscn").instantiate()
    root.add_child(main)
    
    var t = Timer.new()
    t.wait_time = 0.5
    t.autostart = true
    t.one_shot = true
    t.timeout.connect(func():
        var hs = main.get_node("HighlightSystem")
        hs.set_highlight("363", "lod0", "STATES") # North Carolina
        
        var t2 = Timer.new()
        t2.wait_time = 0.5
        t2.autostart = true
        t2.one_shot = true
        t2.timeout.connect(func():
            print("Finished successfully")
            quit()
        )
        root.add_child(t2)
    )
    root.add_child(t)

