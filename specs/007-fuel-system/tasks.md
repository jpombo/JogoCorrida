---

description: "Task list template for feature implementation"
---

# Tasks: Sistema de Combustível (SPEC-007)

**Input**: Design documents from `/specs/007-fuel-system/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: **OBRIGATÓRIOS** — a spec exige explicitamente os 27 testes do texto-fonte (Assumptions: "Testes obrigatórios"), **cobertos pelos ranges** (os 27 testes não equivalem 1 a 1 aos 31 cenários — mapeamento detalhado na premissa): US1 = T1–10, US2 = T16–25, US3 = T11–14, US4 = T15 e 26, US5 = T27.

**Organization**: Tarefas agrupadas por user story para implementação e teste independentes.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Pode rodar em paralelo (arquivos diferentes, sem dependências)
- **[Story]**: User story da tarefa (ex.: US1, US2)
- Caminhos exatos em cada descrição (convenção: `src/`, `tests/` na raiz)

## Path Conventions

- Projeto único Godot 4.7: `src/`, `tests/unit/` na raiz do repositório
- Nomenclatura de parâmetros e eventos conforme FR-034 e `contracts/fuel_events.md` (prefixo `fuel_`)

---

## Phase 1: Setup (Infraestrutura Compartilhada)

**Purpose**: Bloco de configuração e esqueleto do módulo — base compartilhada de todas as stories

- [X] T001 Add bloco `## Combustível (SPEC-007)` em src/config/game_config.gd com os parâmetros FR-027 (`fuel_capacity=100.0`, `fuel_initial_amount=-1.0`, `fuel_consumption_idle=0.0`, `fuel_consumption_min=0.6`, `fuel_consumption_max=2.0`, `fuel_consumption_speed_factor=1.4`, `fuel_low_threshold=0.2`, `fuel_low_label="BAIXO"`) como `@export`, conforme data-model.md §2 e research.md R9
- [X] T002 [P] Create esqueleto de src/fuel/fuel_system.gd com `extends Node`, os 3 sinais (`fuel_changed(atual: float, capacidade: float)`, `fuel_low()`, `fuel_depleted()`), stubs dos métodos públicos (`reset`, `update`, `on_player_collision`, `esta_baixo`, `get_atual`, `get_capacidade`) e campos privados (`_baixo_sinalizado`, `_esgotado_emitido`) — assinaturas exatas de contracts/fuel_events.md

---

## Phase 2: Foundational (Pré-requisito Bloqueante)

**Purpose**: Núcleo de estado do tanque que TODAS as stories dependem

**⚠️ CRITICAL**: Nenhuma user story começa antes desta fase

- [X] T003 Implement núcleo de estado em src/fuel/fuel_system.gd: campos `atual`/`capacidade`, `reset()` com sentinela `-1 ⇒ capacidade` + clamp `[0, capacidade]` + emissão de `fuel_changed` + chamada ao stub `_avaliar_limiar()` (R4/R5), `get_atual()`/`get_capacidade()`, e emissão de `fuel_changed` (com `is_equal_approx`) em toda escrita — contrato data-model.md §1

**Checkpoint**: Fundação pronta — as 5 user stories podem começar

---

## Phase 3: User Story 1 - Administrar o combustível consumido ao longo da corrida (Priority: P1) 🎯 MVP

**Goal**: Tanque inicia cheio/configurado e consome continuamente por `taxa × delta` conforme a velocidade, com clamps — a mecânica base de administrar velocidade

**Independent Test**: Partidas sintéticas em velocidades constantes baixa/alta (total maior na alta); mesma duração em 30/60/120 Hz com desvio < 1%; zerar e parar em 0; inicialização exatamente 1× por partida. Sem penalidades, eventos ou interface.

### Tests for User Story 1 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T004 [P] [US1] Create tests/unit/fuel_consumption_test.gd cobrindo os testes obrigatórios 1–10: init cheio (1), init configurado + clamp de valor inicial (2), velocidade baixa vs alta (3–4), curva ao acelerar/desacelerar/frear (5–7), repouso = `fuel_consumption_idle` (8), mesma duração em 30/60/120 Hz desvio < 1% (9), clamp em zero/capacidade (10), **e gating de inicialização (SC-001): transição READY→PLAYING re-inicializa o tanque (valor = capacidade) e PAUSED→PLAYING NÃO re-inicializa (valor preservado)** — para o gating, instanciar `GameplayManager` sem adicionar à árvore, injetar o `fuel_system` e chamar o handler de transição diretamente; padrão GdUnit4 de `tests/unit/collision_event_test.gd`, instanciando `FuelSystem.new()` e chamando `update(delta, velocidade)` sintético

### Implementation for User Story 1

