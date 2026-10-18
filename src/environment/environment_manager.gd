class_name EnvironmentManager

## Gerencia o ambiente atual do jogo e fornece acesso aos dados de ambiente.
## Utiliza o dicionário ENVIRONMENTS do GameConfig para lookup por ID.

var current_environment: EnvironmentData = null

func set_environment(id: String) -> void:
	if not GameConfig.ENVIRONMENTS.has(id):
		push_warning("EnvironmentManager: ID de ambiente inválido '%s'. Usando fallback para PLAINS." % id)
		id = "PLAINS"

	var data = GameConfig.ENVIRONMENTS[id]
	current_environment = EnvironmentData.new(
		data["id"],
		data["display_name"],
		data["texture_path"],
		data["difficulty"]
	)

func get_current_environment() -> EnvironmentData:
	return current_environment

func get_difficulty() -> int:
	if current_environment:
		return current_environment.difficulty
	return 0

func get_all_environments() -> Array[EnvironmentData]:
	var result: Array[EnvironmentData] = []
	for id in GameConfig.ENVIRONMENTS:
		var data = GameConfig.ENVIRONMENTS[id]
		result.append(EnvironmentData.new(
			data["id"],
			data["display_name"],
			data["texture_path"],
			data["difficulty"]
		))
	return result
