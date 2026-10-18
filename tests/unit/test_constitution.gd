extends GdUnitTestSuite

## T066 / Constitution v3.0.1 §Governança — regressão dos princípios MUST
## redefinidos pelas emendas v2.0.0 (ratificada 2026-09-18, emendada 2026-10-02),
## v3.0.0 (emendada 2026-10-10, /speckit.analyze da SPEC-007) e v3.0.1
## (emendada 2026-10-11, padronização "constitution"→"constituição", PATCH):
##
## 1. §Trânsito — o veículo de trânsito MUST fornecer identificação, posição e
##    área ocupada, e MUST NOT detectar nem resolver colisões; a detecção e a
##    resolução pertencem ao SPEC-005.
## 2. §VI Suporte Multilíngue — pt-BR é a língua de autoria e padrão; en-US foi
##    diferido para uma spec dedicada de localização e nenhuma feature pode ser
##    bloqueada por essa dívida; textos de usuário SHOULD estar externalizados.
## 3. §Comportamento de Colisão (v3.0.0) — consumir combustível adicional vale
##    segundo a penalidade configurável do ambiente vigente, admitindo valor
##    zero em planície e deserto (alavanca de §Dificuldade).
## 4. §Sistema de Combustível (v3.0.0) — ao zerar, o sistema MUST emitir sinal
##    único de esgotamento e o jogo MUST entrar no estado de falha, com a
##    transição a cargo do sistema central de estado de jogo (SPEC-008).
##
## O procedimento de emenda (§Governança) pede este arquivo quando a alteração
## afeta um MUST verificável — os itens acima são verificáveis.

const CONSTITUTION_PATH: String = "res://.specify/memory/constitution.md"


## Lê a constituição; falha com mensagem clara quando o arquivo some ou muda de lugar.
func _texto_da_constitution() -> String:
	assert_bool(FileAccess.file_exists(CONSTITUTION_PATH)).is_true().override_failure_message(
		"Constitution ausente em %s" % CONSTITUTION_PATH
	)
	return FileAccess.get_file_as_string(CONSTITUTION_PATH)


## A emenda v3.0.1 está registrada e versionada no próprio documento.
func test_constitution_is_v301_in_pt_br() -> void:
	var texto: String = _texto_da_constitution()
	assert_str(texto).contains("**Version**: 3.0.1").override_failure_message(
		"§Governança: versão 3.0.1 não registrada"
	)
	assert_str(texto).contains("Português do Brasil (pt-BR)").override_failure_message(
		"§VI: pt-BR deixou de ser a língua de autoria declarada"
	)
	assert_str(texto).contains("especificação dedicada de localização").override_failure_message(
		"§VI: a emenda v2.0.0 diferiu en-US para uma spec dedicada; essa ressalva sumiu"
	)
	assert_str(texto).contains("SPEC-005").override_failure_message(
		"§Trânsito: a detecção/resolução de colisão foi atribuída ao SPEC-005; a atribuição sumiu"
	)


## Emenda v3.0.0 (1): §Comportamento de Colisão — o MUST de combustível
## adicional está qualificado pela penalidade configurável do ambiente, com
## valor zero admitido em planície e deserto.
func test_collision_consumes_fuel_per_environment_penalty() -> void:
	var texto: String = _texto_da_constitution()
	assert_str(texto).contains("consumir combustível adicional segundo a penalidade").override_failure_message(
		"§Comportamento de Colisão: o MUST de combustível adicional perdeu a qualificação por ambiente (emenda v3.0.0)"
	)
	assert_str(texto).contains("admitindo valor zero em ambientes iniciais").override_failure_message(
		"§Comportamento de Colisão: a exceção de penalidade zero em planície/deserto sumiu (emenda v3.0.0)"
	)


## Emenda v3.0.0 (2): §Sistema de Combustível — sinal único de esgotamento
## (sistema de combustível) + estado de falha (sistema central de estado de
## jogo), com entrega escalonada permitida a spec posterior.
func test_depletion_signals_and_state_failure_stays_must() -> void:
	var texto: String = _texto_da_constitution()
	assert_str(texto).contains("MUST emitir um sinal único de").override_failure_message(
		"§Sistema de Combustível: o MUST do sinal único de esgotamento sumiu (emenda v3.0.0)"
	)
	assert_str(texto).contains("MUST entrar no estado de falha apropriado").override_failure_message(
		"§Sistema de Combustível: o MUST de estado de falha foi diluído (emenda v3.0.0)"
	)
	assert_str(texto).contains("sistema central de estado de jogo (§Estado de Jogo)").override_failure_message(
		"§Sistema de Combustível: a responsabilidade da transição voltou a ficar ambígua (emenda v3.0.0)"
	)


