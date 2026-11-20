extends RefCounted

# Append into two previously empty cells without resampling any existing texel.
# Every mip is patched separately; the tiny tail mips remain byte-identical.
static func append_flower(original: Image, views: Array[Image], cell: int = 256) -> Dictionary:
	assert(original.get_format() == Image.FORMAT_RGBA8 and original.has_mipmaps())
	assert(original.get_width() == cell*8 and original.get_height() == cell*4 and views.size() == 2)
	var input := original.get_data()
	var data := PackedByteArray()
	var width := original.get_width()
	var height := original.get_height()
	var offset := 0
	var level := 0
	var regions: Array[Dictionary] = []
	while true:
		var length := width*height*4
		var size := cell >> level
		var mip := Image.create_from_data(width,height,false,Image.FORMAT_RGBA8,input.slice(offset,offset+length))
		if size > 0:
			for view in 2:
				var image := views[view].duplicate() as Image
				image.convert(Image.FORMAT_RGBA8)
				image.resize(size,size,Image.INTERPOLATE_LANCZOS)
				var position := Vector2i((26+view)%8,(26+view)/8)*size
				mip.blit_rect(image,Rect2i(0,0,size,size),position)
				regions.append({"mip":level,"cell":26+view,"pixel_rect":[position.x,position.y,size,size]})
		data.append_array(mip.get_data())
		offset+=length
		if width==1 and height==1:
			break
		width=maxi(1,width>>1)
		height=maxi(1,height>>1)
		level+=1
	var extended := Image.create_from_data(original.get_width(),original.get_height(),true,Image.FORMAT_RGBA8,data)
	var before := outside_digest(original,cell)
	var after := outside_digest(extended,cell)
	return {"image":extended,"unchanged_outside_new_cells":before==after,"protected_bytes_sha256_before":before,"protected_bytes_sha256_after":after,"changed_region_mask":regions,"original_rgba_bytes_sha256":_digest(input),"extended_rgba_bytes_sha256":_digest(data)}


static func outside_digest(image: Image, cell: int = 256) -> String:
	var bytes := image.get_data()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	var width := image.get_width()
	var height := image.get_height()
	var level := 0
	var offset := 0
	while true:
		var size := cell>>level
		for row in height:
			var start := offset+row*width*4
			if size>0 and row>=size*3 and row<size*4:
				hash.update(bytes.slice(start,start+size*2*4))
				hash.update(bytes.slice(start+size*4*4,start+width*4))
			else:
				hash.update(bytes.slice(start,start+width*4))
		offset+=width*height*4
		if width==1 and height==1:
			break
		width=maxi(1,width>>1)
		height=maxi(1,height>>1)
		level+=1
	return hash.finish().hex_encode()


static func _digest(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
