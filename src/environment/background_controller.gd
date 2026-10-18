extends Node2D

## Controla a renderização e scroll vertical do background do ambiente.
## Utiliza pool de 2 Sprite2D com reciclagem vertical para scroll contínuo.
## Os assets de background possuem resolução 640x480 (mesma da viewport).

var sprite_top: Sprite2D
var sprite_bottom: Sprite2D
var texture_height: float = 0.0
var current_texture: Texture2D = null

func _ready() -> void:
	sprite_top = Sprite2D.new()
	sprite_top.name = "BackgroundTop"
	sprite_top.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_top.centered = true
	add_child(sprite_top)

	sprite_bottom = Sprite2D.new()
	sprite_bottom.name = "BackgroundBottom"
	sprite_bottom.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_bottom.centered = true
	add_child(sprite_bottom)

func set_texture(path: String) -> void:
	var tex: Texture2D = null

	if ResourceLoader.exists(path):
		tex = load(path)
	else:
		push_warning("BackgroundController: Textura não encontrada '%s'. Usando fallback para PLAINS." % path)
		var fallback_path = GameConfig.ENVIRONMENTS["PLAINS"]["texture_path"]
		if ResourceLoader.exists(fallback_path):
			tex = load(fallback_path)

	if tex == null:
		push_warning("BackgroundController: Nenhuma textura disponível para background.")
		return

	current_texture = tex
	texture_height = tex.get_height()

	sprite_top.texture = tex
	sprite_bottom.texture = tex

	# Asset já dimensionado (640x480) — sem escala para evitar perda de qualidade
	sprite_top.scale = Vector2.ONE
	sprite_bottom.scale = Vector2.ONE

	_position_sprites_initial()

func _position_sprites_initial() -> void:
	if texture_height <= 0:
		return

	sprite_top.position = Vector2(320, texture_height * 0.5)
	sprite_bottom.position = Vector2(320, texture_height * 1.5)

func update_scroll(road_speed: float, delta: float) -> void:
	if texture_height <= 0 or current_texture == null:
		return

	var bg_speed = road_speed * GameConfig.background_multiplier
	var displacement = bg_speed * delta

	sprite_top.position.y += displacement
	sprite_bottom.position.y += displacement

	_recycle_sprites()

func _recycle_sprites() -> void:
	if texture_height <= 0:
		return

	# Se o sprite superior saiu completamente pela parte inferior
	if sprite_top.position.y - texture_height * 0.5 > 480:
		sprite_top.position.y = sprite_bottom.position.y - texture_height

	# Se o sprite inferior saiu completamente pela parte inferior
	if sprite_bottom.position.y - texture_height * 0.5 > 480:
		sprite_bottom.position.y = sprite_top.position.y - texture_height

func reset() -> void:
	_position_sprites_initial()
