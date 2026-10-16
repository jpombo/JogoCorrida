# Tasks: SPEC-010 — Sistema Básico de Áudio

**Input**: Design documents from `/specs/010-basic-audio-system/`

**Prerequisites**: plan.md, spec.md (3 US), research.md (R1–R11), data-model.md, contracts/ (audio_manager_api, audio_integration), quickstart.md

**Tests**: **Incluídos** — a spec pede explicitamente "Executar testes para verificar reprodução, interrupção, pausa e retomada" (§8.6) e o quickstart §4 prevê 5 suítes novas (`audio_manager`/`audio_collision`/`audio_engine`/`audio_state_flow`/`audio_modes`; R7 divide lógica sem árvore × integração com `add_child` — as 63 suítes/389 casos legados devem permanecer verdes sem ajuste, SC-009).

**Organization**: tarefas agrupadas por user story; cada fase é um incremento testável independente.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: paralelizável (arquivos diferentes, sem dependências)
- **[Story]**: US1–US3 conforme spec.md
- Caminhos exatos: `src/` (monogodot, raiz do repo), `tests/unit/` GdUnit4

## Path Conventions

- Engine: Godot 4.7.2, cena principal `src/game/gameplay.tscn`
- Componente novo: `AudioManager extends Node` em `src/audio/` — exceção documentada ao padrão `RefCounted` (players precisam de dono na árvore — research R2/R9), criado pelo `GameplayManager` em `_ready` (não autoload, não nó de cena)
- Zero números mágicos: tudo no bloco config (T001); pool de motor derivada de `traffic_max_vehicles + 1` no orquestrador (R5)
- Guards `if audio_manager:` em todo wiring — testes sintéticos sem `_ready` seguem com `null` (SC-009)

---

## Phase 1: Setup (infraestrutura compartilhada)

**Purpose**: bloco de configuração único + imports dos assets — pré-requisito de tudo (T001 alimenta o `configurar` do componente)

- [X] T001 [P] Criar bloco `## Áudio (SPEC-010)` em src/config/game_config.gd: `audio_colisao_path = "res://assets/audio/colisao.mp3"`, `audio_caminhao_path = "res://assets/audio/caminhao.mp3"`, `audio_carro_path = "res://assets/audio/carro.mp3"`, `audio_vozes_colisao = 3`, `audio_volume_motor = 0.8`, `audio_volume_colisao = 1.0`, `audio_categoria_caminhao = "caminhao"` — valores e semântica conforme data-model.md §6 e contracts/audio_integration.md §4, com comentários de ajuste (research R8)
- [X] T002 [P] Garantir os `*.import` dos três MP3 em assets/audio/ (abrir o editor Godot uma vez por máquina — regra do AGENTS.md; sem import, `ResourceLoader.exists` falha e todo efeito nasce mudo, quebrando SC-001 nos testes)

**Checkpoint**: config completo e assets importáveis — nenhum sistema lê áudio ainda

---

## Phase 2: Foundational (pré-requisito bloqueante)

**Purpose**: `AudioManager` — dono único da reprodução; TODAS as user stories dependem dele

**⚠️ CRITICAL**: nenhuma US pode começar antes desta fase

- [X] T003 Implementar src/audio/audio_manager.gd (`extends Node`): campos `_configurado`, `_estado`, streams `_stream_colisao/_stream_caminhao/_stream_carro`, pools `_vozes_motor`/`_vozes_colisao` (lista livre + ocupadas), `_dicionario` veículo→voz, `_voz_jogador` (índice 0), volumes; `configurar(cfg)` idempotente com validação de chaves e defaults seguros (path vazio ⇒ efeito mudo; `vozes < 1` ⇒ 1; volume fora de 0..1 ⇒ clamp), `ResourceLoader.exists` + `load` dos 3 streams, `loop = true` nos streams de motor (`loop = false` na colisão), `linear_to_db` dos volumes, criação única das pools como filhas do componente; `ao_alterar_estado(novo, antigo)` **armazenando** `_estado` (a matriz de reprodução é das US2/US3); guards `is_inside_tree()` nos pontos de reprodução; getters `esta_configurado`, `efeito_mudo`, `vozes_motor_totais/ocupadas`, `vozes_colisao_ocupadas` — semântica de contracts/audio_manager_api.md §§1–3 (base) e data-model.md §§2–4, research R1/R2/R5/R8
- [X] T004 [P] Estender src/game/gameplay_manager.gd: campo `var audio_manager: AudioManager = null`; em `_ready`, **depois** de `game_state.state_changed.connect(_on_state_changed)`, criar `AudioManager.new()`, `add_child` e `configurar({...})` com as 8 chaves lidas do `GameConfig` (`vozes_motor = GameConfig.traffic_max_vehicles + 1`) — contracts/audio_integration.md §1; ao **fim** de `_on_state_changed`, `if audio_manager: audio_manager.ao_alterar_estado(new_state, old_state)` (após `_reset_corrida`/`match _show_*`) — contracts/audio_integration.md §3, research R4
- [X] T005 [P] Criar tests/unit/audio_manager_test.gd (GdUnit4): `configurar` idempotente (2ª chamada no-op), 3 streams carregados com `loop` true/false conforme o efeito, volumes convertidos, pools com os tamanhos recebidos no `cfg` (`vozes_motor` respeitado tal como passado) e voz 0 do jogador reservada, path inexistente ⇒ apenas aquele efeito mudo sem erro (SC-008), `ao_alterar_estado` armazena o estado e os getters refletem (I7/I8)

