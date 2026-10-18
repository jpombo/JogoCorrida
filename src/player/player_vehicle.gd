class_name PlayerVehicle
extends CharacterBody2D

## Controlador do veículo
var controller: VehicleController = VehicleController.new()

## Sprite do veículo
@onready var sprite: Sprite2D = $Sprite2D

## Collision shape
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

## Caminho do sprite atual
var current_sprite_path: String = ""

func _ready() -> void:
	_load_sprite(GameConfig.default_sprite_path)
	_set_initial_position()

func _process(delta: float) -> void:
	controller._process(delta)
	_apply_vertical_position()
	_apply_lateral_position()
	_clamp_position()

## Carregar sprite com fallback
func _load_sprite(path: String) -> void:
	if ResourceLoader.exists(path):
		var texture = load(path)
		if texture:
			sprite.texture = texture
			current_sprite_path = path
			return
	push_warning("Sprite não encontrado: " + path + ". Usando placeholder.")
	_create_placeholder()

## Criar placeholder visual (quadrado colorido)
func _create_placeholder() -> void:
	var image = Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLUE)
	var texture = ImageTexture.create_from_image(image)
	sprite.texture = texture

## Definir posição inicial
func _set_initial_position() -> void:
	# Centralizar o carro na pista
	position.x = (GameConfig.road_left_boundary + GameConfig.road_right_boundary) / 2.0
	# Offset para alinhar base do carro com a posição (metade da altura do carro = 24px)
	position.y = GameConfig.initial_vertical_position * 480.0 - 24.0

## Aplicar posição Y baseada na velocidade
func _apply_vertical_position() -> void:
	var vertical_pos = controller.get_vertical_position()
	# Offset para alinhar base do carro com a posição (metade da altura do carro = 24px)
	position.y = vertical_pos * 480.0 - 24.0

## Aplicar posição X baseada no movimento lateral
func _apply_lateral_position() -> void:
	position.x += controller.lateral_speed * get_process_delta_time()

## Respeitar limites da estrada
func _clamp_position() -> void:
	position.x = controller._clamp_position(position.x)

## Trocar sprite dinamicamente
func change_sprite(path: String) -> void:
	_load_sprite(path)

## Obter velocidade atual (para uso externo)
func get_speed() -> float:
	return controller.speed


## Reset de corrida (SPEC-008, FR-035, research R10): física, flag de
## combustível, limites e posição inicial. O sprite é reaplicado pelo
## GameplayManager na largada (seleção de veículo da sessão).
func reset() -> void:
	controller.reset()
	_set_initial_position()
