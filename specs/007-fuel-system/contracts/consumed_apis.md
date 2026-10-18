# Contrato: APIs Consumidas pelo FuelSystem (SPEC-007)

**Consumidor**: `src/fuel/fuel_system.gd` + wiring em `src/game/gameplay_manager.gd`

| # | API fornecida | Origem (spec) | Como o 007 a usa | O que **não** é usado |
|---|---|---|---|---|
| 1 | `CollisionSystem.collision_occurred(data: CollisionData)` | SPEC-005 / `specs/005-collision-drift-system/contracts/collision_event.md` | Conectado em `_ready` a `fuel_system.on_player_collision`; **1 sinal = 1 desconto** (deduplicação inteiramente responsabilidade da 005: guarda `_cooldowns` + `_sobrepostos`, `collision_system.gd:62`) | Todos os campos do payload (`velocidade_impacto`, `intensidade_drift`, `direcao_drift`, `tipo`) — R2/R10 |
| 2 | `GameConfig.current_environment_id: String` | SPEC-003 | Lido **no momento** de `on_player_collision()` — trocas de ambiente em runtime valem imediatamente (FR-016); sem cache do id | — |
| 3 | `GameConfig.collision_fuel_penalty: Dictionary` | 007 (novo) | `.get(ambiente, 0.0)` — chave ausente ⇒ 0.0 (R3) | — |
| 4 | `GameConfig.max_speed: float` | SPEC-001 | Denominador da normalização `clamp(v/max_speed, 0, 1)` | — |
| 5 | `PlayerVehicle.get_speed() -> float` | SPEC-001 (`player_vehicle.gd:70`) | Passado como argumento de `update(delta, velocidade)` pelo **manager** (pull, não sinal — R6) | `speed_changed` (não assinado) |
| 6 | `GameState` transições (`old_state`, `new_state`) | SPEC-008 (estrutura atual) | Ponto único de `reset()`: `READY → PLAYING` em `_on_state_changed` (R4) | Qualquer outra transição; PAUSED→PLAYING **não** reseta |
| 7 | `GameConfig.fuel_*` / `fuel_low_label` | 007 (novo) | Leitura dos parâmetros a cada operação (valores sempre atuais — FR-026) | — |

**Garantias recebidas assumidas** (e verificáveis nas suítes 005/006 existentes):
- o sinal da linha 1 emite no máximo 1× por colisão válida e **nunca** por colisão NPC×NPC (SC-011 — teste 21);
- `max_speed > 0` (invariante de balance da SPEC-001);
- `current_environment_id` é sempre chave de `ENVIRONMENTS` (PLAINS/DESERT/FOREST/ICE).

**Divergência registrada**: o contrato 005 menciona "reduzir combustível proporcionalmente à intensidade" como sugestão de consumo futuro; a SPEC-007 fixa penalidade **constante por ambiente** — a spec prevalece (R10 do `research.md`). O payload permanece completo p/ balanceamento futuro.

**Escopo futuro (SPEC-008)**: `fuel_depleted` já existe para transição de estado; nenhum campo novo será exigido — o 007 não altera este contrato ao evoluir (só acrescenta emissões conforme FR-033).