**Checkpoint**: componente criado, configurado e recebendo estado no jogo — as 3 US podem avançar

---

## Phase 3: User Story 1 - Ouvir o impacto das colisões durante a corrida (Priority: P1) 🎯 MVP

**Goal**: AUD-001 toca em **toda** colisão veicular relevante — jogador×NPC **e** NPC×NPC (Clarification Q1) — com exatamente 1 reprodução por evento, somente em PLAYING, sem tocar o pipeline de colisão.

**Independent Test**: quickstart §3.2 — provocar colisões (incl. NPC×NPC) e ouvir 1 efeito por evento com física idêntica; suíte `audio_collision_test` verde.

### Tests for User Story 1

- [X] T006 [P] [US1] Criar tests/unit/audio_collision_test.gd (GdUnit4): `tocar_colisao()` só reproduz em PLAYING (não em MENU/READY/PAUSED/VICTORY/GAME_OVER); exatamente 1 `play()` por chamada/evento; pool exausta rouba a voz mais antiga (LRU por `Time.get_ticks_msec`) em vez de descartar o evento; efeito mudo ⇒ no-op; fora da árvore ⇒ estado lógico atualizado sem `push_error` (guard `is_inside_tree`); devolução da voz pelo `finished` — SC-002, SC-006, SC-008, invariantes I3/I8 de data-model.md §5

### Implementation for User Story 1

- [X] T007 [US1] Implementar `tocar_colisao()` em src/audio/audio_manager.gd: gates (configurado · estado == PLAYING · AUD-001 não-mudo · na árvore), seleção de voz livre ou roubo da mais antiga (`iniciada_em` menor), único `play()` com `volume_colisao`, conexão de `finished` para devolver à lista — contracts/audio_manager_api.md §3, data-model.md §4, research R5 (sem dedup própria — dedup é upstream SPEC-005/006)
- [X] T008 [P] [US1] Conectar os forwards de colisão em src/game/gameplay_manager.gd (junto de `collision_system.collision_occurred.connect(fuel_system.on_player_collision)`): `collision_system.collision_occurred` e `npc_collision_system.npc_collision_occurred` → `func(_d): audio_manager.tocar_colisao()` (payload ignorado, sem deduplicação) — contracts/audio_integration.md §2

**Checkpoint**: US1 funcional — som de colisão em jogadores e NPCs, 1 por evento, sem regressão do pipeline

---

## Phase 4: User Story 2 - Ouvir os motores dos veículos na pista (Priority: P2)

**Goal**: jogador + NPCs não-caminhão tocam AUD-003, caminhões AUD-002 (`TrafficData.id`), tudo simultâneo enquanto ativo; o som morre exatamente com o veículo (zero órfãos).

**Independent Test**: quickstart §3.1 e §3.3 — corrida com caminhão/carros simultâneos e NPCs sendo reciclados sem eco; suíte `audio_engine_test` verde.

### Tests for User Story 2

- [X] T009 [P] [US2] Criar tests/unit/audio_engine_test.gd (GdUnit4): mapeamento por `category.id` (`caminhao` ⇒ AUD-002, `esporte/passeio/utilitario` ⇒ AUD-003, jogador ⇒ AUD-003); 1:1 veículo→voz (spawn duplicado no-op, saída desconhecida no-op); pool de NPCs cheia ⇒ silêncio sem erro; liga em PLAYING, para em qualquer saída de PLAYING e em `ao_veiculo_sair` em qualquer estado (zero som órfão); gate do jogador: `ao_aceleracao_jogador(true)` liga a voz 0 (PLAYING + árvore lógica), `(false)` a silencia, a entrada em PLAYING **não** liga o jogador sozinha e chamada com estado ≠ PLAYING é ignorada; simultaneidade de todas as vozes + `loop = true` nos streams — SC-003, SC-004, FR-003/Q3, invariantes I1/I2/I5/I9 de data-model.md §5

