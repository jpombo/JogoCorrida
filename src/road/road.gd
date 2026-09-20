extends Node2D

## Pool de sprites da estrada
var segment_pool: Array = []

## Tipos de cada segmento no pool
var segment_types: Array = []

## Dimensões do segmento atual
var segment_height: float = 0.0
var segment_width: float = 0.0

## Velocidade de scrolling atual
var scroll_speed: float = 0.0

## Offset total acumulado
var scroll_offset: float = 0.0

## Altura da viewport
var screen_height: float = 480.0

## Limites laterais da estrada
var left_boundary: float = 248.0
var right_boundary: float = 392.0

## Tamanho do pool (calculado automaticamente)
var pool_size: int = 0

## Buffer de segmentos
var segment_buffer: int = 2

## Espaçamento entre segmentos
var segment_spacing: float = 0.0

## Texturas dos segmentos
var straight_texture: Texture2D = null
var expansion_texture: Texture2D = null
var expanded_2_lanes_texture: Texture2D = null
var reduction_texture: Texture2D = null

## Sequência da pista para testes
var track_sequence: Array = []
var track_index: int = 0
var track_count: int = 0
var use_track_sequence: bool = false

## Signals
signal segment_type_changed(new_type: int)
signal boundary_changed(left: float, right: float)

func _ready() -> void:
	left_boundary = GameConfig.road_left_boundary
	right_boundary = GameConfig.road_right_boundary
	segment_buffer = GameConfig.segment_buffer
	segment_spacing = GameConfig.segment_spacing

	# Carregar texturas com fallback
	straight_texture = _load_texture_with_fallback(GameConfig.road_straight_path)
	expansion_texture = _load_texture_with_fallback(GameConfig.road_expansion_path)
	expanded_2_lanes_texture = _load_texture_with_fallback(GameConfig.road_expanded_2_lanes_path)
	reduction_texture = _load_texture_with_fallback(GameConfig.road_reduction_path)

	# Obter dimensões do segmento reto
	if straight_texture:
		var size = straight_texture.get_size()
		segment_width = size.x
		segment_height = size.y
	else:
		segment_width = 64.0
		segment_height = 64.0

	# Calcular tamanho do pool
	if GameConfig.visible_segment_count > 0:
		pool_size = GameConfig.visible_segment_count
	else:
		pool_size = ceil(screen_height / segment_height) + segment_buffer

	# Criar pool de segmentos
	_initialize_pool()
	
	# Carregar sequência de teste se configurada
	if GameConfig.test_track_sequence.size() > 0:
		_load_track_sequence(GameConfig.test_track_sequence)

## Carregar sequência da pista
func _load_track_sequence(sequence: Array) -> void:
	track_sequence = sequence
	track_index = 0
	track_count = 0
	use_track_sequence = true

## Obter próximo tipo de segmento da sequência
func _get_next_segment_type() -> int:
	if not use_track_sequence or track_sequence.size() == 0:
		return 0  # Padrão: STRAIGHT
	
	var entry = track_sequence[track_index]
	var segment_type = entry[0]
	var count = entry[1]
	
	track_count += 1
	if track_count >= count:
		track_count = 0
		track_index = (track_index + 1) % track_sequence.size()
	
	return segment_type

func _initialize_pool() -> void:
	for i in range(pool_size):
		var sprite = Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = straight_texture
		sprite.position.x = left_boundary
		sprite.position.y = i * (segment_height + segment_spacing) - segment_height
		add_child(sprite)
		segment_pool.append(sprite)
		segment_types.append(0)  # STRAIGHT

func _process(delta: float) -> void:
	if scroll_speed > 0:
		# Mover todos os segmentos para baixo
		for sprite in segment_pool:
			sprite.position.y += scroll_speed * delta

		# Acumular offset
		scroll_offset += scroll_speed * delta

		# Reciclar segmentos que saíram da tela
		_recycle_segments()

func _recycle_segments() -> void:
	for i in range(segment_pool.size()):
		var sprite = segment_pool[i]
		# Se o segmento saiu da área visível
		if sprite.position.y > screen_height + segment_height:
			# Encontrar o segmento com menor y (mais acima)
			var min_y = sprite.position.y
			for other in segment_pool:
				if other != sprite and other.position.y < min_y:
					min_y = other.position.y
			
			# Determinar tipo do próximo segmento
			var next_type = _get_next_segment_type()
			var texture = _get_texture_for_type(next_type)
			
			if texture:
				sprite.texture = texture
				segment_types[i] = next_type
			
			# Posicionar logo acima do segmento mais alto
			sprite.position.y = min_y - segment_height - segment_spacing