- [X] T005 [US1] Implement modelo de consumo em `update()` em src/fuel/fuel_system.gd: `normalizada = clamp(velocidade / GameConfig.max_speed, 0, 1)`, `taxa = idle` se `velocidade <= 0` senão `clamp(min + normalizada × fator, min, max)`, `atual = clamp(atual − taxa × delta, 0, capacidade)`, no-op se `atual == 0`, emitindo `fuel_changed` — research.md R1, FR-004…FR-010 (depends: T003, T004)
- [X] T006 [US1] Wire ciclo de vida em src/game/gameplay_manager.gd: instanciar `FuelSystem.new()` em `_ready`; chamar `fuel_system.reset()` somente quando `old == READY && new == PLAYING` em `_on_state_changed`; manter `_on_state_changed(new_state, old_state)` dependente apenas do campo `fuel_system` (sem referências de cena) para permitir o teste de gating da T004; chamar `fuel_system.update(_delta, player_vehicle.get_speed())` após `collision_system.update(...)` no ramo `PLAYING` de `_process` — research.md R4/R12 (depends: T005)

**Checkpoint**: US1 funcional e testável sozinha — validação manual: barra não existe ainda; conferir por teste que o valor drena

---

## Phase 4: User Story 2 - Sofrer consequência de combustível nas colisões conforme o ambiente (Priority: P1)

**Goal**: Colisão válida do jogador desconta 0 (PLAINS/DESERT) ou valor pequeno (FOREST/ICE) por evento, acumulativo e sem retroatividade; NPC×NPC = 0

**Independent Test**: Eventos de colisão em cada um dos 4 ambientes (0, 0, pequeno, pequeno); N colisões = N descontos; evento ausente (NPC×NPC) = inalterado; troca de ambiente entre colisões usa o valor novo.

### Tests for User Story 2 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T007 [P] [US2] Create tests/unit/fuel_collision_penalty_test.gd cobrindo os testes obrigatórios 16–25: penalidade 0 em PLAINS (16) e DESERT (17), valor em FOREST (18) e ICE (19), equivalência FOREST=ICE (20), acúmulo N colisões = N descontos (21), no máximo 1 desconto por evento/contato (22), NPC×NPC não altera (23), troca de ambiente sem retroatividade (24), clamp a zero com esgotamento normal (25) — mutando `GameConfig.current_environment_id` e restaurando em `after_test`

### Implementation for User Story 2

- [X] T008 [US2] Implement `on_player_collision()` em src/fuel/fuel_system.gd: ler `GameConfig.current_environment_id` no momento, descontar `collision_fuel_penalty.get(ambiente, 0.0)` com `clamp(atual, 0, capacidade)`, emitir `fuel_changed` — research.md R2/R3, FR-011…FR-017 (depends: T007)
- [X] T009 [US2] Connect `collision_system.collision_occurred.connect(fuel_system.on_player_collision)` em `_ready` de src/game/gameplay_manager.gd — sem deduplicação própria (o 005 já garante 1 evento por colisão válida) — research.md R12 (depends: T008)

**Checkpoint**: US2 funcional — colisão em floresta/gelo desconta; regressão 005 mantida

---

## Phase 5: User Story 3 - Ser avisado uma única vez quando o combustível esgotar (Priority: P1)

**Goal**: `fuel_depleted` emitido exatamente 1× por esgotamento (qualquer origem), sem consumo/negativo pós-zero, sem tocar em física/estados

**Independent Test**: Zerar por consumo → 1 evento; zerar por penalidade em ICE → 1 evento; rodar após zero → valor 0, sem novos eventos; nenhuma tela de Game Over e velocidade inalterada.

### Tests for User Story 3 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T010 [P] [US3] Create tests/unit/fuel_depletion_test.gd cobrindo os testes obrigatórios 11–14: cruza zero pelo consumo → para em 0 e detecta no mesmo passo (11), penalidade não deixa negativo (12), pós-esgotado sem consumo/penalidade (13), exatamente 1 evento por ocorrência independentemente da origem (14), e asserção de FR-021/US3-AS5: pós-esgotado nenhum sinal além de `fuel_changed`/`fuel_depleted` é emitido (nenhum evento de estado/falha nasce aqui; verificação integrada de GAME_OVER no passo 8 do quickstart)

### Implementation for User Story 3

- [X] T011 [US3] Implement latch de esgotamento em src/fuel/fuel_system.gd: flag `_esgotado_emitido` emitindo `fuel_depleted()` na primeira atingida de zero em `update()` **e** em `on_player_collision()`, rearma somente em `reset()`, e `update()` vira no-op de consumo com `atual == 0` — research.md R5, FR-018…FR-021, bordas 12/14/16 (depends: T010; integra com T005/T008)

