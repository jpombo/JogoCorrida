extends Node

enum State {
	MENU,
	READY,
	PLAYING,
	PAUSED,
	VICTORY,
	GAME_OVER
}

var current_state: State = State.MENU
var previous_state: State = State.MENU

signal state_changed(new_state: State, old_state: State)

func change_state(new_state: State) -> void:
	if new_state == current_state:
		return
	previous_state = current_state
	current_state = new_state
	state_changed.emit(new_state, previous_state)

func start_game() -> void:
	change_state(State.READY)

func begin_playing() -> void:
	change_state(State.PLAYING)

func pause_game() -> void:
	if current_state == State.PLAYING:
		change_state(State.PAUSED)

func resume_game() -> void:
	if current_state == State.PAUSED:
		change_state(State.PLAYING)

func game_over() -> void:
	change_state(State.GAME_OVER)

func victory() -> void:
	change_state(State.VICTORY)

func reset() -> void:
	change_state(State.MENU)