## Obter textura para um tipo de segmento
func _get_texture_for_type(type: int) -> Texture2D:
	match type:
		0:  # STRAIGHT
			return straight_texture
		1:  # EXPANSION
			return expansion_texture
		2:  # REDUCTION
			return reduction_texture
		3:  # EXPANDED_2_LANES
			return expanded_2_lanes_texture
	return straight_texture

## Obter limites laterais baseado na posição Y do jogador
## Para segmentos de transição (EXPANSION/REDUCTION), utiliza interpolação linear
## criando uma área de movimentação trapezoidal
func get_boundaries_for_player_y(player_y: float) -> Dictionary:
	for i in range(segment_pool.size()):
		var sprite = segment_pool[i]
		var seg_top = sprite.position.y
		var seg_bottom = sprite.position.y + segment_height
		
		if player_y >= seg_top and player_y < seg_bottom:
			var type = segment_types[i]
			var narrow_right = GameConfig.road_left_boundary + 144.0  # 2 vias
			var wide_right = GameConfig.road_left_boundary + 176.0    # 4 vias
			
			match type:
				0:  # STRAIGHT (2 vias)
					return {"left": GameConfig.road_left_boundary, "right": narrow_right}
				1:  # EXPANSION (2→4 vias): interpola de 144 para 176
					var t = 1.0 - (player_y - seg_top) / segment_height
					return {"left": GameConfig.road_left_boundary, "right": lerpf(narrow_right, wide_right, t)}
				2:  # REDUCTION (4→2 vias): interpola de 176 para 144
					var t = 1.0 - (player_y - seg_top) / segment_height
					return {"left": GameConfig.road_left_boundary, "right": lerpf(wide_right, narrow_right, t)}
				3:  # EXPANDED_2_LANES (4 vias)
					return {"left": GameConfig.road_left_boundary, "right": wide_right}
	
	return {"left": GameConfig.road_left_boundary, "right": GameConfig.road_right_boundary}

## Atualizar velocidade de scrolling (chamado pelo gameplay_manager)
func update_scroll_speed(player_speed: float) -> void:
	scroll_speed = player_speed * GameConfig.scroll_multiplier

## Adicionar segmento de um tipo específico
func add_segment(type: int) -> void:
	var texture: Texture2D = null
	match type:
		0:  # STRAIGHT
			texture = straight_texture
		1:  # EXPANSION
			texture = expansion_texture
		2:  # REDUCTION
			texture = reduction_texture
		3:  # EXPANDED_2_LANES
			texture = expanded_2_lanes_texture

	if texture:
		# Encontrar último segmento para posicionar depois dele
		var last_y = -segment_height
		for sprite in segment_pool:
			if sprite.position.y > last_y:
				last_y = sprite.position.y

		# Criar novo segmento
		var sprite = Sprite2D.new()
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.texture = texture
		sprite.position.x = left_boundary
		sprite.position.y = last_y + segment_height
		add_child(sprite)
		segment_pool.append(sprite)
		segment_types.append(type)

		# Emitir signal
		segment_type_changed.emit(type)

## Carregar textura com fallback para assets ausentes
func _load_texture_with_fallback(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var texture = load(path)
		if texture:
			return texture
	
	# Fallback: quadrado cinza 32x32
	push_warning("Road asset not found: " + path + " — using placeholder")
	var placeholder = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	placeholder.fill(Color(0.5, 0.5, 0.5))
	return ImageTexture.create_from_image(placeholder)

## Atualizar limites laterais baseado no tipo do segmento
func _update_boundaries(type: int) -> void:
	match type:
		0:  # STRAIGHT (2-vias)
			left_boundary = GameConfig.road_left_boundary
			right_boundary = GameConfig.road_right_boundary
		1:  # EXPANSION (2→4 vias)
			left_boundary = GameConfig.road_left_boundary
			right_boundary = GameConfig.road_left_boundary + expansion_texture.get_width()
		2:  # REDUCTION (4→2 vias — transição visual)
			left_boundary = GameConfig.road_left_boundary
			right_boundary = GameConfig.road_left_boundary + reduction_texture.get_width()
		3:  # EXPANDED_2_LANES (pista expandida)
			left_boundary = GameConfig.road_left_boundary
			right_boundary = GameConfig.road_left_boundary + expanded_2_lanes_texture.get_width()

	boundary_changed.emit(left_boundary, right_boundary)

## Obter limites laterais atuais
func get_left_boundary() -> float:
	return left_boundary

func get_right_boundary() -> float:
	return right_boundary

func get_road_width() -> float:
	return right_boundary - left_boundary
