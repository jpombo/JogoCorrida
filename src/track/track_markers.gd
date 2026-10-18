class_name TrackMarkers
extends Node2D

## Marcadores de INÍCIO e CHEGADA no mundo da pista (SPEC-008, FR-009…FR-013,
## research R2). Banda quadriculada construída com ColorRect (sem sprite novo
## — FR-020) e rótulo lido de GameConfig (§VI, FR-041). Ambos descem com a
## MESMA rolagem da estrada; a CHEGADA nasce a `total / track_units_to_km` px
## acima da largada e permanece até a conclusão.

enum Tipo { INICIO, CHEGADA }

## Altura da banda e tamanho da célula do quadriculado (px, escala inteira).
const ALTURA_BANDA: float = 16.0
const CELULA: float = 8.0

var banda_inicio: Node2D = null
var banda_chegada: Node2D = null
var _criados: bool = false


## Cria a banda de início na largada e a de chegada a `total_km` km acima,
## convertidos em px por `track_units_to_km` (R2). Recria do zero se já existir.
func criar_marcadores(player_y: float, total_km: float) -> void:
	limpar()
	var largura_visivel: float = GameConfig.road_right_boundary - GameConfig.road_left_boundary
	var largura_banda: float = maxf(largura_visivel, GameConfig.road_expanded_width)
	banda_inicio = _criar_banda(Tipo.INICIO, player_y, largura_banda)
	if total_km > 0.0:
		var unidades: float = maxf(GameConfig.track_units_to_km, 0.000001)
		banda_chegada = _criar_banda(
			Tipo.CHEGADA, player_y - total_km / unidades, largura_banda
		)
	_criados = true


## Desloca as bandas com a rolagem do quadro; a banda de início que sair
## completamente da tela é ocultada DEFINITIVAMENTE (FR-010, SC-002).
func update(delta: float, scroll_speed: float) -> void:
	if not _criados or scroll_speed <= 0.0:
		return
	if banda_inicio != null and banda_inicio.visible:
		banda_inicio.position.y += scroll_speed * delta
		if banda_inicio.position.y > _altura_tela():
			banda_inicio.visible = false
	if banda_chegada != null:
		banda_chegada.position.y += scroll_speed * delta


## Vitória geométrica (R2): a banda de chegada está COMPLETAMENTE abaixo da
## base do jogador (topo da banda ≥ base do carro). Depende do cruzamento
## efetivo, não do valor de `percorrida` (caso de borda 14).
func banda_completamente_cruzou(player_y: float, hitbox_altura: float) -> bool:
	if banda_chegada == null:
		return false
	return banda_chegada.position.y >= player_y + hitbox_altura * 0.5


## Remove as bandas atuais de forma síncrona (testes inspecionam os filhos no
## mesmo quadro — `queue_free` seria adiado).
func limpar() -> void:
	while get_child_count() > 0:
		var filho: Node = get_child(0)
		remove_child(filho)
		filho.free()
	banda_inicio = null
	banda_chegada = null
	_criados = false


func reset() -> void:
	limpar()


func _criar_banda(tipo: int, y_topo: float, largura: float) -> Node2D:
	var banda := Node2D.new()
	banda.name = "BandaInicio" if tipo == Tipo.INICIO else "BandaChegada"
	banda.position = Vector2(GameConfig.road_left_boundary, y_topo)
	banda.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(banda)

	var colunas: int = int(ceil(largura / CELULA))
	var linhas: int = int(ALTURA_BANDA / CELULA)
	for linha in linhas:
		for coluna in colunas:
			var celula := ColorRect.new()
			celula.position = Vector2(coluna * CELULA, linha * CELULA)
			celula.size = Vector2(CELULA, CELULA)
			celula.mouse_filter = Control.MOUSE_FILTER_IGNORE
			celula.color = Color.WHITE if (linha + coluna) % 2 == 0 else Color.BLACK
			banda.add_child(celula)

	var rotulo := Label.new()
	var chave: String = "marker_start" if tipo == Tipo.INICIO else "marker_finish"
	rotulo.text = String(GameConfig.ui_strings.get(chave, ""))
	rotulo.position = Vector2(0.0, -ALTURA_BANDA - 14.0)
	rotulo.add_theme_font_size_override("font_size", 12)
	banda.add_child(rotulo)
	return banda


func _altura_tela() -> float:
	if get_viewport() == null:
		return 480.0
	return get_viewport_rect().size.y
