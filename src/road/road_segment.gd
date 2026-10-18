extends Node2D

enum SegmentType {
	STRAIGHT,
	EXPANSION,
	REDUCTION,
	EXPANDED_2_LANES
}

var segment_type: SegmentType = SegmentType.STRAIGHT
var sprite: Sprite2D = null
var segment_width: float = 0.0
var segment_height: float = 0.0

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)

func setup(type: SegmentType, texture_path: String) -> void:
	segment_type = type
	_load_texture(texture_path)

func _load_texture(path: String) -> void:
	if path.is_empty():
		push_warning("Road segment: caminho vazio para tipo " + str(segment_type))
		_create_placeholder()
		return

	if ResourceLoader.exists(path):
		var texture = load(path)
		if texture:
			sprite.texture = texture
			_update_dimensions()
			return

	push_warning("Road segment: asset nao encontrado: " + path + ". Usando placeholder.")
	_create_placeholder()

func _create_placeholder() -> void:
	var image = Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(Color.GRAY)
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture
	segment_width = 64.0
	segment_height = 64.0

func _update_dimensions() -> void:
	if sprite.texture:
		var size = sprite.texture.get_size()
		segment_width = size.x
		segment_height = size.y

func get_segment_dimensions() -> Vector2:
	return Vector2(segment_width, segment_height)

func get_width() -> float:
	return segment_width

func get_height() -> float:
	return segment_height

func get_boundaries() -> Dictionary:
	match segment_type:
		SegmentType.STRAIGHT:
			return {"left": GameConfig.road_left_boundary, "right": GameConfig.road_right_boundary}
		SegmentType.EXPANSION:
			return {"left": GameConfig.road_left_boundary, "right": GameConfig.road_left_boundary + 176.0}
		SegmentType.REDUCTION:
			return {"left": GameConfig.road_left_boundary, "right": GameConfig.road_left_boundary + 176.0}
		SegmentType.EXPANDED_2_LANES:
			return {"left": GameConfig.road_left_boundary, "right": GameConfig.road_left_boundary + 176.0}
		_:
			return {"left": GameConfig.road_left_boundary, "right": GameConfig.road_right_boundary}
