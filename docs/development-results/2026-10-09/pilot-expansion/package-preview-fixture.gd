extends SceneTree
func _initialize() -> void:
 _run.call_deferred()
func _run() -> void:
 if not FileAccess.file_exists("res://project.binary") or FileAccess.file_exists("res://project.godot"):
  quit(1)
  return
 root.get_node("WaveSettings").set_graphics_preset("medium")
 change_scene_to_file("res://scenes/city/drive_pilot_city.tscn")
 await scene_changed
 for frame in 20:
  await process_frame
 await RenderingServer.frame_post_draw
 var city := current_scene.get_node("City")
 print("Exported city: %d blocks, %d parcels, %.0f m2" % [city.get_meta("block_count"), city.get_meta("parcel_count"), city.get_meta("area_m2")])
 root.get_texture().get_image().save_png("/home/otavio/Projects/Wave/docs/art-results/2026-10-09/pilot-expansion/package-driving.png")
 current_scene.queue_free()
 await process_frame
 quit(0)
