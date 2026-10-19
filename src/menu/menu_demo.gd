class_name MenuDemo
extends Node2D

## SPEC-012 / US3 — Demonstração de corrida do menu principal
## (RF-004…RF-011; contracts/menu_demo_lifecycle.md): ciclo local dos 4
## ambientes com fade, cenário próprio e NPCs de vitrine, SEM tocar em
## qualquer estado de gameplay (FR-013/FR-018): nunca escreve em
## `GameConfig.current_environment_id`, nunca lê dificuldade, nunca emite
## sinais para o orquestrador (menu silencioso — contract §2).
##
## Reutiliza como classes `Road`, `BackgroundController`,
## `DecorationManager` e `TrafficVehicle` com INSTÂNCIAS PRÓPRIAS (research
## R5): nada aqui participa da árvore de gameplay nem é resetado por ele.

## Estados do ciclo de vida (data-model §3, contract §1).
enum Estado { PARADA, EXECUTANDO, PAUSADA }

## BackgroundController não tem class_name — script carregado 1×.
const _script_fundo := preload("res://src/environment/background_controller.gd")

var _estado: int = Estado.PARADA

## Ciclo local: índice sobre `GameConfig.environment_sequence`, SEMPRE
## reiniciando em PLAINS a cada `iniciar()` (RF-005, contract §2).
var _indice_ambiente: int = 0
var _tempo_ambiente: float = 0.0

var _estrada: Road = null
var _fundo = null
var _decoracao: DecorationManager = null
var _fade_rect: ColorRect = null
var _tween: Tween = null

## Pool fixa de NPCs de vitrine (contract §1/§2) — criada no primeiro
## `iniciar()` e REUTILIZADA entre reinícios (SC-007: nunca acumula);
## nunca passa de `demo_npc_max`.
var _pool: Array[TrafficVehicle] = []

## Categorias próprias (TrafficData medida via `garantir_size`, espelhando o
## TrafficManager) — a demo NÃO compartilha instâncias com o trânsito real.
var _categorias_demo: Dictionary[String, TrafficData] = {}

## Cronômetro até a próxima tentativa de reposição (contract §2).
var _tempo_spawn: float = 0.0


## API (contract §1): true só enquanto EXECUTANDO.
func esta_ativo() -> bool:
	return _estado == Estado.EXECUTANDO


## ID canônico do ambiente da sequência — leitura do índice local, nunca de
## `GameConfig.current_environment_id` (FR-013).
func ambiente_atual() -> String:
	var sequencia: Array = GameConfig.environment_sequence
	if sequencia.is_empty():
		return ""
	return String(sequencia[_indice_ambiente])


func npc_ativos() -> int:
	var total: int = 0
	for veiculo in _pool:
		if veiculo != null and veiculo.is_active():
			total += 1
	return total


## Reinício consistente (contract §1): encerra o estado anterior, garante
## PLAINS (índice 0), zera cronômetros/fade, recicla NPCs, religa o
## processamento e VOLTA A SER VISIBLE — a demo é o último nó de mundo e,
## escondida, deixaria a corrida sem cenário no menu. Idempotente.
func iniciar() -> void:
	encerrar()
	_ensure_estrutura()
	_indice_ambiente = 0
	_tempo_ambiente = 0.0
	_tempo_spawn = 0.0
	_matar_tween()
	if _fade_rect != null:
		_fade_rect.color.a = 0.0
	_reciclar_npcs()
	# Estado inicial do cenário: PLAINS (fundo + decoração) — a troca
	# posterior acontece só com alpha do fade em 1 (contract §2).
	_aplicar_ambiente(ambiente_atual())
	_estrada.reset()
	_estrada.update_scroll_speed(float(GameConfig.demo_velocidade))
	_estrada.set_process(true)
	_estado = Estado.EXECUTANDO
	set_process(true)
	visible = true


## EXECUTANDO ⇒ PAUSADA (contract §1): mata o tween, força alpha 0 (SC-005)
## e congela TODO o movimento (processamento próprio e da estrada). O nó
## continua VISIBLE — Configurações abre sobre o cenário congelado (RF-009).
func pausar() -> void:
	if _estado != Estado.EXECUTANDO:
		return
	_matar_tween()
	if _fade_rect != null:
		_fade_rect.color.a = 0.0
	if _estrada != null:
		_estrada.set_process(false)
	_estado = Estado.PAUSADA
	set_process(false)


## PAUSADA ⇒ EXECUTANDO (contract §1): retoma o tempo/ambiente pausados —
## nada é reiniciado (RF-009: abrir/fechar configurações não reinicia o
## ciclo).
func retomar() -> void:
	if _estado != Estado.PAUSADA:
		return
	if _estrada != null:
		_estrada.set_process(true)
	_estado = Estado.EXECUTANDO
	set_process(true)


