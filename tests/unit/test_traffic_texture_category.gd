extends GdUnitTestSuite

## FR-011 — a aparência de um veículo do pool acompanha a categoria do
## nascimento.
##
## O pool reutiliza o mesmo nó com a categoria sorteada a cada birth. A
## textura memorizada só pode ser reaproveitada quando ela pertence à MESMA
## categoria; caso contrário o veículo exibe a aparência de uma categoria com
## a velocidade de outra — ex.: um sprite de `passeio` descendo aos 28 px/s do
## `caminhão` (125 − 90 = 35 km/h) em vez dos 20 px/s do próprio `passeio`
## (125 − 100 = 25 km/h), que é o defeito observado no aceite manual.
## A guarda antiga (`category.size != ZERO`) era sempre verdadeira, porque
## `TrafficManager.setup()` mede o `size` de toda categoria antes do 1º spawn.


var veiculo: TrafficVehicle


func before_test() -> void:
	veiculo = TrafficVehicle.new()
	add_child(veiculo)


func after_test() -> void:
	veiculo.free()


func _categoria(id: String) -> TrafficData:
	var c := TrafficData.new(GameConfig.TRAFFIC_CATEGORIES[id])
	c.garantir_size()
	return c


## Reutilizado com OUTRA categoria, o veículo carrega a textura da nova pasta
## (FR-011) em vez de herdar a aparência da anterior.
func test_reuso_com_categoria_diferente_troca_a_textura() -> void:
	var passeio := _categoria("passeio")
	var caminhao := _categoria("caminhao")

	veiculo.activate(passeio, 320.0, -100.0)
	var textura_passeio := veiculo.texture
	veiculo.deactivate()

	veiculo.activate(caminhao, 320.0, -100.0)
	var esperada := load(caminhao.texture_path_for(caminhao.assets[0]))

	assert_bool(veiculo.texture == esperada).is_true().override_failure_message(
		"FR-011: reuso como '%s' herdou a textura de '%s' (%s)"
		% [caminhao.id, passeio.id, veiculo.texture.resource_path]
	)
	assert_bool(veiculo.texture != textura_passeio).is_true().override_failure_message(
		"FR-011: a textura não mudou no recycle para a categoria %s" % caminhao.id
	)


## Reutilizado com a MESMA categoria, o cache continua valendo (FR-017) —
## nenhuma recarga é feita e a textura é a mesma instância.
func test_reuso_com_a_mesma_categoria_preserva_o_cache() -> void:
	var passeio_a := _categoria("passeio")
	var passeio_b := _categoria("passeio")

	veiculo.activate(passeio_a, 320.0, -100.0)
	var textura := veiculo.texture
	veiculo.deactivate()

	veiculo.activate(passeio_b, 320.0, -100.0)
	assert_bool(veiculo.texture == textura).is_true().override_failure_message(
		"FR-017: cache de textura descartado no recycle da mesma categoria"
	)


## A textura exibida tem as mesmas dimensões da área ocupada da categoria —
## sem isso o espaçamento e a colisão usam um retângulo que não corresponde ao
## sprite na tela.
func test_textura_exibida_coincide_com_o_size_da_categoria() -> void:
	for id in ["caminhao", "utilitario", "passeio", "esporte"]:
		veiculo.activate(_categoria(id), 320.0, -100.0)
		var categoria: TrafficData = veiculo.category
		assert_float(float(veiculo.texture.get_height())).is_equal(
			categoria.size.y
		).override_failure_message(
			"FR-011: textura de '%s' com altura %d mas category.size.y = %d"
			% [id, veiculo.texture.get_height(), categoria.size.y]
		)
		assert_float(float(veiculo.texture.get_width())).is_equal(
			categoria.size.x
		).override_failure_message(
			"FR-011: textura de '%s' com largura %d mas category.size.x = %d"
			% [id, veiculo.texture.get_width(), categoria.size.x]
		)
		veiculo.deactivate()
