extends Node

## Parâmetros de física do veículo
@export var max_speed: float = 100.0
@export var acceleration: float = 40.0
@export var brake_force: float = 70.0
@export var natural_deceleration: float = 15.0

## Parâmetros de movimento lateral
@export var lateral_speed: float = 100.0
@export var lateral_acceleration: float = 300.0
@export var lateral_deceleration: float = 400.0

## Posição vertical
@export var initial_vertical_position: float = 0.95  # Inicia quase na base (com margem)
@export var vertical_position_min: float = 0.6  # Topo: 1 tamanho do carro abaixo do meio (288/480)
@export var vertical_position_max: float = 0.95  # Base: com margem para o sprite completo

## Limites da estrada (pista de 2 vias centralizada — largura 144px, centro 320)
@export var road_left_boundary: float = 248.0
@export var road_right_boundary: float = 392.0

## Performance
@export var target_fps: int = 60

## Assets
@export var default_sprite_path: String = "res://assets/player/azul/azul.png"
@export var alt_sprite_path: String = "res://assets/player/vermelho/vermelho.png"

## Scrolling da estrada
@export var scroll_multiplier: float = 1.0  # Fator entre velocidade do jogador e scrolling
@export var visible_segment_count: int = 0  # Quantidade de segmentos (0 = cálculo automático)
@export var segment_buffer: int = 2  # Segmentos extras além dos visíveis
@export var segment_spacing: float = 0.0  # Espaçamento entre segmentos (0 = sem espaço)
@export var road_straight_path: String = "res://assets/estrada/estrada_2_vias.png"
@export var road_expansion_path: String = "res://assets/estrada/estrada_expansao_4_vias.png"
@export var road_expanded_2_lanes_path: String = "res://assets/estrada/estrada_2_vias_expandido.png"
@export var road_reduction_path: String = "res://assets/estrada/estrada_reducao_2_vias.png"

## Ambientes
@export var current_environment_id: String = "PLAINS"
@export var background_multiplier: float = 0.6

## Dicionário centralizado de ambientes — cada entrada é um Dictionary com id, display_name, texture_path, difficulty
var ENVIRONMENTS: Dictionary = {
	"PLAINS": { "id": "PLAINS", "display_name": "Planície", "texture_path": "res://assets/background/Seamless Pixel Art Grass Texture.png", "difficulty": 1 },
	"DESERT": { "id": "DESERT", "display_name": "Deserto", "texture_path": "res://assets/background/Pixel Art Desert Sand Texture.png", "difficulty": 2 },
	"FOREST": { "id": "FOREST", "display_name": "Floresta", "texture_path": "res://assets/background/Pixel Art Forest Floor Texture.png", "difficulty": 3 },
	"ICE": { "id": "ICE", "display_name": "Gelo", "texture_path": "res://assets/background/Pixel Art Snowy Ice Texture.png", "difficulty": 4 },
}

## Sequência de teste da pista (tipos: 0=STRAIGHT, 1=EXPANSION, 2=REDUCTION, 3=EXPANDED_2_LANES)
## Formato: [tipo, quantidade]
@export var test_track_sequence: Array = [
	[0, 10],  # 10 segmentos retos (2 vias)
	[1, 1],   # 1 segmento de expansão (2→4 vias)
	[3, 10],  # 10 segmentos expandidos (2 vias expandidas)
	[2, 1],   # 1 segmento de redução (4→2 vias)
]

# ---------------------------------------------------------------------------
# SPEC-004 — Sistema de Trânsito e Decoração
# ---------------------------------------------------------------------------

## Conversão de km/h para as unidades de física do jogo (research.md R2)
## 100 unidades = 125 km/h, portanto 1 km/h = 0.8 unidades.
## Ancorar o jogador em 125 km/h mantém GameConfig.max_speed em 100.0,
## preservando as constantes já calibradas do SPEC-001.
const KMH_TO_SPEED_UNIT: float = 0.8