**Checkpoint**: US3 funcional — gatilho confiável pronto para a SPEC-008 consumir

---

## Phase 6: User Story 4 - Acompanhar o nível de combustível e o alerta de baixo na tela (Priority: P2)

**Goal**: Detecção de combustível baixo (evento 1× + estado consultável) e HUD mínimo observador: barra por cor + rótulo estático "BAIXO" persistente enquanto durar a condição

**Independent Test**: Alterar combustível → barra acompanha; cruzar o limite → cor + rótulo visíveis; tentar modificar pela UI → nada muda.

### Tests for User Story 4 (OBRIGATÓRIOS — escrever PRIMEIRO, devem FALHAR antes da implementação)

- [X] T012 [P] [US4] Create tests/unit/fuel_low_event_test.gd cobrindo o teste obrigatório 15: detecção de combustível baixo — travessia do limiar `atual/capacidade <= fuel_low_threshold` emite 1×, sem repetição enquanto persistir, `esta_baixo()` verdadeiro, init abaixo do limiar sinaliza desde o início sem duplicar (borda 10)
- [X] T013 [P] [US4] Create tests/unit/fuel_hud_test.gd cobrindo o teste obrigatório 26: proporção da barra sempre = `atual/capacidade` (H1), cor + rótulo visíveis ⇔ `esta_baixo()` (H2/H3), UI não modifica `fuel_system.get_atual()` (H5/SC-015) — instanciando `fuel_hud.gd` headless conforme contracts/hud_indicator.md

### Implementation for User Story 4

- [X] T014 [US4] Implement detecção de baixo em src/fuel/fuel_system.gd: `_avaliar_limiar()` com guard de `capacidade > 0`, emissão única de `fuel_low` por travessia via latch `_baixo_sinalizado` (chamada também no `reset()` p/ borda 10), `esta_baixo()` derivado — research.md R5, FR-022…FR-024 (depends: T012)
- [X] T015 [P] [US4] Create src/ui/fuel_hud.gd: `setup(fuel_system)`, `_on_fuel_changed` ajustando largura do `Preenchimento` (`ColorRect`, escala inteira), cor + visibilidade do `Label` (`GameConfig.fuel_low_label`, sem literal) — regras H1–H5 de contracts/hud_indicator.md, composição de research.md R7 (depends: contrato; stub de `esta_baixo` já existe)
- [X] T016 [US4] Add CanvasLayer `FuelHudLayer` em src/game/gameplay.tscn (Control retângulo total `mouse_filter=IGNORE`, `Fundo`/`Preenchimento` ColorRect pixel-alinhados, `Label`) e chamar `fuel_hud.setup(fuel_system)` em `_ready` de src/game/gameplay_manager.gd (conexões não duplicadas — H4) — depends: T014, T015

**Checkpoint**: US4 funcional — indicador visível na partida seguindo a Clarification 2026-10-09

---

## Phase 7: User Story 5 - Ajustar o balanceamento sem mexer na lógica (Priority: P2)

**Goal**: Todos os `fuel_*` + `collision_fuel_penalty` ajustáveis só por configuração, com valores calibrados por testes de gameplay (FR-028)

**Independent Test**: Alterar cada parâmetro apenas em `GameConfig` e observar o efeito; nenhum teste anterior quebra; nenhum arquivo de lógica alterado.

### Tests for User Story 5 (OBRIGATÓRIOS — escrever PRIMEIRO; este teste pode nascer verde pois exercita config já existente — executar e confirmar)

- [X] T017 [P] [US5] Create tests/unit/fuel_config_test.gd cobrindo o teste obrigatório 27: mutar cada parâmetro (`fuel_capacity`, `fuel_initial_amount`, `fuel_consumption_idle/min/max/speed_factor`, `fuel_low_threshold`, `collision_fuel_penalty`) e afirmar o efeito correspondente em `update()`/`on_player_collision()`/limiar, restaurando tudo em `after_test` — FR-026, SC-016

### Implementation for User Story 5

- [X] T018 [US5] Calibrar sementes por testes de gameplay seguindo quickstart.md (passos 1–10): **tanque cheio dura entre 45 e 90 s em velocidade máxima (SC-018, benchmark provisório do FR-028)**, consumo administrável, **penalidade de FOREST/ICE entre 2% e 10% da capacidade e idêntica entre os dois ambientes (SC-019)** — ajustar APENAS valores em src/config/game_config.gd conforme objetivos FR-028 (depends: T001, T005, T008)

**Checkpoint**: Balanceamento iterável sem tocar em lógica

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Regressão, validação ponta a ponta e documentação

