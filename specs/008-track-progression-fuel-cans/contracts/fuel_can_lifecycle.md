# Contrato: Ciclo de Vida dos Galões — FuelCanManager (SPEC-008)

**Emissor**: `src/items/fuel_can_manager.gd` (`FuelCanManager`) e `src/items/fuel_can.gd` (`FuelCan`)
**Consumidores**: `GameplayManager` (update/reset/restauração), testes `fuel_can_*_test.gd`

---

## 1. Sinais

### `fuel_can_spawned(can: FuelCan)`

| Item | Regra |
|---|---|
| Emite quando | um galão passa a `ATIVO` numa posição validada (FR-030) |
| Garantia | 1× por nascimento; nunca em lote |

### `fuel_can_collected(restaurado: float)`

| Item | Regra |
|---|---|
| Payload | `GameConfig.fuel_can_restore_amount` no momento da coleta |
| Emite quando | sobreposição válida galão×jogador em `PLAYING` (estado `ATIVO` → devolução ao pool no mesmo quadro) |
| Frequência | **exatamente 1× por galão** — sobreposição por vários quadros não repete (SC-009) |
| Não emite | Fora de `PLAYING`; com galão já coletado; por colisão com NPC; contato que envolva efeitos de colisão (a coleta **não** passa pelo `CollisionSystem` — Clarificação) |

## 2. API pública

| Método | Regra |
|---|---|
| `setup()` | 1× no `_ready` do `GameplayManager`; pré-carrega o pool (`fuel_can_max_active` instâncias) |
| `update(delta, road, npcs_snapshot, track, player)` | **só no ramo `PLAYING`** e com `road.scroll_speed > 0` para geração; movimento/reciclagem/coleta rodam com o scroll vigente |
| `reset()` | devolve tudo ao pool; `gerados_na_corrida = 0`, `distancia_desde_ultima = 0`, pendências limpas |

## 3. Regras de posicionamento e geração (FR-022/FR-028–FR-031)

- **Sem velocidade própria**: `y += road.scroll_speed × delta`; parado ⇒ parado (Clarificação).
- Geração orientada por **distância** com taxa por ambiente (`fuel_can_spawn_rate`); nunca exclusivamente por temporizador.
- Respeita, em todo nascimento: `fuel_can_max_active`; piso/teto do **total por corrida**; `fuel_can_start_offset`/`fuel_can_finish_offset`; `fuel_can_min_spacing` entre ativos; **nunca sobre NPC** e com `fuel_can_npc_spacing` para interagir sem provocar colisão (Clarificação); limites dirigíveis vigentes da estrada.
- Posição inválida ⇒ candidato fica **pendente** e é reavaliado a cada quadro até nascer ou expirar no próximo intervalo.
- **Reciclagem na base**: não coletado que sai completamente da tela volta ao pool e pode ser apresentado novamente mais adiante, em nova posição válida, com estado redefinido (Clarificação; SC-011).
- **Coleta não é colisão**: zero perda de velocidade, deriva, penalidade, cooldown ou evento de colisão (SC-009).
- Nenhum galão ativo/coletável após `VICTORY`/`GAME_OVER`/menu/reinício (SC-011).