## De qualquer estado ⇒ PARADA (contract §1): mata o tween + alpha 0
## (SC-005), recicla NPCs, zera a rolagem da estrada, desliga o
## processamento e some da tela. Idempotente.
## O `visible = false` é o que cumpre RF-009 ("sem interferir na
## inicialização da corrida"): sendo o último nó de mundo, a demo desenha
## fundo/estrada/decoração ACIMA do PlayerVehicle e do TrafficLayer —
## visível, ela escondia o carro do jogador e os NPCs em QUALQUER modo.
func encerrar() -> void:
	_matar_tween()
	if _fade_rect != null:
		_fade_rect.color.a = 0.0
	_reciclar_npcs()
	if _estrada != null:
		_estrada.update_scroll_speed(0.0)
		_estrada.set_process(false)
	_estado = Estado.PARADA
	set_process(false)
	visible = false


## Avanço do tempo (contracts §2): rolamento/fundo/decoração/NPCs seguem com
## velocidade FIXA — nunca `DifficultyManager` (FR-017) — e o cronômetro do
## ambiente dispara a transição por fade ao cruzar `demo_duracao_ambiente`.
## Fora de EXECUTANDO é no-op total (congelamento de pausa/encerramento).
func _process(delta: float) -> void:
	if _estado != Estado.EXECUTANDO:
		return

	_fundo.update_scroll(float(GameConfig.demo_velocidade), delta)
	_decoracao.update(delta, _estrada)
	_atualizar_npcs(delta)

	_tempo_ambiente += delta
	if _tempo_ambiente < float(GameConfig.demo_duracao_ambiente):
		return
	# Transição em curso: NÃO zera o acumulador — o gatilho é reavaliado no
	# próximo quadro, quando o fade anterior terminar (um swap por fade,
	# contract §2; a dívida de tempo é descartada só no gatilho efetivo).
	if _tween != null and _tween.is_valid():
		return
	_tempo_ambiente = 0.0
	_iniciar_transicao()


## Criação preguiçosa da estrutura própria (contract §2) — chamada pelo
## `iniciar()`, uma vez por instância; reinícios posteriores só resetam.
## Ordem dos filhos espelha o gameplay.tscn (Background → Decoration →
## Road → NPCs → fade) — regressão T024: Road antes do fundo deixava o
## asfalto (`estrada_2_vias.png`) escondido atrás do background.
func _ensure_estrutura() -> void:
	if _fundo == null:
		_fundo = _script_fundo.new()
		add_child(_fundo)
	if _decoracao == null:
		_decoracao = DecorationManager.new()
		_decoracao.setup(GameConfig.DECORATION_LIBRARIES)
		add_child(_decoracao)
	if _estrada == null:
		_estrada = Road.new()
		add_child(_estrada)
	_ensure_pool()
	if _fade_rect == null:
		# Véu preto tela cheia NO CANVAS DE MUNDO — abaixo do UiLayer da UI
		# (contract §2), desenhado por último entre os filhos da demo.
		# Tamanho explícito do viewport do canvas (640 × 480 fixos, research
		# R3) — sem âncoras: o pai é Node2D, não Control.
		_fade_rect = ColorRect.new()
		_fade_rect.position = Vector2.ZERO
		_fade_rect.size = get_viewport_rect().size
		_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_fade_rect)


## Uma transição por vez (contract §2): fade 0→1 ⇒ troca no alpha 1 (nunca
## dois ambientes visíveis) ⇒ fade 1→0.
func _iniciar_transicao() -> void:
	if _fade_rect == null:
		return
	if _tween != null and _tween.is_valid():
		return
	_tween = create_tween()
	_tween.tween_property(_fade_rect, "color:a", 1.0, float(GameConfig.demo_fade_escurecer))
	_tween.tween_callback(_trocar_ambiente)
	_tween.tween_property(_fade_rect, "color:a", 0.0, float(GameConfig.demo_fade_clarear))


## A troca de ambiente acontece SOMENTE no pico do fade (alpha 1) e escreve
## apenas nos objetos próprios — nunca em `current_environment_id` (FR-013).
func _trocar_ambiente() -> void:
	var sequencia: Array = GameConfig.environment_sequence
	if sequencia.is_empty():
		return
	_indice_ambiente = (_indice_ambiente + 1) % sequencia.size()
	_aplicar_ambiente(ambiente_atual())


## Fundo + decoração do ambiente próprio (contract §4: textura por
## `ENVIRONMENTS[id].texture_path`; decoração sem sinais — research R5).
func _aplicar_ambiente(id: String) -> void:
	var ambiente: Dictionary = GameConfig.ENVIRONMENTS.get(id, {})
	_fundo.set_texture(String(ambiente.get("texture_path", "")))
	_decoracao.set_environment(id)