### Implementation for User Story 2

- [X] T010 [US2] Estender src/audio/audio_manager.gd: pool de vozes de motor com índice 0 dedicado ao jogador (criada em `configurar`, stream AUD-003), dicionário `_dicionario` veículo→voz; `ao_veiculo_surgir(veiculo)` (já registrado ⇒ no-op; sem voz livre ⇒ silêncio; stream por `veiculo.category.id == categoria_caminhao`; `play()` só se PLAYING e na árvore) e `ao_veiculo_sair(veiculo)` (desconhecido ⇒ no-op; senão `stop()` + devolver à pool + remover — em qualquer estado); implementar os getters de consulta da API `voz_jogador_tocando()` e `motor_tocando(veiculo)`; adicionar `ao_aceleracao_jogador(acionado: bool)` — gate da voz 0 (FR-003/Q3): `true` ⇒ `play()` se PLAYING + árvore + AUD-003 não-muda e não tocando (já tocando ⇒ no-op), `false` ⇒ `stop()` com guarda de estado falha ⇒ silenciar, mantendo o flag `_jogador_acelerando`; estender `ao_alterar_estado`: PLAYING ⇒ ligar **todos os registrados exceto o jogador** (a voz 0 fica a cargo do gate — I9), saída de PLAYING ⇒ `stop()` + `stream_paused = false` (regra base; a pausa fina é da US3) — contracts/audio_manager_api.md §1/§3, data-model.md §3, research R5/R6/R11
- [X] T011 [P] [US2] Conectar os forwards de trânsito em src/game/gameplay_manager.gd (ao lado dos lambdas existentes de `marcar_reavaliacao`): `traffic_layer.vehicle_spawned` → `ao_veiculo_surgir` e `traffic_layer.vehicle_recycled` → `ao_veiculo_sair`; e o gate por quadro em `_processar_playing` (após as guardas existentes, com `if audio_manager:`): `audio_manager.ao_aceleracao_jogador(Input.is_action_pressed("accelerate") and not Input.is_action_pressed("brake"))` — contracts/audio_integration.md §2, research R11

**Checkpoint**: US1 + US2 funcionais — corrida com motores por tipo, som acompanha ciclo de vida dos veículos

---

## Phase 5: User Story 3 - Áudio coerente com estados, modos e interfaces (Priority: P3)

**Goal**: pausa **suspende** e retomada **restaura** sem reiniciar; vitória/fim/menu/READY ficam em silêncio controlado; o áudio funciona nos 3 modos sem alterar velocidades nem fatores.

**Independent Test**: quickstart §3.4–§3.5 — ciclar pausa/retomada, vencer, morrer, navegar menus e trocar modos; suítes `audio_state_flow_test` + `audio_modes_test` verdes.

### Tests for User Story 3

- [X] T012 [P] [US3] Criar tests/unit/audio_state_flow_test.gd (GdUnit4): matriz completa de estados — PLAYING liga os NPCs registrados (o jogador **não** é ligado na virada: `voz_jogador_tocando() == false`, só após `ao_aceleracao_jogador(true)` — Q3/I9), PAUSED aplica `stream_paused = true` em todas as vozes e a retomada restaura **sem reiniciar** (posição mantida; o gate segue o último flag — retomar acelerando ⇒ som do jogador volta, solto ⇒ segue mudo, correção no 1º quadro via forward), VICTORY/GAME_OVER/MENU/READY ⇒ `stop()` + `stream_paused = false`, estado desconhecido ⇒ parar tudo (falha segura); colisão em voo pausa junto na PAUSED e morre nas saídas; duas viradas no mesmo quadro ⇒ **a última vence**; integração com `add_child` assertando `AudioStreamPlayer.playing`/`stream_paused` reais (driver dummy) e, com um `GameplayManager` em árvore — mesmo padrão de `tests/unit/difficulty_speed_test.gd` — `audio_manager.vozes_motor_totais() == GameConfig.traffic_max_vehicles + 1` após o `_ready` (derivação do orquestrador em T004) — SC-006, SC-007, data-model.md §5, research R2/R3/R4/R11
- [X] T013 [P] [US3] Criar tests/unit/audio_modes_test.gd (GdUnit4): nos 3 modos da SPEC-009 (injeção como as suítes `difficulty_*`), atividade completa de áudio (configurar, spawns dos 3 tipos, colisões, viradas de estado) **não altera** `DifficultyManager.fator_velocidade_total()` nem `GameConfig.max_speed`/`TrafficData.max_speed`; efeito AUD-002/003 segue ativo em cada modo — SC-005, FR-005, research R10