## Categorias de veículos de trânsito.
## Cada entrada vira um TrafficData (src/traffic/traffic_data.gd).
## `assets` lista os arquivos sem extensão; a pasta é exclusiva da categoria (FR-012).
## `frequency` é a frequência relativa de spawn e é um parâmetro de ajuste (FR-023).
var TRAFFIC_CATEGORIES: Dictionary = {
	"caminhao": {
		"id": "caminhao",
		"display_name": "Caminhão",
		"assets_path": "res://assets/npcs/caminhao/",
		"assets": ["caminhao_madeireiro"],
		"max_speed_kmh": 90.0,
		"frequency": 0.15,
	},
	"utilitario": {
		"id": "utilitario",
		"display_name": "Utilitário",
		"assets_path": "res://assets/npcs/utilitario/",
		"assets": ["Carro-prata", "carro_03", "carro_05", "carro_06", "carro_08", "carro_11", "carro_12"],
		"max_speed_kmh": 90.0,
		"frequency": 0.25,
	},
	"passeio": {
		"id": "passeio",
		"display_name": "Passeio",
		"assets_path": "res://assets/npcs/passeio/",
		"assets": ["carro_01", "carro_02", "carro_04", "carro_07", "carro_09", "carro_10"],
		"max_speed_kmh": 100.0,
		"frequency": 0.35,
	},
	"esporte": {
		"id": "esporte",
		"display_name": "Esporte",
		"assets_path": "res://assets/npcs/esporte/",
		"assets": ["carro-amarelo", "carro-laranja", "carro-verde"],
		"max_speed_kmh": 120.0,
		"frequency": 0.25,
	},
}

## Parâmetros de ajuste do trânsito (FR-023). Todos são somente leitura em runtime:
## a dificuldade do SPEC-008 adjusta frequência, densidade e quantidade, nunca identidade.
@export var traffic_enabled: bool = true
@export var traffic_max_vehicles: int = 12
@export var traffic_spawn_distance: float = 80.0
## Variação vertical da faixa de nascimento acima da tela (px). Só separa
## visualmente quem já vai entrar — a separação de retângulos no birth é
## garantida por `traffic_min_separation`.
@export var traffic_spawn_distance_variance: float = 120.0
## Distância de reposição acima da tela durante o enchimento (px): curta de
## propósito — quem sai por baixo é reposto no topo quase de imediato.
@export var traffic_spawn_fill_distance: float = 40.0
@export var traffic_spawn_interval: float = 1.2
@export var traffic_min_spacing: float = 70.0
## Separação mínima (px) entre as bordas de dois veículos de trânsito, em
## qualquer eixo: impede que NPCs nasçam colados ou sobrepostos entre si.
@export var traffic_min_separation: float = 12.0

## Densidade de trânsito visível (ajuste 3/4): mínimo de NPCs com pixel na
## tela a perseguir em ritmo acelerado de spawn, e máximo de NPCs ATIVOS
## (visíveis + a caminho) por nível de dificuldade do ambiente
## (ENVIRONMENTS[id].difficulty: 1=Planície ... 4=Gelo) — como todo ativo
## acaba entrando na tela, o teto de ativos é o que garante o teto de visíveis.
## É dado de configuração: o SPEC-008 poderá reescrever estes valores.
@export var traffic_min_visible: int = 3
var traffic_max_visible_by_difficulty: Dictionary = { 1: 5, 2: 5, 3: 5, 4: 5 }
## Intervalo de spawn quando abaixo do mínimo visível (enchimento gradual,
## um por vez — nunca em lote).
@export var traffic_spawn_interval_filling: float = 0.35

## Bibliotecas de decoração por ambiente.
## Cada entrada vira um DecorationData (src/decoration/decoration_data.gd).
## `repeatable` é DADO DE CONFIGURAÇÃO, nunca deduzido do nome do arquivo em runtime
## (research.md R3, constitution v2.0.0 §Independência de Assets, FR-036).
## `weight` é o PERCENTUAL DE APRESENTAÇÃO do elemento dentro do ambiente, em pontos
## percentuais que somam 100 por biblioteca: define a chance relativa do elemento
## nascer quando há mais de um candidato elegível (FR-036, FR-037).
## Quando um ambiente tem dois assets de árvore, o percentual da árvore é dividido
## igualmente entre eles (Deserto 73% -> 36.5 + 36.5; Floresta 96% -> 48 + 48).
## A lista é explícita — `DirAccess` só é usado em modo debug para comparar (R4).
var DECORATION_LIBRARIES: Dictionary = {
	"PLAINS": [
		{ "asset": "planice_arvore01", "repeatable": true, "weight": 80.0 },
		{ "asset": "planice_casa01", "repeatable": false, "weight": 5.0 },
		{ "asset": "planice_feno01", "repeatable": false, "weight": 7.0 },
		{ "asset": "planice_milho", "repeatable": false, "weight": 6.0 },
		{ "asset": "planice_silo01", "repeatable": false, "weight": 2.0 },
	],
	"DESERT": [
		{ "asset": "deserto_arvore01", "repeatable": true, "weight": 36.5 },
		{ "asset": "deserto_arvore02", "repeatable": true, "weight": 36.5 },
		{ "asset": "deserto_cactus", "repeatable": false, "weight": 20.0 },
		{ "asset": "deserto_duna", "repeatable": false, "weight": 5.0 },
		{ "asset": "deserto_casa", "repeatable": false, "weight": 2.0 },
	],
	"FOREST": [
		{ "asset": "floresta_arvore01", "repeatable": true, "weight": 48.0 },
		{ "asset": "floresta_arvore02", "repeatable": true, "weight": 48.0 },
		{ "asset": "floresta_lago", "repeatable": false, "weight": 3.0 },
		{ "asset": "floresta_serra", "repeatable": false, "weight": 1.0 },
	],
	"ICE": [
		{ "asset": "gelo_arvore", "repeatable": true, "weight": 96.0 },
		{ "asset": "gelo_boneco", "repeatable": false, "weight": 3.0 },
		{ "asset": "gelo_casa01", "repeatable": false, "weight": 1.0 },
	],
}