## §Trânsito (MUST): identificação, posição e área ocupada disponíveis no veículo.
func test_traffic_vehicle_provides_identification_position_and_area() -> void:
	var veiculo := TrafficVehicle.new()
	assert_bool(veiculo.has_method("get_category_id")).is_true().override_failure_message(
		"§Trânsito: TrafficVehicle não fornece identificação (get_category_id)"
	)
	assert_bool(veiculo.has_method("get_occupied_area")).is_true().override_failure_message(
		"§Trânsito: TrafficVehicle não fornece área ocupada (get_occupied_area)"
	)

	var esporte: TrafficData = TrafficData.new(GameConfig.TRAFFIC_CATEGORIES["esporte"])
	esporte.garantir_size()
	veiculo.activate(esporte, 320.0, 240.0)
	assert_str(veiculo.get_category_id()).is_equal("esporte")
	assert_that(veiculo.get_occupied_area().size).is_equal(esporte.size).override_failure_message(
		"§Trânsito: área ocupada não deriva da dimensão real da categoria (R10)"
	)
	var centro: Vector2 = veiculo.get_occupied_area().get_center()
	assert_float(centro.x).is_equal_approx(320.0, 0.001).override_failure_message(
		"§Trânsito: área ocupada não está centrada na posição (x)"
	)
	assert_float(centro.y).is_equal_approx(240.0, 0.001).override_failure_message(
		"§Trânsito: área ocupada não está centrada na posição (y)"
	)
	veiculo.free()


## §Trânsito (MUST NOT): nenhum objeto do SPEC-004 detecta nem resolve colisões.
## O vocabulário de contato não pode aparecer nem como sinal nem como método.
func test_no_collision_vocabulary_in_spec004_scripts() -> void:
	var proibidos: Array[String] = [
		"body_entered", "body_exited", "area_entered", "area_exited",
		"body_shape_entered", "collision_detected", "collision_resolve",
		"resolve_collision", "detect_collision", "apply_impulse",
	]

	var transito := TrafficManager.new()
	var decoracao := DecorationManager.new()
	var veiculo := TrafficVehicle.new()
	var elemento := DecorationElement.new()
	var alvos: Array[Node] = [transito, decoracao, veiculo, elemento]

	for alvo in alvos:
		for termo in proibidos:
			assert_bool(alvo.has_signal(termo)).is_false().override_failure_message(
				"§Trânsito: %s expõe o sinal proibido '%s'" % [alvo.get_class(), termo]
			)
			assert_bool(alvo.has_method(termo)).is_false().override_failure_message(
				"§Trânsito: %s implementa o método proibido '%s'" % [alvo.get_class(), termo]
			)

	for alvo in alvos:
		alvo.free()


## §Trânsito (MUST): a geração fica com o manager; o veículo não cria nem recicla.
func test_spawning_is_separated_from_the_vehicle() -> void:
	var veiculo := TrafficVehicle.new()
	assert_bool(veiculo.has_method("update")).is_false().override_failure_message(
		"§Trânsito: o veículo ganhou responsabilidade de update do sistema"
	)
	assert_bool(veiculo.has_method("spawn")).is_false().override_failure_message(
		"§Trânsito: o veículo ganhou responsabilidade de spawn"
	)
	veiculo.free()


## §VI (SHOULD): textos voltados ao usuário ficam na configuração, sem literais
## espalhados nos scripts — os `display_name` de categorias e ambientes existem
## em GameConfig e são texto de exibição em pt-BR, não identificador nem caminho.
func test_user_facing_names_are_externalized_in_config() -> void:
	for id in GameConfig.TRAFFIC_CATEGORIES:
		var nome: String = String(GameConfig.TRAFFIC_CATEGORIES[id].get("display_name", ""))
		assert_str(nome).is_not_empty().override_failure_message(
			"§VI: categoria '%s' sem display_name externalizado" % id
		)
		# Externalizado = texto de exibição, não caminho de arquivo: o SHOULD do
		# §VI é violado se a UI precisar derivar o nome do asset.
		assert_bool(nome.contains("/") or nome.ends_with(".png")).is_false().override_failure_message(
			"§VI: display_name de '%s' é caminho de asset, não texto de usuário" % id
		)

	for id in GameConfig.ENVIRONMENTS:
		var entrada: Dictionary = GameConfig.ENVIRONMENTS[id]
		var nome: String = String(entrada.get("display_name", ""))
		assert_str(nome).is_not_empty().override_failure_message(
			"§VI: ambiente '%s' sem display_name externalizado" % id
		)
		assert_bool(nome.contains("/") or nome.ends_with(".png")).is_false().override_failure_message(
			"§VI: display_name de '%s' é caminho de asset, não texto de usuário" % id
		)
