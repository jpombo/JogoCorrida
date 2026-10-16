# Implementation Plan: Sistema de Dificuldade e Balanceamento

**Branch**: `009-difficulty-balancing` | **Date**: 2026-10-12 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/009-difficulty-balancing/spec.md`

## Summary

Três modos de dificuldade (Relaxante 1,0×, Normal 3,0×, Desafio 4,0×) com multiplicador único de velocidade aplicado a jogador e NPCs, parâmetros de balanceamento por modo (densidade de trânsito, frequência/distância de galões, penalidade de colisão) e progressão infinita de ambientes (planície → deserto → floresta → gelo → planície…) com bônus de +0,2% de velocidade por ciclo de 4 vitórias — reutilizando os sistemas das SPEC-001 a SPEC-008:

- **`DifficultyManager` (novo, `src/difficulty/`)**: componente próprio de configuração efetiva (constitution §III/§IV) — dono do modo vigente e dos fatores por modo lidos do bloco novo `GameConfig.difficulty_modes`; expõe `fator_velocidade_total() = multiplicador_modo × fator_ciclo` e `efetiva(base)`; modo inválido cai em Normal (FR-001/FR-002). Instanciado pelo `GameplayManager` e injetado por referência nos sistemas (player controller, TrafficManager, FuelCanManager, FuelSystem, UIManager) — sem estado global novo, sem dependência circular.
- **Velocidade-base × efetiva (FR-003)**: `GameConfig.max_speed` e `TrafficData.max_speed` permanecem intocados; o fator é lido no ponto de cálculo — `VehicleController` ganha `fator_dificuldade` (teto, aceleração, frenagem e desaceleração natural escalados juntos para preservar a curva normalizada — SC-003) e `TrafficVehicle.get_speed()` passa a `base × fator` (nunca muta `TRAFFIC_CATEGORIES`); aplicação no nascimento dos NPCs + fator compartilhado por corrida (modo fixo por corrida).
- **Combustível coerente (FR-013)**: `_taxa_consumo` normaliza pelo teto efetivo e multiplica a taxa pelo fator de velocidade — consumo por km constante em todos os modos, mantendo o dimensionamento derivado da SPEC-008 válido (SC-008); penalidade de colisão = `collision_fuel_penalty[ambiente] × fator_penalidade` aplicada no único ponto atual (`FuelSystem.on_player_collision`).
- **Trânsito e galões**: densidade-alvo efetiva = `teto_do_ambiente × fator_densidade`, limitada pelo teto absoluto `traffic_max_vehicles` (FR-008); geração de galões com `taxa_ambiente × fator_frequência` e `intervalo × fator_distância` (FR-009/FR-011), piso/teto e validações existentes intactos.
- **Progressão infinita (novo `RaceProgression`, `src/game/`)**: posição na sequência `GameConfig.environment_sequence`, vitórias do ciclo e ciclos concluídos, só em sessão (FR-019/FR-023); vitória registra e avança (`pos = (pos+1) % 4`, a cada 4 vitórias `ciclos++`), derrota zera posição/vitórias preservando ciclos; o avanço de fase usa a propagação **já existente** de `GameConfig.current_environment_id` em runtime (detecção por quadro no `GameplayManager._process` — SPEC-008/T061).
- **Fluxos de fim de corrida (FR-020/FR-021)**: vitória vira [Continuar próxima fase → sinal novo `continue_next_phase` | Voltar ao menu] e Fim de Jogo vira [Voltar ao menu] — removendo "Tentar novamente" das duas telas; menu ganha a 3ª linha "Modo" que cicla com `ui_accept` (placeholder da SPEC-013, FR-016).

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.7.2)

**Primary Dependencies**: `GameConfig` (autoload — bloco novo `difficulty_modes`, `environment_sequence`, `difficulty_cycle_bonus_increment`, rótulos `ui_*`), `GameState` (autoload — transições intactas), `VehicleController` (`speed`/`max_speed`/aceleração — ganha `fator_dificuldade`), `TrafficVehicle`/`TrafficData` (`get_speed()` base × fator), `TrafficManager` (`_maximo_visivel_atual()`, `_nascer()`), `FuelSystem` (`_taxa_consumo`, `on_player_collision` — +2 campos de fator), `FuelCanManager` (`_tentar_gerar`), `UIManager` (menu 3 linhas, sinais de fim), `GameplayManager` (orquestração: injeção, `_on_start_race`, `_avaliar_transicoes`, handlers de fim), propagação existente de `current_environment_id`

**Storage**: N/A (parâmetros no autoload `GameConfig`; modo e progresso vivem na sessão, sem persistência — recordes fora do escopo)

**Testing**: GdUnit4 em `tests/unit/` (50 suítes/324 casos atuais + 9 novas `difficulty_*`/`cycle_*`; runner `addons/gdUnit4/runtest.sh --headless` — exit 101 quando verde)

**Target Platform**: Desktop (Linux, Windows, macOS) via Godot export templates

**Project Type**: 2D arcade racing game (pixel art, top-down)

**Performance Goals**: 60 FPS meta / 30 FPS piso — custo novo por quadro: 1 multiplicação no cálculo de velocidade do jogador e de cada NPC (≤12 ativos), 1 leitura de densidade com fator, 1 produto na taxa de combustível; zero alocação por quadro; zero timer novo

**Constraints**:
- Multiplicador aplicado **uma única vez**, em ponto único por sistema; velocidades-base nunca sobrescritas (FR-003, SC-002)
- Relaxante (1,0× × ciclo 1,000) = comportamento exatamente atual — suíte existente deve permanecer verde sem ajustes (SC-003, R12)
- Consumo por km constante entre modos; capacidade derivada da SPEC-008 continua válida (FR-013)
- Densidade efetiva nunca ultrapassa `traffic_max_vehicles`; memória de spawn e geração intactas (FR-008)
- Colisões detectadas em 3×/4× sem atravessamento; penalidade única por evento (FR-014)
- Temporizadores/estados/UI nunca escalados pelo multiplicador (FR-007, SC-003)
- Modo fixo por corrida; Normal padrão; configuração constante do início ao fim (FR-001/FR-006)
- Textos de usuário externalizados em `GameConfig.ui_strings`; docs/comentários em pt-BR (§VI)
- Zero regressão das SPEC-001–008; controles, assets e hitboxes intocados (FR-018)

**Scale/Scope**: 4 user stories, 23 FRs, 17 SCs, 3 entidades novas, ~10 parâmetros novos de configuração, 2 scripts novos (`difficulty_manager.gd`, `race_progression.gd`), 1 diretório novo (`src/difficulty/`), wiring aditivo em 8 scripts existentes (+campos/métodos, nenhum reescrito), 9 suítes novas

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Status | Verificação |
|-----------|--------|-------------|
| I. Controles Simples, Gameplay Profundo | ✅ PASS | Zero controles novos — seletor de modo usa `ui_accept`/`ui_up`/`ui_down` existentes; profundidade vem dos modos e da progressão, exatamente o "aumento de dificuldade" do enunciado do jogo |
| II. Prioridade da Experiência do Jogador | ✅ PASS | Relaxante é porta de entrada acessível; Fim de Jogo com saída simples (Q1-A); vitória com avanço claro (Q1/FR-020); bônus de ciclo torna o desvio mais desafiador sem truques de controle |
| III. Arquitetura Modular | ✅ PASS | `DifficultyManager` (parâmetros efetivos) e `RaceProgression` (estado de sessão) são módulos de responsabilidade única; sistemas existentes apenas recebem fatores — nenhum sistema paralelo de trânsito/combustível/colisão (FR-018) |
| IV. Design Orientado a Configuração | ✅ PASS | Bloco `## Dificuldade e Progressão (SPEC-009)`: `difficulty_modes` (5 fatores × 3 modos), `environment_sequence`, `difficulty_cycle_bonus_increment`, rótulos — zero constante de balanceamento na lógica; fórmula do bônus derivada da configuração |
| V. Autoridade da Constituição e Proteção de Escopo | ✅ PASS | §Dificuldade autoriza literalmente velocidade, densidade, combustível e consequências de colisão como alavas; nada da lista proibida; menu completo/som/recordes seguem fora de escopo |
| VI. Suporte Multilíngue e Língua da Documentação | ✅ PASS | Docs em pt-BR; todos os textos novos (Modo/Relaxante/Normal/Desafio/Continuar próxima fase) externalizados em `ui_strings` |
| Regras — Veículo do Jogador | ✅ PASS | Fator escala teto+aceleração+frenagem mantendo a curva (SC-003); 4 controles intactos; largada inicia em zero; reset não toca no fator |
| Regras — Física do Veículo | ✅ PASS | Arcade preservado — sem física nova; só escala de parâmetros configuráveis já previstos |
| Regras — Comportamento de Colisão | ✅ PASS | Pipeline SPEC-005/006 intacto; só a penalidade de combustível ganha fator (aplicada no FuelSystem); drift/durações inalterados |
| Regras — Sistema de Combustível | ✅ PASS | FuelSystem mantém autoridade; consumo escalado de forma coerente (R3); capacidade derivada intocada; esgotamento/vitória/GAME_OVER preservados |
| Regras — Pista | ✅ PASS | Distância percorrida acompanha a velocidade efetiva pela mesma rolagem (FR-007); total/configuração por corrida inalterados |
| Regras — Trânsito | ✅ PASS | Identidade, memória de spawn, nascimento validado e limites intactos; só a densidade-alvo e a velocidade de cada veículo recebem fatores |
| Regras — Estado de Jogo | ✅ PASS | Transições continuam exclusivas do `GameState`; avanço de fase é comando de UI → orquestrador (nenhum objeto de gameplay decide estado) |
| Regras — Dificuldade | ✅ PASS | **Núcleo desta spec**: alavas exatamente as listadas (número/densidade/velocidade/combustível/consequências), todas configuráveis; controles inalterados |
| Estratégia — Disciplina de Mudanças | ✅ PASS | 2 scripts novos isolados; alterações aditivas (+campo de fator, +linhas de menu, +sinal, +bloco de config); nenhum sistema reescrito |
| Testes | ✅ PASS | §`### Testes` da constituição (cobertura automatizada da lógica determinística crítica + testes MUST pós-mudança de gameplay) coberta por suítes novas automatizadas (multiplicadores, base preservada, sem acúmulo, densidade, galões, penalidade, ciclos, telas) + aceite manual do quickstart |
| Qualidade de Código | ✅ PASS | Responsabilidade única; fallback seguro (modo inválido → Normal; fator ausente → 1,0); comentários em pt-BR; sem valores mágicos |
| Performance | ✅ PASS | Fatores são floats lidos por quadro sem alloc; densidade máxima +1 NPC; pools intactos |
| Independência de Assets | ✅ PASS | Nenhum asset modificado; UI construída com as primitivas Label/ColorRect existentes |