## Pastas de assets de decoração por ambiente.
## Declaradas explicitamente porque o identificador do ambiente e o nome da pasta não
## coincidem para PLAINS (`PLAINS` -> `planice`). Derivar a pasta do id exigiria
## comparação de string em runtime, o que a constitution v2.0.0
## §Independência de Assets proíbe e research.md R3 descarta.
var DECORATION_PATHS: Dictionary = {
	"PLAINS": "res://assets/decoracao/planice/",
	"DESERT": "res://assets/decoracao/deserto/",
	"FOREST": "res://assets/decoracao/floresta/",
	"ICE": "res://assets/decoracao/gelo/",
}

## Parâmetros de ajuste da decoração (FR-056).
@export var decoration_enabled: bool = true
@export var decoration_density: float = 1.0
@export var decoration_speed_multiplier: float = 0.85
@export var decoration_spacing_min: float = 90.0
@export var decoration_spacing_max: float = 180.0
@export var decoration_depth_count: int = 3
@export var decoration_depth_spacing: float = 52.0
@export var decoration_scale: float = 1.0
@export var decoration_safety_margin: float = 24.0
@export var decoration_tree_repeat_limit: int = 10

# ---------------------------------------------------------------------------
# SPEC-005 — Sistema de Colisão e Drift
# ---------------------------------------------------------------------------
# Todos os parâmetros de colisão/drift são ajustáveis sem alteração de código
# (FR-035, SC-012); nenhum deles pode aparecer fixo na lógica.

## Perda de velocidade do jogador na colisão (unidades de velocidade internas)
@export var collision_speed_loss_min: float = 10.0
@export var collision_speed_loss_max: float = 45.0

## Tempo (s) após a colisão em que a aceleração do jogador é desconsiderada
## (ajuste 4): sem isso, quem segura o acelera recomposta a perda no mesmo
## instante e a "empurrada para trás" do impacto some — o jogador parecia
## voltar direto à posição de antes. A frenagem continua valendo.
@export var collision_accel_lockout_time: float = 0.8

## Drift do jogador (deslocamento lateral do impacto e controle reduzido)
@export var drift_force_min: float = 60.0    # px/s de deslocamento no impacto mínimo
@export var drift_force_max: float = 180.0   # px/s no impacto máximo
@export var drift_duration_min: float = 0.4  # segundos
@export var drift_duration_max: float = 1.2  # segundos
@export var drift_control_factor: float = 0.4  # resposta lateral durante o drift (SC-004)
@export var drift_recovery_rate: float = 1.2   # fator de controle recuperado por segundo

## Cooldown por par jogador↔NPC (segundos)
@export var collision_cooldown_time: float = 0.8

## Margem neutra da posição relativa, em px (FR-005)
@export var collision_neutral_margin: float = 4.0

## Ultrapassagem do NPC na colisão tipo 1-3 (FR-018, FR-019)
@export var npc_overtake_magnitude: float = 40.0  # px laterais
@export var npc_overtake_duration: float = 1.0    # segundos (ida até o ponto de ultrapassagem)
## Retorno do NPC à faixa de origem após a ida (FR-021, ajuste 6): sem ele o
## NPC ficava deslocado para sempre, invadindo o corredor de outra velocidade.
@export var npc_overtake_return_duration: float = 1.0  # segundos

## Divisor de normalização da intensidade (velocidade relativa → 0..1, R8)
@export var collision_intensity_divisor: float = 100.0