### Implementation for User Story 3

- [X] T014 [US3] Refinar `ao_alterar_estado` em src/audio/audio_manager.gd: PAUSED ⇒ `stream_paused = true` em **todas** as vozes ativas (motor, jogador e colisão em voo) mantendo posição; PLAYING ⇒ `stream_paused = false` (retomada exata, sem reinício de loop); VICTORY/GAME_OVER/MENU/READY ⇒ `stop()` + reset do `stream_paused` (próxima corrida limpa); estado desconhecido ⇒ parar tudo (falha segura) — substitui a regra genérica "saída de PLAYING ⇒ stop" da T010 apenas no destino PAUSED, preservando as demais — data-model.md §5, research R3, contracts/audio_manager_api.md §3

**Checkpoint**: todas as US funcionais — matriz de estados completa, modos sem mutação

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: regressão global, escopo e aceite humano

- [X] T015 [P] Rodar a suíte completa (comando do quickstart §2): as 63 suítes/389 casos legados verdes **sem ajuste** + as 5 suítes `audio_*` novas, exit 101, zero failures — SC-009/FR-008 (regressão zero de lógica) — **executado em 2026-10-16: 68 suítes / 412 casos, exit 101, 2 execuções consecutivas verdes (389 legados intactos + 23 novos)**
- [X] T016 Aceite manual do quickstart §3.1–§3.7 (os 12 critérios de §6 da spec) pelo usuário no build completo: motores/colisões/ciclo de vida/estados/modos/arquivo ausente/desempenho; registrar o resultado (e eventuais ajustes da calibração §5) nesta phase, no padrão do aceite manual das specs anteriores — spec §6 e §8.6 — **concluído em 2026-10-16: executado pelo usuário com sucesso; nenhum ponto da calibração §5 se manifestou (aceite sem ajustes de valores)**
- [X] T017 [P] Registrar a contagem final de suítes/casos na tabela do quickstart.md §4 (hoje prevista como "contagem em tasks.md") e conferir que a lista das 5 suítes bate com o entregue — **contagem (68/412) registrada na §4; lista das 5 suítes confere**
- [X] T018 [P] Atualizar a seção "Estado atual" do AGENTS.md com o status da SPEC-010 (tarefas concluídas, suítes novas, pendência do aceite manual T016) — padrão da SPEC-009 (T027)
- [X] T019 [P] Revisão de conformidade final em specs/010-basic-audio-system/spec.md §7 vs src/ (zero itens fora de escopo implementados), bloco `## Áudio` único em src/config/game_config.gd (zero números/caminhos mágicos fora dele), comentários/docs em pt-BR, zero texto de usuário novo, diff contendo apenas mudanças da SPEC-010 (constitution §Definição de Concluído/§Disciplina de Mudanças) — **revisado em 2026-10-16: §7 limpa, bloco único, pt-BR, sem texto novo, diff só SPEC-010**

**Checkpoint**: feature concluída — suíte verde, aceite registrado, escopo conferido

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: sem dependências — iniciar imediatamente (T001 ∥ T002)
- **Foundational (Phase 2)**: depende do T001 (chaves do `cfg`) — BLOQUEIA todas as US; T002 bloqueia apenas a execução dos testes que carregam MP3
- **US1 (Phase 3)**: depende do Phase 2 — sem dependências de outras US
- **US2 (Phase 4)**: depende do Phase 2 — independente da US1 (arquivos distintos; só `gameplay_manager.gd` é compartilhado)
- **US3 (Phase 5)**: depende do Phase 2; **refina o `ao_alterar_estado` estendido pela US2 (T010)** — funcionalmente as asserções de som contínuo (pausa/retomada) exigem a US2 implementada; com Foundational apenas, o refinamento da T014 afetaria só a colisão em voo da US1
- **Polish (Phase 6)**: depende das US desejadas (MVP = US1 para T015 parcial; a suíte completa T015 e o aceite T016 exigem US1–US3)

### User Story Dependencies

- **US1 (P1)**: após Foundational — totalmente independente (MVP)
- **US2 (P2)**: após Foundational — independente
- **US3 (P3)**: após Foundational + implementação da US2 (mesmo método `ao_alterar_estado`, mesmo arquivo) — critérios verificáveis com as suítes da fase

### Within Each User Story

