class_name AudioManager
extends Node

## SPEC-010 — dono único da reprodução de áudio (AUD-001 colisão, AUD-002
## motor de caminhão, AUD-003 motor de carro). Recebe tudo por
## `configurar()` (não lê GameConfig — contracts/audio_manager_api.md §2) e
## reage apenas a forwards do GameplayManager (contracts/audio_integration).
## Zero `_process`: o gate por quadro do jogador vem de fora (R11).
## Estado lógico sempre coerente mesmo fora da árvore — o `play()` físico é
## que exige `is_inside_tree()` (I8, research R2).

## Streams carregados uma única vez em `configurar` (null = efeito mudo).
var _stream_colisao: AudioStream = null
var _stream_caminhao: AudioStream = null
var _stream_carro: AudioStream = null

var _efeito_mudo: Dictionary = {"colisao": true, "caminhao": true, "carro": true}
var _categoria_caminhao: String = ""
var _volume_motor_db: float = -80.0
var _volume_colisao_db: float = -80.0

## Pools criadas uma única vez como filhas (RF-004/I5). O índice 0 do motor
## é dedicado ao jogador e nunca entra na lista livre (R5, data-model §3).
var _vozes_motor: Array[AudioStreamPlayer] = []
var _livres_motor: Array[int] = []
var _vozes_colisao: Array[AudioStreamPlayer] = []
var _livres_colisao: Array[int] = []

## Dicionário veículo→índice de voz (autoridade do 1:1 — I1). Índice -1 =
## registrado sem voz por pool cheia (silêncio, data-model §3).
var _dicionario: Dictionary = {}

## Carimbo de início de cada colisão em voo — base do roubo LRU (I3/R5).
var _iniciada_em: Dictionary = {}

## Último estado observado + gate do jogador (FR-003/Clarification Q3, R11).
var _estado: int = GameState.State.MENU
var _jogador_acelerando: bool = false

var _configurado: bool = false


## Ciclo de vida — idempotente; chaves ausentes/inválidas ganham defaults
## seguros (falha segura, api §2). Cria as pools e carrega os 3 streams.
func configurar(cfg: Dictionary) -> void:
	if _configurado:
		return
	_configurado = true
	_categoria_caminhao = str(cfg.get("categoria_caminhao", ""))
	_volume_motor_db = _para_db(float(cfg.get("volume_motor", 0.8)))
	_volume_colisao_db = _para_db(float(cfg.get("volume_colisao", 1.0)))
	_stream_colisao = _carregar_stream(str(cfg.get("colisao_path", "")), false)
	_stream_caminhao = _carregar_stream(str(cfg.get("caminhao_path", "")), true)
	_stream_carro = _carregar_stream(str(cfg.get("carro_path", "")), true)
	_efeito_mudo["colisao"] = _stream_colisao == null
	_efeito_mudo["caminhao"] = _stream_caminhao == null
	_efeito_mudo["carro"] = _stream_carro == null
	_criar_pool_motor(maxi(1, int(cfg.get("vozes_motor", 1))))
	_criar_pool_colisao(maxi(1, int(cfg.get("vozes_colisao", 1))))


func esta_configurado() -> bool:
	return _configurado


## `id`: "colisao" | "caminhao" | "carro" — desconhecido também é mudo.
func efeito_mudo(id: String) -> bool:
	return bool(_efeito_mudo.get(id, true))


func vozes_motor_totais() -> int:
	return _vozes_motor.size()


func vozes_motor_ocupadas() -> int:
	return _vozes_motor.size() - _livres_motor.size()


func vozes_colisao_ocupadas() -> int:
	return _vozes_colisao.size() - _livres_colisao.size()


## Getter lógico (I8): não depende da árvore nem do estado físico do player.
func voz_jogador_tocando() -> bool:
	return _configurado and _estado == GameState.State.PLAYING \
		and _jogador_acelerando and not efeito_mudo("carro")


## Getter lógico (I8) — false para veículo desconhecido ou sem voz.
func motor_tocando(veiculo: TrafficVehicle) -> bool:
	if veiculo == null or not _dicionario.has(veiculo):
		return false
	var indice: int = _dicionario[veiculo]
	if indice < 0 or _estado != GameState.State.PLAYING:
		return false
	return _vozes_motor[indice].stream != null


## AUD-001 — exatamente 1 `play()` por chamada (I3/SC-002); pool exausta
## rouba a voz mais antiga em vez de descartar o evento; sem deduplicação
## própria (o dedup de evento é upstream — FR-001).
func tocar_colisao() -> void:
	if not _configurado or _estado != GameState.State.PLAYING \
			or efeito_mudo("colisao") or not is_inside_tree():
		return
	if _vozes_colisao.is_empty():
		return
	var indice: int = -1
	if not _livres_colisao.is_empty():
		indice = _livres_colisao.pop_front()
	else:
		indice = _roubar_colisao_mais_antiga()
	if indice < 0:
		return
	_iniciada_em[indice] = Time.get_ticks_msec()
	_vozes_colisao[indice].play()


## Ciclo de vida do som de motor — 1 voz por veículo (I1); a voz 0 do
## jogador nunca é tocada por aqui (só pelo gate).
func ao_veiculo_surgir(veiculo: TrafficVehicle) -> void:
	if not _configurado or veiculo == null:
		return
	if _dicionario.has(veiculo):
		return
	var indice: int = -1
	if not _livres_motor.is_empty():
		indice = _livres_motor.pop_front()
	_dicionario[veiculo] = indice
	if indice < 0:
		return
	var stream: AudioStream = _stream_caminhao \
		if veiculo.category != null and veiculo.category.id == _categoria_caminhao \
		else _stream_carro
	_vozes_motor[indice].stream = stream
	_vozes_motor[indice].volume_db = _volume_motor_db
	if _estado == GameState.State.PLAYING and is_inside_tree() and stream != null:
		_vozes_motor[indice].play()