## Hitbox do jogador (largura x altura, centrada na posição) — independente do sprite (FR-006)
@export var player_hitbox_size: Vector2 = Vector2(24.0, 40.0)

## Hitboxes por categoria de NPC (independentes dos sprites — FR-007, FR-008).
## Categoria ausente cai no retângulo de `get_occupied_area()` como fallback.
var NPC_HITBOX_SIZES: Dictionary = {
	"caminhao": Vector2(30.0, 64.0),
	"utilitario": Vector2(24.0, 44.0),
	"passeio": Vector2(24.0, 42.0),
	"esporte": Vector2(26.0, 38.0),
}

## Agrupamentos de parâmetros expostos ao SPEC-008 (FR-061, data-model.md §8).
## Somente leitura nesta versão: o SPEC-004 expõe a estrutura, o SPEC-008 resolve a dificuldade.
## As chaves individuais acima continuam válidas — são uma projeção, não uma substituição.
var traffic_tuning: Dictionary = {}
var decoration_tuning: Dictionary = {}

func _ready() -> void:
	_build_tuning_groups()
	_verificar_consistencia_de_assets()


## R4 / T050 — compara cada lista `assets` com o conteúdo real da pasta.
## Roda APENAS em build de debug, emite `push_warning` na divergência e nunca
## participa de lógica de gameplay: é diagnóstico de authoring, não regra de
## runtime (research.md R4, constitution v2.0.0 §Independência de Assets).
func _verificar_consistencia_de_assets() -> void:
	if not OS.is_debug_build():
		return

	for id in TRAFFIC_CATEGORIES:
		var entrada: Dictionary = TRAFFIC_CATEGORIES[id]
		_conferir_pasta(
			String(entrada.get("assets_path", "")),
			entrada.get("assets", []) as Array,
			"trânsito/" + str(id)
		)

	for ambiente in DECORATION_LIBRARIES:
		var declarados: Array = []
		for item in DECORATION_LIBRARIES[ambiente]:
			declarados.append(String(item.get("asset", "")))
		_conferir_pasta(
			String(DECORATION_PATHS.get(ambiente, "")), declarados, "decoração/" + str(ambiente)
		)


## Avisa sobre asset declarado ausente e sobre arquivo não declarado na pasta.
func _conferir_pasta(pasta: String, declarados: Array, rotulo: String) -> void:
	if pasta.is_empty():
		return

	var dir: DirAccess = DirAccess.open(pasta)
	if dir == null:
		push_warning("[SPEC-004] %s: pasta inacessível '%s'" % [rotulo, pasta])
		return

	var reais: Array[String] = []
	dir.list_dir_begin()
	var nome: String = dir.get_next()
	while not nome.is_empty():
		if not dir.current_is_dir() and _e_png(nome):
			reais.append(nome.get_basename())
		nome = dir.get_next()
	dir.list_dir_end()

	for esperado in declarados:
		if not reais.has(String(esperado)):
			push_warning(
				"[SPEC-004] %s: declarado '%s' não existe em %s" % [rotulo, esperado, pasta]
			)

	for encontrado in reais:
		if not declarados.has(encontrado):
			push_warning(
				"[SPEC-004] %s: '%s' existe em %s mas não está em `assets`"
				% [rotulo, encontrado, pasta]
			)


## Só PNG conta como asset: `.import` e `.uid` acompanham o arquivo declarado.
func _e_png(nome: String) -> bool:
	return nome.get_extension().to_lower() == "png"


func _build_tuning_groups() -> void:
	traffic_tuning = {
		"traffic_enabled": traffic_enabled,
		"traffic_max_vehicles": traffic_max_vehicles,
		"traffic_spawn_distance": traffic_spawn_distance,
		"traffic_spawn_interval": traffic_spawn_interval,
		"traffic_min_spacing": traffic_min_spacing,
	}
	for id in TRAFFIC_CATEGORIES:
		traffic_tuning["traffic_frequency_" + id] = TRAFFIC_CATEGORIES[id]["frequency"]

	decoration_tuning = {
		"decoration_enabled": decoration_enabled,
		"decoration_density": decoration_density,
		"decoration_speed_multiplier": decoration_speed_multiplier,
		"decoration_spacing_min": decoration_spacing_min,
		"decoration_spacing_max": decoration_spacing_max,
		"decoration_depth_count": decoration_depth_count,
		"decoration_depth_spacing": decoration_depth_spacing,
		"decoration_scale": decoration_scale,
		"decoration_safety_margin": decoration_safety_margin,
		"decoration_tree_repeat_limit": decoration_tree_repeat_limit,
	}