## Mata o tween sem deixar transição zumbi e força alpha 0 (SC-005:
## pausar()/encerrar() durante transição ⇒ alpha 0).
func _matar_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _reciclar_npcs() -> void:
	for veiculo in _pool:
		if veiculo != null and veiculo.is_active():
			veiculo.deactivate()


## Cria a pool fixa uma única vez (primeiro `iniciar()` via `_ensure_estrutura`)
## — reinícios só reciclam os veículos existentes (SC-007, T019).
func _ensure_pool() -> void:
	if not _pool.is_empty():
		return
	for i in int(GameConfig.demo_npc_max):
		var veiculo := TrafficVehicle.new()
		add_child(veiculo)
		_pool.append(veiculo)


## Movimento, reciclagem e reposição dos NPCs de vitrine (T020,
## contract §2): velocidade FIXA `demo_velocidade` — nunca
## `DifficultyManager` (FR-017); reposição a cada `demo_npc_intervalo`;
## sem conexão com AudioManager (menu silencioso).
func _atualizar_npcs(delta: float) -> void:
	var tela_y: float = get_viewport_rect().size.y
	for veiculo in _pool:
		if veiculo == null or not veiculo.is_active():
			continue
		veiculo.position.y += float(GameConfig.demo_velocidade) * delta
		# Reciclagem ao cruzar por completo a borda inferior (centro além
		# da tela + meia-largura do próprio veículo).
		if veiculo.position.y - veiculo.category.size.y * 0.5 > tela_y:
			veiculo.deactivate()

	_tempo_spawn += delta
	if _tempo_spawn >= float(GameConfig.demo_npc_intervalo):
		_tempo_spawn = 0.0
		_tentar_spawn_demo()


## Tenta repor um NPC: pool cheia ⇒ no-op; senão sorteia categoria e um X
## válido dentro da pista (tentativas limitadas — contract §2, T020).
func _tentar_spawn_demo() -> void:
	var livre := _pool_livre()
	if livre == null:
		return
	var categoria := _sortear_categoria_demo()
	if categoria == null:
		return
	var y: float = -categoria.size.y
	var x := _sortear_x_demo(categoria)
	if is_nan(x):
		return
	livre.activate(categoria, x, y)
	# FR-017: o fator de dificuldade da corrida NUNCA entra na demo.
	livre.fator_dificuldade = 1.0


func _pool_livre() -> TrafficVehicle:
	for veiculo in _pool:
		if veiculo != null and not veiculo.is_active():
			return veiculo
	return null


## Sorteio ponderado pela frequência, espelhando o TrafficManager (FR-010):
## categorias com `frequency == 0` nunca participam.
func _sortear_categoria_demo() -> TrafficData:
	_ensure_categorias()
	var ids: Array[String] = []
	var pesos: Array[float] = []
	var total: float = 0.0
	for id in _categorias_demo:
		var categoria: TrafficData = _categorias_demo[id]
		if not categoria.is_spawnable():
			continue
		ids.append(id)
		pesos.append(categoria.frequency)
		total += categoria.frequency
	if ids.is_empty() or total <= 0.0:
		return null
	var alvo: float = randf() * total
	var acumulado: float = 0.0
	for i in ids.size():
		acumulado += pesos[i]
		if alvo <= acumulado:
			return _categorias_demo[ids[i]]
	return _categorias_demo[ids[ids.size() - 1]]


## Instancia e mede as categorias próprias 1× (garantir_size), como o
## setup do TrafficManager faz com as dele.
func _ensure_categorias() -> void:
	if not _categorias_demo.is_empty():
		return
	for id in GameConfig.TRAFFIC_CATEGORIES:
		var entrada = GameConfig.TRAFFIC_CATEGORIES[id]
		var data: TrafficData
		if entrada is TrafficData:
			data = entrada
		else:
			data = TrafficData.new(entrada)
		data.garantir_size()
		_categorias_demo[id] = data


## X dentro dos limites da pista com separação ≥ `traffic_min_separation`
## dos ativos (tentativas limitadas — contract §2). NaN = esgotou.
func _sortear_x_demo(categoria: TrafficData) -> float:
	var meio: float = categoria.size.x * 0.5
	var esq: float = float(GameConfig.road_left_boundary) + meio
	var dir: float = float(GameConfig.road_right_boundary) - meio
	if dir < esq:
		return NAN
	for tentativa in int(GameConfig.demo_spawn_tentativas):
		var x: float = randf_range(esq, dir)
		if _separacao_respeitada_demo(x):
			return x
	return NAN


func _separacao_respeitada_demo(x: float) -> bool:
	var separacao := float(GameConfig.traffic_min_separation)
	for veiculo in _pool:
		if veiculo != null and veiculo.is_active():
			if absf(veiculo.position.x - x) < separacao:
				return false
	return true
