class_name DecorationData
extends Resource

## Dados de um elemento da biblioteca de decoração de um ambiente.
## Instanciado a partir de GameConfig.DECORATION_LIBRARIES (FR-029, R4).
##
## É um Resource de configuração: `repeatable` é um dado declarado, nunca deduzido
## do nome do arquivo em runtime (research.md R3, constitution v2.0.0
## §Independência de Assets, FR-036).

## Nome do asset, sem extensão.
var asset: String = ""

## Caminho completo do asset já reescalonado (R1).
var texture_path: String = ""

## Autoriza repetição consecutiva até GameConfig.decoration_tree_repeat_limit (FR-036).
## `true` apenas para os assets marcados como repetíveis na configuração.
var repeatable: bool = false

## Percentual de apresentação do elemento dentro do seu ambiente, em pontos
## percentuais (a biblioteca soma 100). É a META declarada em GameConfig
## (FR-036, FR-037): o que o validador confere e o que o jogador deve observar
## em partidas longas.
var weight: float = 100.0

## Peso efetivo do sorteio, derivado de `weight` por
## DecorationManager._compensar_pesos. Neutraliza o viés que D6 (não repetir
## imediatamente) e D7 (limite de repetição) imprimem na frequência observada,
## de modo que a frequência real se aproxime do percentual declarado.
var peso_sorteio: float = 100.0

## Dimensão real medida da textura após o reescalonamento (FR-046).
## Preenchida em runtime; reflete o asset efetivamente carregado.
var size: Vector2 = Vector2.ZERO

## Monta o Resource a partir de uma entrada de GameConfig.DECORATION_LIBRARIES e
## da pasta declarada em GameConfig.DECORATION_PATHS.
func _init(p_asset: String = "", p_texture_path: String = "", p_repeatable: bool = false, p_weight: float = 100.0) -> void:
	asset = p_asset
	texture_path = p_texture_path
	repeatable = p_repeatable
	weight = p_weight
	peso_sorteio = p_weight

## Monta o Resource a partir de uma entrada crua da biblioteca e a pasta do ambiente.
static func from_entry(p_asset: String, p_folder: String, p_repeatable: bool, p_weight: float = 100.0) -> DecorationData:
	return DecorationData.new(p_asset, p_folder + p_asset + ".png", p_repeatable, p_weight)

## Verdadeiro quando o asset pode ser usado: tem caminho declarado (FR-029).
func is_usable() -> bool:
	return not texture_path.is_empty() and ResourceLoader.exists(texture_path)


## Garante que `size` foi medida antes do primeiro nascimento (FR-042, FR-050).
##
## Sem isso o primeiro nascimento de um asset calcula altura e meia-largura com
## `size == ZERO`: o elemento nasceria mais perto da tela e, lateralmente,
## invadiria a área trafegável + margem de segurança no quadro do nascimento.
## Idempotente: depois de medida, custa só a leitura do sinalizador.
func garantir_size() -> void:
	if size != Vector2.ZERO:
		return
	if texture_path.is_empty() or not ResourceLoader.exists(texture_path):
		return
	var textura: Texture2D = load(texture_path)
	if textura != null:
		size = Vector2(textura.get_width(), textura.get_height())