- [X] T019 [P] Run suíte completa `GODOT_BIN=<godot> bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit` e corrigir regressões — esperado exit 101, 35 suítes existentes + 6 novas = 41, zero falha das SPECs 001–006 (SC-017)
- [ ] T020 Run validação manual de quickstart.md (10 passos no editor Godot) e registrar ajustes de calibração/visual — SC-001, SC-008…SC-015, bordas observáveis
- [X] T021 [P] Review de conformidade em src/fuel/fuel_system.gd e src/ui/fuel_hud.gd: 0 números de balance fixos na lógica (FR-026), 0 literal de texto de usuário (§VI — só `GameConfig.fuel_low_label`), comentários em pt-BR (§VI), nenhuma escrita fora do domínio do combustível (FR-029/FR-030)
- [X] T022 [P] Update AGENTS.md seção "Estado atual" (+ README.md se listar specs concluídas) marcando SPEC-007 como implementada, seguindo o padrão das SPECs anteriores

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Sem dependências — início imediato (T001 ∥ T002)
- **Foundational (Phase 2)**: Depende do Setup — **BLOQUEIA todas as user stories**
- **User Stories (Phase 3–7)**: Todas dependem da Foundational
  - Ordem de prioridade: US1 (P1, MVP) → US2 (P1) → US3 (P1) → US4 (P2) → US5 (P2)
  - US2 depende de US1 apenas pelo consumo compartilhado (estado/reset já vêm da Foundational); US3 depende dos caminhos de escrita de US1+US2; US4 depende do estado + eventos (independente de HUD-testavel assim que T014 existir); US5 fecha o ciclo após o modelo todo
- **Polish (Final)**: Depende das stories desejadas (mínimo: US1 para MVP; completo: US1–US5)

### User Story Dependencies

- **US1 (P1)**: Inicia após Foundational — sem dependência de outras stories (MVP)
- **US2 (P1)**: Após Foundational; usa o mesmo estado/reset de US1 (já existentes na fundação T003) — teste independente via chamadas diretas de `on_player_collision()`
- **US3 (P1)**: Após escritas de US1 (consumo) e US2 (penalidade) implementadas — os 4 testes cobrem as duas origens
- **US4 (P2)**: Após estado existir; lógica de limiar (T014) ∥ HUD (T015); integração em T016
- **US5 (P2)**: Após US1–US4 (calibração precisa do modelo completo)

### Within Each User Story

- Testes escritos e **falhando** antes da implementação (TDD — exceto T27, que valida config já existente)
- Estado → consumo → penalidade → esgotamento → baixo/HUD → calibração
- Cada checkpoint permite validação independente

### Parallel Opportunities

- T001 ∥ T002 (arquivos diferentes)
- Todos os arquivos de teste são independentes entre si: T004, T007, T010, T012, T013, T017 podem ser escritos em paralelo assim que T002 existir (stubs)
- T015 (HUD) ∥ T014 (limiar) após T003
- T019, T021, T022 (Polish) ∥ entre si
- Stories paralelas com equipe maior: US2-tests ∥ US1-impl; US4-impl ∥ US2/US3-impl (arquivos distintos)

---

## Parallel Example: User Story 2

```bash
# Duas tarefas em paralelo (arquivos diferentes, sem dependência entre si):
Task: "Create tests/unit/fuel_collision_penalty_test.gd cobrindo testes 16–25"
Task: "Create tests/unit/fuel_depletion_test.gd cobrindo testes 11–14"   # US3, outro arquivo

# Em seguida, sequencial dentro da US2:
Task: "Implement on_player_collision() em src/fuel/fuel_system.gd"        # depends: testes falhando
Task: "Connect collision_occurred → on_player_collision em src/game/gameplay_manager.gd"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Completar Phase 1: Setup (T001–T002)
2. Completar Phase 2: Foundational (T003) — CRÍTICO
3. Completar Phase 3: US1 (T004→T006)
4. **PARAR e VALIDAR**: suíte `fuel_consumption_test.gd` verde + rodada manual sem colisão
5. Entregável: mecânica de administrar velocidade para a corrida durar

### Incremental Delivery

1. Setup + Foundational → fundação pronta
2. US1 → teste independente → **MVP!**
3. US2 → teste independente → colisão passa a custar combustível nos ambientes avançados
4. US3 → teste independente → gatilho único de esgotamento confiável
5. US4 → teste independente → jogador enxerga o recurso (Clarification B aplicada)
6. US5 → calibração sem tocar em lógica
7. Polish → regressão total (41 suítes, exit 101) + validação manual

### Notes

- [P] = arquivos diferentes, sem dependências; [Story] = rastreabilidade à story
- Cada story é completável e testável de forma independente
- Commits por task ou grupo lógico (somente quando solicitado)
- Parar em cada checkpoint para validar a story
- Evitar: tasks vagas, conflitos no mesmo arquivo, dependências que quebrem a independência
