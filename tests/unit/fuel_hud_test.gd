extends GdUnitTestSuite

## SPEC-007 / US4 — teste obrigatório 26: HUD somente observador (H1–H5 de
## contracts/hud_indicator.md). Monta a composição mínima da cena em código
## (mesmos nós de gameplay.tscn) e liga o FuelSystem real; a UI nunca escreve
## no combustível (H5/SC-015).

var sistema: FuelSystem
var hud: FuelHud
var fundo: ColorRect
var preenchimento: ColorRect
var rotulo: Label

var _capacidade_original: float
var _inicial_original: float
var _limiar_original: float
var _rotulo_original: String


func before_test() -> void:
	_capacidade_original = GameConfig.fuel_capacity
	_inicial_original = GameConfig.fuel_initial_amount
	_limiar_original = GameConfig.fuel_low_threshold
	_rotulo_original = GameConfig.fuel_low_label
	GameConfig.fuel_capacity = 100.0
	GameConfig.fuel_initial_amount = -1.0
	GameConfig.fuel_low_threshold = 0.2
	GameConfig.fuel_low_label = "BAIXO"

	sistema = FuelSystem.new()
	sistema.reset()

	hud = FuelHud.new()
	fundo = ColorRect.new()
	fundo.name = "Fundo"
	fundo.size = Vector2(120, 10)
	preenchimento = ColorRect.new()
	preenchimento.name = "Preenchimento"
	preenchimento.size = Vector2(120, 10)
	rotulo = Label.new()
	rotulo.name = "Rotulo"
	hud.add_child(fundo)
	hud.add_child(preenchimento)
	hud.add_child(rotulo)
	add_child(hud)
	hud.setup(sistema)


func after_test() -> void:
	GameConfig.fuel_capacity = _capacidade_original
	GameConfig.fuel_initial_amount = _inicial_original
	GameConfig.fuel_low_threshold = _limiar_original
	GameConfig.fuel_low_label = _rotulo_original
	remove_child(hud)
	hud.free()
	sistema.free()


## H1 — a largura do preenchimento é sempre round(proporção × trilho),
## proporcional a atual/capacidade após cada fuel_changed.
func test_26h1_proporcao_sempre_igual_ao_combustivel() -> void:
	# Tanque cheio: largura total.
	assert_float(preenchimento.size.x).is_equal(round(1.0 * fundo.size.x))

	# 70/100 ⇒ round(0.70 × 120) = 84.
	GameConfig.fuel_initial_amount = 70.0
	sistema.reset()
	assert_float(preenchimento.size.x).is_equal(round(0.70 * fundo.size.x))

	# Consome até ~30/100 ⇒ round(0.30 × 120) = 36.
	sistema.update(20.0, 100.0)  # 70 − 2×20 = 30
	assert_float(sistema.get_atual()).is_equal(30.0)
	assert_float(preenchimento.size.x).is_equal(round(0.30 * fundo.size.x))


## H1 — clamp [0,1]: valor zero ⇒ barra vazia; nunca estoura o trilho.
func test_26h1_clamp_de_proporcao() -> void:
	sistema.update(1000.0, 100.0)
	assert_float(preenchimento.size.x).is_equal(0.0)
	assert_bool(preenchimento.size.x <= fundo.size.x).is_true()


## H2/H3 — rótulo + cor: visíveis ⇔ esta_baixo(); estado não-baixo ⇒ oculto e
## cor padrão. O texto vem de GameConfig.fuel_low_label (nunca literal fixo).
func test_26h2h3_cor_e_rotulo_seguem_estado() -> void:
	# Estado não-baixo.
	assert_bool(sistema.esta_baixo()).is_false()
	assert_bool(rotulo.visible).is_false()
	assert_bool(preenchimento.color == FuelHud.COR_PADRAO).is_true()

	# Consome até o limiar (100 → 15).
	sistema.update(42.5, 100.0)  # 100 − 2×42.5 = 15 ≤ 20
	assert_bool(sistema.esta_baixo()).is_true()
	assert_bool(rotulo.visible).is_true()
	assert_str(rotulo.text).is_equal(GameConfig.fuel_low_label)
	assert_bool(preenchimento.color == FuelHud.COR_BAIXO).is_true()

	# Condição persiste ⇒ continua visível (rótulo estático, sem piscar).
	sistema.update(1.0, 100.0)
	assert_bool(rotulo.visible).is_true()


## H4 — setup idempotente: re-setup não duplica conexões.
func test_26h4_setup_nao_duplica_conexoes() -> void:
	hud.setup(sistema)
	hud.setup(sistema)
	assert_int(sistema.fuel_changed.get_connections().size()).is_equal(1)


## H5 / SC-015 — a UI não modifica o combustível: após interações do HUD
## (setup + redibuições), o valor só muda pelo próprio FuelSystem.
func test_26h5_ui_nao_modifica_combustivel() -> void:
	GameConfig.fuel_initial_amount = 55.0
	sistema.reset()
	var antes: float = sistema.get_atual()

	hud.setup(sistema)
	sistema.update(10.0, 100.0)  # única variação legítima (−20)

	var esperado: float = antes - 20.0
	assert_float(sistema.get_atual()).is_equal(esperado)