## Devolve a voz em QUALQUER estado — zero som órfão (SC-004).
func ao_veiculo_sair(veiculo: TrafficVehicle) -> void:
	if veiculo == null or not _dicionario.has(veiculo):
		return
	var indice: int = _dicionario[veiculo]
	_dicionario.erase(veiculo)
	if indice < 0:
		return
	_vozes_motor[indice].stop()
	_vozes_motor[indice].stream = null
	if not indice in _livres_motor:
		_livres_motor.append(indice)


## Gate por quadro do jogador (FR-003/Q3, R11): o flag é armazenado sempre
## (retomada após pausa re-aplica); o `play()` físico exige PLAYING +
## árvore + AUD-003 não-muda; `false` ou gates falhos ⇒ silenciar a voz 0.
## Nunca reinicia o loop já em reprodução.
func ao_aceleracao_jogador(acionado: bool) -> void:
	_jogador_acelerando = acionado
	if acionado and _configurado and _estado == GameState.State.PLAYING \
			and not efeito_mudo("carro") and is_inside_tree() \
			and _stream_carro != null:
		if not _vozes_motor.is_empty() and not _vozes_motor[0].playing:
			_vozes_motor[0].play()
		return
	if not _vozes_motor.is_empty() and _vozes_motor[0].playing:
		_vozes_motor[0].stop()


## Matriz de reprodução por estado (data-model §5, FR-006) — aplicada
## sincronamente no fim de `_on_state_changed` (R4). O componente não
## decide transições, só reage.
func ao_alterar_estado(novo: int, _antigo: int) -> void:
	_estado = novo
	if not _configurado:
		return
	match novo:
		GameState.State.PLAYING:
			_ligar_tudo()
		GameState.State.PAUSED:
			_pausar_tudo()
		_:
			# VICTORY/GAME_OVER/MENU/READY/desconhecido — falha segura.
			_parar_tudo()


## PLAYING: restaura o `stream_paused`, liga os NPCs registrados com voz e
## re-aplica o gate do jogador (design b — flag zerado em toda parada;
## preservado apenas pela PAUSED, que é o caminho da retomada).
func _ligar_tudo() -> void:
	for voz in _vozes_motor:
		voz.stream_paused = false
	for voz in _vozes_colisao:
		voz.stream_paused = false
	for veiculo in _dicionario:
		var indice: int = _dicionario[veiculo]
		if indice < 0:
			continue
		var voz := _vozes_motor[indice]
		if voz.stream == null or not is_inside_tree() or voz.playing:
			continue
		voz.play()
	ao_aceleracao_jogador(_jogador_acelerando)


## PAUSED: suspende todas as vozes mantendo a posição (SC-006).
func _pausar_tudo() -> void:
	for voz in _vozes_motor:
		voz.stream_paused = true
	for voz in _vozes_colisao:
		voz.stream_paused = true


## Saídas de PLAYING: stop + reset do stream_paused (próxima corrida
## limpa). O dicionário NÃO é limpo aqui — a reciclagem do trânsito emite
## `vehicle_recycled` (ao_veiculo_sair) e a largada seguinte re-liga os
## registrados via `_ligar_tudo`.
func _parar_tudo() -> void:
	for voz in _vozes_motor:
		voz.stop()
		voz.stream_paused = false
	for voz in _vozes_colisao:
		voz.stop()
		voz.stream_paused = false
	# Colisões interrompidas não emitem `finished` — devolve as slots à
	# mão para a próxima corrida não nascer com a pool vazia.
	_livres_colisao.clear()
	for i in _vozes_colisao.size():
		_livres_colisao.append(i)
	_iniciada_em.clear()
	_jogador_acelerando = false


func _carregar_stream(caminho: String, com_loop: bool) -> AudioStream:
	if caminho.is_empty() or not ResourceLoader.exists(caminho):
		return null
	var stream := load(caminho) as AudioStreamMP3
	if stream == null:
		return null
	# Loop aplicado em runtime, sempre — não depende do .import (R1).
	stream.loop = com_loop
	return stream


func _para_db(volume_linear: float) -> float:
	var volume := clampf(volume_linear, 0.0, 1.0)
	if volume <= 0.0:
		return -80.0
	return linear_to_db(volume)


func _criar_pool_motor(total: int) -> void:
	for i in total:
		var voz := AudioStreamPlayer.new()
		voz.stream = _stream_carro
		voz.volume_db = _volume_motor_db
		add_child(voz)
		_vozes_motor.append(voz)
		if i > 0:
			_livres_motor.append(i)


func _criar_pool_colisao(total: int) -> void:
	for i in total:
		var voz := AudioStreamPlayer.new()
		voz.stream = _stream_colisao
		voz.volume_db = _volume_colisao_db
		add_child(voz)
		_vozes_colisao.append(voz)
		_livres_colisao.append(i)
		voz.finished.connect(_liberar_colisao.bind(i))


func _liberar_colisao(indice: int) -> void:
	if indice in _iniciada_em:
		_iniciada_em.erase(indice)
	if not indice in _livres_colisao:
		_livres_colisao.append(indice)


## Roubo LRU: menor carimbo `iniciada_em` (empate ⇒ menor índice, pela
## ordem de iteração). O evento nunca é descartado (I3).
func _roubar_colisao_mais_antiga() -> int:
	var alvo := -1
	var menor: int = 9223372036854775807
	for indice in _iniciada_em:
		var carimbo: int = _iniciada_em[indice]
		if carimbo < menor:
			menor = carimbo
			alvo = int(indice)
	return alvo