**Resultado: PASS — 0 violações.** A §Dificuldade da constituição prevê exatamente estas alavas; nenhum gate de fase anterior fica aberto.

**Re-check pós-design (Fase 1)**: gerados `research.md` (R1–R13), `data-model.md` (3 entidades novas + mapeamento de código), `contracts/` (3 contratos) e `quickstart.md`. **Nenhuma violação nova**: injeção de fatores por referência mantém os módulos independentes (§III); fórmulas derivadas de constantes de config (§IV); FuelSystem única autoridade do combustível (§Combustível); transições continuam no `GameState` (§Estado de Jogo); UI só emite comandos (FR-005/008 herdados). **Resultado do re-check: PASS (0 pendências).**

## Project Structure

### Documentation (this feature)

```text
specs/009-difficulty-balancing/
├── plan.md              # Este arquivo (/speckit.plan)
├── research.md          # Phase 0 — R1–R13
├── data-model.md        # Phase 1 — entidades e transições
├── quickstart.md        # Phase 1 — guia de validação
├── contracts/
│   ├── difficulty_manager_api.md   # Interface do DifficultyManager + injeção
│   ├── environment_cycle.md        # Sequência, progressão e fluxos de fim
│   └── ui_commands.md              # Menu 3 linhas, sinais, telas de fim
└── tasks.md             # Phase 2 (/speckit.tasks — NÃO criado pelo plan)
```

