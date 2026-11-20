extends SceneTree

const Patch = preload("res://scripts/tools/pilot_foliage_atlas_extension.gd")
var checks:=0
var failures:=0


func _initialize() -> void:
	var original := Image.create(64,32,false,Image.FORMAT_RGBA8)
	for y in original.get_height():
		for x in original.get_width():
			original.set_pixel(x,y,Color(float(x)/64,float(y)/32,float((x+y)%11)/11,1))
	original.generate_mipmaps()
	var first := Image.create(8,8,false,Image.FORMAT_RGBA8)
	first.fill(Color.WHITE)
	var second := Image.create(8,8,false,Image.FORMAT_RGBA8)
	second.fill(Color(0.2,0.3,0.4,0.5))
	var views: Array[Image] = [first,second]
	var before := original.get_data()
	var result := Patch.append_flower(original,views,8)
	var extended: Image = result.image
	_check(result.unchanged_outside_new_cells,"all protected texels outside the two new cells remain byte-identical across mips")
	_check(before==original.get_data(),"patching never mutates the original image")
	_check(before!=extended.get_data() and extended.get_pixel(16,24)==Color.WHITE and result.changed_region_mask.size()==8,"new view regions are populated independently at every cell-sized mip")
	_check(original.get_mipmap_count()==extended.get_mipmap_count() and original.get_size()==extended.get_size(),"atlas dimensions and mip layout remain unchanged")
	var tail:=original.get_mipmap_offset(4)
	_check(before.slice(tail)==extended.get_data().slice(tail),"all tail mip bytes smaller than a cell remain unchanged")
	var altered:=extended.duplicate() as Image
	altered.set_pixel(0,0,Color.WHITE)
	_check(Patch.outside_digest(altered,8)!=result.protected_bytes_sha256_before,"protected digest detects a modification in the original layer region")
	altered=extended.duplicate() as Image
	altered.set_pixel(16,24,Color.BLACK)
	_check(Patch.outside_digest(altered,8)==result.protected_bytes_sha256_before,"protected digest permits modifications only inside the new-cell mask")
	print("Foliage atlas extension: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)


func _check(value:bool,message:String)->void:
	checks+=1
	if value:
		print("PASS: "+message)
	else:
		failures+=1
		push_error(message)
