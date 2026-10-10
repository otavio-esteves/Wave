extends RefCounted

# Preserve every authored triangle. Only its owner changes; seams are never
# retriangulated, so rendering and swept collision keep the same road surface.
const WIDTH := 128.0

class Faces extends RefCounted:
	var vertices := PackedVector3Array()


static func key(a: Vector3, b: Vector3, c: Vector3) -> Vector2i:
	var centre := (a + b + c) / 3.0
	return Vector2i(floori(centre.x / WIDTH), floori(centre.z / WIDTH))


static func split(vertices: PackedVector3Array) -> Dictionary:
	var chunks: Dictionary = {}
	for index in range(0, vertices.size(), 3):
		var tile := key(vertices[index], vertices[index + 1], vertices[index + 2])
		if not chunks.has(tile):
			chunks[tile] = Faces.new()
		var faces: Faces = chunks[tile]
		faces.vertices.append(vertices[index])
		faces.vertices.append(vertices[index + 1])
		faces.vertices.append(vertices[index + 2])
	return chunks
