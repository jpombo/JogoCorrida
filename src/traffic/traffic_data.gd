class_name TrafficData
extends Resource

## Dados de uma categoria de veículo de trânsito.
##instanciado a partir de GameConfig.TRAFFIC_CATEGORIES (FR-001, FR-012, R4).
##
## É um Resource de configuração, não um estado de gameplay: a identidade da
## categoria (velocidade máxima, pasta, assets) não muda em runtime.

## Identificador da categoria: `caminhao`, `esporte`, `passeio` ou `utilitario`.
var id: String = ""

## Nome para exibição. Texto de usuário fica em GameConfig, nunca em código
## (constitution v2.0.0 §Suporte Multilíngue).
var display_name: String = ""

## Pasta exclusiva de assets da categoria (FR-012).
var assets_path: String = ""

## Arquivos da categoria, sem extensão.
var assets: Array[String] = []

## Velocidade máxima em km/h — dado de identificação, não parâmetro de ajuste (FR-057).
var max_speed_kmh: float = 0.0

## Velocidade máxima nas unidades da física do jogo (R2: 1 km/h = 0.8 unidades).
## Sempre menor que GameConfig.max_speed (FR-008, I4).
var max_speed: float = 0.0

## Frequência relativa de spawn. `0.0` mantém a categoria configurável mas nunca
## a sorteia (FR-010, FR-023).
var frequency: float = 0.0

## Dimensão real medida da textura, preenchida em runtime pelo TrafficManager
## (FR-011). Não é configuração: reflete o asset realmente carregado.
var size: Vector2 = Vector2.ZERO

## Monta o Resource a partir de uma entrada de GameConfig.TRAFFIC_CATEGORIES.
func _init(p_data: Dictionary = {}) -> void:
	if p_data.is_empty():
		return

	id = p_data.get("id", "")
	display_name = p_data.get("display_name", "")
	assets_path = p_data.get("assets_path", "")

	var lista: Array = p_data.get("assets", [])
	assets.clear()
	for a in lista:
		assets.append(str(a))

	max_speed_kmh = float(p_data.get("max_speed_kmh", 0.0))
	max_speed = max_speed_kmh * GameConfig.KMH_TO_SPEED_UNIT
	frequency = float(p_data.get("frequency", 0.0))

## Caminho completo de um asset da categoria, sem extensão.
func texture_path_for(asset: String) -> String:
	return assets_path + asset + ".png"

## Verdadeiro quando a categoria pode participar do sorteio de spawn (FR-023).
## Requer frequência positiva e ao menos um asset configurado.
func is_spawnable() -> bool:
	return frequency > 0.0 and not assets.is_empty()

## Verdadeiro quando a categoria é mais lenta que o jogador (FR-008, I4).
## O teste usa `<` estrito: uma categoria na velocidade do jogador já violaria a
## intenção de FR-007, em que o trânsito é sempre ultrapassado.
func is_slower_than_player() -> bool:
	return max_speed < GameConfig.max_speed

## Mede a dimensão real da textura da categoria (FR-011, R10) ANTES do primeiro
## spawn. Sem esta medida antecipada, a primeira ativação da categoria ainda
## teria `size == ZERO` e o nascimento seria calculado com folga nula — o veículo
## sairia da área trafegável (I2, FR-014).
##
## Idempotente: depois de medida, a chamada custa só a leitura do sinalizador.
func garantir_size() -> void:
	if size != Vector2.ZERO:
		return
	for asset in assets:
		var caminho: String = texture_path_for(asset)
		if caminho.is_empty() or not ResourceLoader.exists(caminho):
			continue
		var textura: Texture2D = load(caminho)
		if textura != null:
			size = Vector2(textura.get_width(), textura.get_height())
			return