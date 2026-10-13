extends "res://scripts/world/world_streamer.gd"
func _poll() -> void:
    var requested := []
    for record in records:
        if record.state == "requested":
            requested.append(record.id)
    super._poll()
    for record in records:
        if record.id in requested and record.state == "ready":
            record.renderer_ready_frame = Engine.get_process_frames() + 1
func _activate_one() -> void:
    for record in records:
        if record.state == "ready" and Engine.get_process_frames() < record.get("renderer_ready_frame", 0):
            return
    super._activate_one()