- Testes escritos primeiro (devem falhar antes da implementação)
- Implementação no `audio_manager.gd` antes do wiring correspondente no `gameplay_manager.gd`
- Config (T001–T002) → Foundation (T003–T005) → impl da história → testes → suíte global → aceite manual

### Parallel Opportunities

- T001 ∥ T002 (arquivos distintos)
- T003 ∥ T004 ∥ T005 após T001 (src novo × game_manager × tests — arquivos distintos; T004 roda em seguida no mesmo arquivo dos wirings seguintes)
- US1: T006 (tests) ∥ T007 (impl); depois T008 (wiring)
- US2: T009 ∥ T010; depois T011 (wiring)
- US3: T012 ∥ T013 (duas suítes) → T014 (impl)
- Histórias US1/US2 podem rodar em paralelo entre si após Foundational (exceto `gameplay_manager.gd` — serializar T008/T011 com T004)
- Polish: T015 → T016 → T017 ∥ T018 ∥ T019

---

## Parallel Example: User Story 1

```bash
# Juntos (arquivos distintos, após Phase 2):
Task: "tests/unit/audio_collision_test.gd (T006)"
Task: "src/audio/audio_manager.gd — tocar_colisao (T007)"

# Em sequência por dependência (método precisa existir):
Task: "src/game/gameplay_manager.gd — forwards de colisão (T008)"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 (T001–T002) + Phase 2 (T003–T005)
2. Phase 3 completa (T006–T008)
3. **PARAR E VALIDAR**: quickstart §3.2 + suíte `audio_*` até aqui
4. Nesse ponto o jogo já emite feedback sonoro de colisão — valor entregue sozinho

### Incremental Delivery

1. Setup + Foundational → `AudioManager` criado, configurado e recebendo estado
2. + US1 → som de colisão (MVP)
3. + US2 → motores por tipo de veículo com ciclo de vida completo
4. + US3 → estados finos (pausa/retomada/silêncios) e modos
5. Polish → regressão global, aceite manual e conformidade

### Notes

- [P] = arquivos distintos, sem dependências entre tarefas pendentes
- Tarefas de wiring no `gameplay_manager.gd` (T004, T008, T011) serializam (mesmo arquivo)
- `audio_manager == null` com guards mantém as 63 suítes legadas intactas sem nenhum ajuste (SC-009)
- Reprodução sempre exige `is_inside_tree()` — testes de lógica rodam sem árvore, integração com `add_child` (research R2/R7)
- Pendência manual: T016 (aceite do quickstart §3.1–§3.7) segue o padrão T020/T028/T053 das specs anteriores — resultado registrado nesta phase quando executado

## Phase 7: Convergence

- [X] T020 [P] [US3] Estender `tests/unit/audio_state_flow_test.gd` para cobrir o gate do jogador na matriz de estados: ligar a voz 0 com `ao_aceleracao_jogador(true)` antes da virada para PAUSED, afirmar `stream_paused == true` na voz 0 do jogador junto com as demais vozes, e na retomada afirmar que a voz 0 volta a tocar quando o flag preservado está `true` e permanece muda quando `false` (correção no 1º quadro via forward de `ao_aceleracao_jogador`) per US3/AC1, T012 (partial)
- [X] T021 [P] [US3] Completar as asserções de não-mutação em `tests/unit/audio_modes_test.gd`: as 4 bases de `GameConfig.TRAFFIC_CATEGORIES` (incluindo `esporte` e `utilitario`) e o campo `max_speed` das instâncias `TrafficData` dos 3 NPCs criados após a atividade completa de áudio per T013, SC-005, FR-005 (partial)
- [X] T022 [P] [US1] Adicionar em `tests/unit/audio_collision_test.gd` a asserção física de reprodução (`_vozes_colisao[indice].playing == true` logo após `tocar_colisao()` em PLAYING), além do bookkeeping de ocupação, para provar SC-002/US1/AC2 em nível de `AudioStreamPlayer` per T006, SC-002 (partial)

## Phase 8: Convergence

- [X] T023 [P] Atualizar a contagem da suíte pós-Phase 7: em `specs/010-basic-audio-system/quickstart.md` §4 trocar "68 suítes / 412 casos" por "68 suítes / 414 casos" e "5 suítes / 23 casos novas" por "5 suítes / 25 casos novas" (63/389 legados inalterados); em `AGENTS.md` §"Estado atual" espelhar 414 casos / 25 casos novos e o status "T001–T015, T017–T023 `[X]`" com T016 pendente (mantendo a frase de TDD e as demais referências) per T017, T018 (partial)
