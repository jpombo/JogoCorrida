class_name EnvironmentData

## Dados estáticos de um ambiente do jogo.
## Cada ambiente possui identificação, nome exibido, asset de background e dificuldade base.

var id: String
var display_name: String
var texture_path: String
var difficulty: int

func _init(p_id: String, p_display_name: String, p_texture_path: String, p_difficulty: int) -> void:
	id = p_id
	display_name = p_display_name
	texture_path = p_texture_path
	difficulty = p_difficulty
