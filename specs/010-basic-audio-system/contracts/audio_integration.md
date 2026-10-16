# Contrato: Integração do Áudio no Jogo (SPEC-010)

**Dono do wiring**: `src/game/gameplay_manager.gd` (`GameplayManager`)
**Componente**: `src/audio/audio_manager.gd` (`AudioManager`) — [audio_manager_api.md](audio_manager_api.md)
**Sinais consumidos**: `GameState.state_changed` (via handler existente), `CollisionSystem.collision_occurred`, `NpcCollisionSystem.npc_collision_occurred`, `TrafficManager.vehicle_spawned`/`vehicle_recycled` (nós `traffic_layer`)
**Referências**: [data-model.md](../data-model.md) §5, research R4/R5/R9, plan §Technical Context

## 1. Criação e configuração (em `_ready`, ordem importa)

```gdscript
# Campo (padrão ui_root/track_layer — null nos testes sintéticos sem _ready):
var audio_manager: AudioManager = null

# Em _ready(), DEPOIS de `game_state.state_changed.connect(_on_state_changed)`:
audio_manager = AudioManager.new()
add_child(audio_manager)                     # filho do orquestrador (R9)
audio_manager.configurar({                   # chaves e defaults: audio_manager_api.md §2
    "colisao_path": GameConfig.audio_colisao_path,
    "caminhao_path": GameConfig.audio_caminhao_path,
    "carro_path": GameConfig.audio_carro_path,
    "vozes_colisao": GameConfig.audio_vozes_colisao,
    "vozes_motor": GameConfig.traffic_max_vehicles + 1,
    "volume_motor": GameConfig.audio_volume_motor,
    "volume_colisao": GameConfig.audio_volume_colisao,
    "categoria_caminhao": GameConfig.audio_categoria_caminhao,
})
```

Ordem relativa em `_ready`:

1. `game_state.state_changed.connect(_on_state_changed)` (existente, topo);
2. criação + `configurar()` do áudio;
3. conexões de trânsito (ao lado dos lambdas existentes de `marcar_reavaliacao`);
4. conexões de colisão (ao lado de `collision_system.collision_occurred.connect(fuel_system.on_player_collision)`).

## 2. Conexões de eventos (forwards — payload de colisão ignorado)

```gdscript
# Trânsito — vida do som de motor (R5):
traffic_layer.vehicle_spawned.connect(func(v): audio_manager.ao_veiculo_surgir(v))
traffic_layer.vehicle_recycled.connect(func(v): audio_manager.ao_veiculo_sair(v))

# Colisões — AUD-001 para jogador×NPC e NPC×NPC (Clarification Q1 / FR-001):
collision_system.collision_occurred.connect(func(_d): audio_manager.tocar_colisao())
npc_collision_system.npc_collision_occurred.connect(func(_d): audio_manager.tocar_colisao())
```

Regras do wiring:
- As conexões só existem dentro de `_ready` — testes sintéticos que não rodam `_ready` não têm áudio (legado intacto, SC-009).
- **Nenhuma** deduplicação aqui: os sistemas SPEC-005/006 já emitem 1 evento por encontro; o áudio reage 1:1 (FR-001).
- Os payloads `CollisionData`/`NpcCollisionData` são ignorados — o efeito é único para toda colisão (Assumption da spec).

### Gate do som do jogador (chamada por quadro — não é conexão de sinal)

```gdscript
# Em _processar_playing() (executa só em PLAYING, após as guardas existentes de quadro):
if audio_manager:
    audio_manager.ao_aceleracao_jogador(
        Input.is_action_pressed("accelerate")
        and not Input.is_action_pressed("brake"))
```

- Condição idêntica à fase de aceleração de `src/player/vehicle_controller.gd` (FR-003/Clarification Q3).
- Fora de PLAYING não há chamada — as viradas continuam cobertas por `ao_alterar_estado` (§3).
- Custo: 1 chamada + 2 `Input.is_action_pressed` por quadro em PLAYING, sem alocação; o `AudioManager` segue sem `_process` (R11).
- Adicionado pela T011, ao lado dos demais forwards do orquestrador; guarda `if audio_manager:` preserva os testes legados.

## 3. Transições de estado (fim de `_on_state_changed`)

```gdscript
func _on_state_changed(new_state: int, old_state: int) -> void:
    if old_state == game_state.State.READY and new_state == game_state.State.PLAYING:
        _reset_corrida()          # existente — emite vehicle_spawned dos veículos novos
    match new_state:              # existente — _show_menu/_show_ready/_show_playing/...
        ...
    # SPEC-010 / FR-006: encaminha POR ÚLTIMO — depois do reset e da exibição:
    if audio_manager:
        audio_manager.ao_alterar_estado(new_state, old_state)
```

Por que **no fim**:
- READY→PLAYING: o reset spawna os veículos **antes** de o áudio ligar (nada toca durante a preparação; Assumption da spec) e, no mesmo passo, liga o que acabou de nascer.
- Viradas no mesmo quadro: o encaminhamento é síncrono por transição — a **última** virada vence, então o áudio sempre reflete o estado final (edge case "transição no mesmo quadro" do spec, R4 — sem guarda de quadro estilo `_frame_pausa`: a virada **não** lê input; a leitura de aceleração é só do forward por quadro de §2, R11).
- `ao_alterar_estado` é chamado para **todas** as transições (inclusive `antigo == novo` nunca ocorrer — `GameState` só emite viradas reais); estado desconhecido ⇒ falha segura de parar tudo (api §3).

## 4. Bloco de configuração (`GameConfig` — `## Áudio (SPEC-010)`)

```gdscript
## ## Áudio (SPEC-010)
@export var audio_colisao_path: String = "res://assets/audio/colisao.mp3"
@export var audio_caminhao_path: String = "res://assets/audio/caminhao.mp3"
@export var audio_carro_path: String = "res://assets/audio/carro.mp3"
@export var audio_vozes_colisao: int = 3
@export var audio_volume_motor: float = 0.8        # linear 0..1 → linear_to_db em runtime
@export var audio_volume_colisao: float = 1.0
@export var audio_categoria_caminhao: String = "caminhao"
```

`vozes_motor` **não** é campo: o orquestrador deriva `traffic_max_vehicles + 1` (fonte única da densidade, R5). Nenhum parâmetro de balanceamento (velocidade, densidade, fatores, consumo) é lido ou escrito pelo áudio (FR-005/SC-005, R10).

## 5. O que NÃO muda (escopo de regressão — SC-009/FR-008)

| Arquivo | Mudança |
|---------|---------|
| `src/game/game_state.gd` | **nenhuma** (só observado) |
| `src/collision/*.gd` | **nenhuma** (sinais só observados) |
| `src/traffic/*.gd` | **nenhuma** (sinais e `TrafficData.id` só lidos) |
| `src/player`, `src/track`, `src/items`, `src/fuel`, `src/ui`, `src/difficulty` | **nenhuma** |
| `src/game/gameplay.tscn` | **nenhuma** (sem nó de cena novo — R9) |
| `tests/unit/*` legados | **nenhuma** alteração exigida (`audio_manager == null` com guards) |
