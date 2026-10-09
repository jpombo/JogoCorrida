# Contract: APIs consumidas pelo Sistema de Colisão NPC×NPC

**Feature**: SPEC-006 | **Versão**: 1.0 (2026-10-07)

Interfaces **já existentes** que o `NpcCollisionSystem` consome; nenhuma é modificada por esta feature (somente leitura), exceto os dois hooks aditivos explicitamente marcados. Documentadas como base de testes de contrato.

## 1. TrafficVehicle → estado individual exposto (SPEC-004/005)

```
TrafficVehicle.position: Vector2          # leitura; position.x é o ÚNICO campo escrito (drift)
TrafficVehicle.get_speed() -> float       # leitura — NUNCA escrita por esta spec (FR-017)
TrafficVehicle.get_occupied_area() -> Rect2
TrafficVehicle.get_category_id() -> String
TrafficVehicle.is_active() -> bool
TrafficVehicle.get_instance_id() -> int   # identidade do par (cooldown, cadeia)
```

- As áreas físicas vêm de `GameConfig.NPC_HITBOX_SIZES` (SPEC-005), com fallback em `get_occupied_area()` — **sem segundo conjunto de hitboxes** (Assumptions).
- Os veículos continuam não detectando nem resolvendo colisões por conta própria (§Trânsito, FR-039).

### Hook aditivo 1 (escrito por esta spec)

```
TrafficVehicle.npc_drift: NpcDriftState            # estado de drift, 1 por veículo
TrafficVehicle.aplicar_drift_npc(direcao, forca, duracao) -> void   # substitui drift em curso (FR-014)
TrafficVehicle.atualizar_drift_npc(delta, limite_esq, limite_dir) -> void  # avança fases + clamp (FR-018)
```

- Aditivo: sem chamada, comportamento idêntico ao SPEC-004/005 (SC-016).
- Só escreve em `position.x`; velocidade, scroll, categoria e estado do pool são intocados (FR-017).

## 2. Road → limites trafegáveis vigentes por altura (SPEC-002)

```
Road.get_boundaries_for_player_y(y: float) -> Dictionary {left, right}
```

- Consultada **por quadro, na altura de cada veículo envolvido** — nunca largura memorizada (FR-018, FR-040; mesma fonte já usada por `CollisionSystem`).
- Funciona em 2 vias, 4 vias e durante as transições (interpolação trapezoidal do `Road`).
- O `NpcCollisionSystem` **não** altera geometria da pista.

## 3. TrafficManager → geração e reciclagem (SPEC-004)

```
signal vehicle_spawned(vehicle: TrafficVehicle)
signal vehicle_recycled(vehicle: TrafficVehicle)
TrafficManager.active_vehicles: Array[TrafficVehicle]
TrafficManager.active_vehicles_snapshot: Array[TrafficVehicle]   # cópia sob demanda
```

- Sinais consomidos para **reavaliação orientada a eventos** (FR-033, R8): entrada/saída de NPC invalida o cache de pares candidatos.
- A avaliação NPC×NPC **não** cria, move ou recicla veículos (separação de responsabilidades, FR-036).

### Hook aditivo 2 (chamada de volta ao TrafficManager)

```
TrafficManager → NpcCollisionSystem.validar_spawn(categoria, x, y, bounds) -> Dictionary
                 {aceito: bool, x: float, y: float, adiar: bool}
```

- Consultada em `_tentar_spawn` **depois** das validações já existentes (separação, ordenação, espaçamento) (FR-028).
- `adiar == true` → o candidato permanece pendente e é **revalidado no quadro seguinte** com posições atualizadas; o nascimento nunca é descartado até o próximo intervalo (FR-029, Clarificação Q3). O fluxo de densidade mínima do SPEC-004 (FR-063) é preservado.
- Especificação completa: `contracts/spawn_validation.md`.

## 4. CollisionSystem (SPEC-005) → fronteira de responsabilidade

```
CollisionSystem.collision_occurred(data: CollisionData)   # inalterado, continua sendo o ÚNICO
                                                          # emissor do contato jogador↔NPC
```

- **Nenhuma integração de código**: o novo sistema ignora o jogador; o SPEC-005 continua detectando o contato dele com qualquer NPC, inclusive os deslocados por drift NPC×NPC (FR-037/FR-038, SC-015).
- Garantia de contrato: um NPC deslocado que toque o jogador → **exatamente 1 evento** do SPEC-005 e **0 eventos** desta spec.

## 5. GameConfig → parâmetros (FR-044)

```
GameConfig.NPC_HITBOX_SIZES                       # reuso (SPEC-005)
GameConfig.npc_*                                  # ~16 novos parâmetros (data-model §6)
GameConfig.traffic_min_visible / max por dificuldade  # leitura do teto (FR-042)
```

- Todos somente leitura em runtime; a calibração de dificuldade futura (SPEC-008) pode reescrevê-los sem alteração de código.