### Source Code (repository root)

```text
src/
├── difficulty/
│   └── difficulty_manager.gd     # NOVO — modo + fatores efetivos (RefCounted)
├── game/
│   ├── race_progression.gd       # NOVO — posição/vitórias/ciclos (RefCounted)
│   ├── gameplay_manager.gd       # wiring: injeção, handlers de fim, sync de ambiente
│   └── game_state.gd             # intacto
├── config/
│   └── game_config.gd            # +bloco ## Dificuldade e Progressão (SPEC-009)
├── player/
│   ├── vehicle_controller.gd     # +fator_dificuldade (teto/accel/frenagem/decel)
│   └── player_vehicle.gd         # intacto (get_speed delega ao controller)
├── traffic/
│   ├── traffic_manager.gd        # +dificuldade; densidade-alvo × fator; fator no nascimento
│   └── traffic_vehicle.gd        # +fator_dificuldade; get_speed() = base × fator
├── items/
│   └── fuel_can_manager.gd       # +dificuldade; taxa × fator_freq; intervalo × fator_dist
├── fuel/
│   └── fuel_system.gd            # +fator_velocidade (taxa) e +fator_penalidade_colisao
└── ui/
    └── ui_manager.gd             # 3ª linha "Modo"; vitória 2 opções; game over 1 opção; sinal continue_next_phase

tests/unit/
├── difficulty_manager_test.gd        # NOVO — modos, fatores, fallback
├── difficulty_speed_test.gd          # NOVO — jogador/NPCs 1×/3×/4×, base preservada, sem acúmulo
├── difficulty_fuel_test.gd           # NOVO — consumo por km constante, penalidade × fator
├── difficulty_traffic_can_test.gd    # NOVO — densidade, ordem de frequência, limites
├── cycle_progression_test.gd         # NOVO — sequência, bônus 0,002, derrota zera ciclo
├── cycle_flow_test.gd                # NOVO — opções das telas, continue_next_phase, sync de ambiente
├── difficulty_environment_matrix_test.gd # NOVO — 4 ambientes × 3 modos (SC-011)
├── difficulty_stability_test.gd       # NOVO — cenário máximo 4,0× + 1,20× (SC-013)
├── difficulty_state_flow_test.gd      # NOVO — estados por modo, pausa/reinício (SC-010)
└── (suítes existentes permanecem verde — regressão 1,0×)
```

**Structure Decision**: monogame Godot — `src/` por subsystem, como nas SPECs anteriores; componentes novos seguem o padrão `RefCounted` de `TrackManager`/`FuelSystem` instanciados pelo `GameplayManager` (não autoloads, não Nodes de cena — testáveis sem a árvore).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Nenhuma violação — tabela vazia.
