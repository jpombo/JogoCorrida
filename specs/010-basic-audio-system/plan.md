# Implementation Plan: Sistema Básico de Áudio

**Branch**: `010-basic-audio-system` | **Date**: 2026-10-16 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/010-basic-audio-system/spec.md`

## Summary

Três efeitos sonoros MP3 (AUD-001 colisão, AUD-002 motor de caminhão, AUD-003 motor de carro) acionados pelos eventos dos sistemas existentes de colisão, trânsito e estado de jogo — mais o gate de aceleração do jogador (FR-003/Clarification Q3: o som dele só toca enquanto acelera) — reutilizando a arquitetura das SPEC-001 a SPEC-009, sem nenhuma mudança na lógica de gameplay:

- **`AudioManager` (novo, `src/audio/audio_manager.gd`)**: componente dedicado previsto na constituição §III — dono único da reprodução (RF-004): carrega os 3 streams uma vez (`ResourceLoader.exists` + `load`, arquivo ausente ⇒ efeito mudo, SC-008), mantém `loop = true` em runtime nos dois streams de motor (sonda R1: `AudioStreamMP3.loop` existe e é setável), e gerencia duas pools de `AudioStreamPlayer` **pré-criadas** — `vozes_motor = traffic_max_vehicles + 1` (voz dedicada do jogador + 12 NPCs) e `vozes_colisao = 3` (config) — com **zero nós novos por quadro e zero `_process`** (RF-004, constitution Performance).
- **Wiring por forwards do `GameplayManager`** (padrão `fuel_system.on_player_collision`): `collision_occurred` e `npc_collision_occurred` → `tocar_colisao()` (1 `play()` por evento; a deduplicação continua sendo dos sistemas SPEC-005/006); `vehicle_spawned`/`vehicle_recycled` → `ao_veiculo_surgir/sair` (associação 1:1 veículo→voz, sem sons órfãos — SC-004); `ao_alterar_estado` chamado **no fim** de `_on_state_changed` (após `_reset_corrida`/`_show_*`): PLAYING liga os NPCs, PAUSED pausa (`stream_paused`), MENU/READY/VICTORY/GAME_OVER param tudo (FR-006/SC-006/SC-007); e `ao_aceleracao_jogador(bool)` chamado **por quadro** em `_processar_playing` — o som do jogador só toca enquanto `accelerate` estiver pressionado sem `brake` (FR-003/Q3, R11).
- **Mapeamento por tipo**: jogador e NPCs não-caminhão ⇒ AUD-003; `category.id == GameConfig.audio_categoria_caminhao` ⇒ AUD-002 — a distinção vem dos dados já existentes (`TrafficData.id`), sem campo novo (FR-008/SC-003).
- **Zero acoplamento com dificuldade**: o `AudioManager` não referencia `DifficultyManager` nem multiplicadores — FR-005/SC-005 satisfeitos por construção; volumes lineares e caminhos de arquivo vivem no bloco novo `## Áudio (SPEC-010)` do `GameConfig` (§IV).

## Technical Context

**Language/Version**: GDScript (Godot Engine 4.7.2)

**Primary Dependencies**: `GameConfig` (autoload — bloco novo `audio_colisao_path`/`audio_caminhao_path`/`audio_carro_path`, `audio_vozes_colisao`, `audio_volume_motor`/`audio_volume_colisao`, `audio_categoria_caminhao`), `GameState` (autoload — transições intactas, só observadas), `CollisionSystem.collision_occurred`, `NpcCollisionSystem.npc_collision_occurred`, `TrafficManager.vehicle_spawned/vehicle_recycled`, `TrafficVehicle`/`TrafficData.id`, `GameplayManager` (orquestração: criação do componente, forwards, chamada de estado, gate de aceleração por quadro), `AudioStreamPlayer`/`AudioStreamMP3` (áudio nativo da engine)

**Storage**: N/A (sem persistência; 3 MP3 em `assets/audio/` — `colisao.mp3` 2,12 s, `caminhao.mp3`, `carro.mp3` — imports gerados pelo editor, regra existente do projeto)

**Testing**: GdUnit4 em `tests/unit/` (63 suítes/389 casos legados + **novas suítes `audio_*`** — lógica sem árvore + integração com `add_child` assertando `playing` real no driver dummy headless — contagem final em `tasks.md`; runner `addons/gdUnit4/runtest.sh --headless` — exit 101 quando verde)

**Target Platform**: Desktop (Linux, Windows, macOS) via Godot export templates

**Project Type**: 2D arcade racing game (pixel art, top-down)

**Performance Goals**: 60 FPS meta / 30 FPS piso — custo novo por quadro: **1 chamada de método + 2 leituras `Input.is_action_pressed` em PLAYING** (gate FR-003, via `_processar_playing` já existente; sem alocação e **zero `_process` no `AudioManager`**, R11); custo por evento: O(pool) constante; 16 `AudioStreamPlayer` estáticos no total (13 motor + 3 colisão), todos filhos do `AudioManager` criados uma única vez em `configurar()`

**Constraints**:
- Exatamente 3 efeitos MP3; **zero** item da lista "Fora do escopo" (trilha, música de menu, aceleração/drift, alertas, vitória/game over, volume por categoria, áudio espacial, efeitos por ambiente) — FR-008/§7
- Deduplicação de colisão é dos sistemas SPEC-005/006 — o áudio faz exatamente 1 `play()` por evento recebido, sem deduplicação própria além disso (FR-001/SC-002)
- Nenhuma mutação de velocidades nem de multiplicadores de modo; nenhuma leitura de `DifficultyManager` (FR-005/SC-005)
- Sons de gameplay somente em PLAYING (e o do jogador somente também enquanto acelerando — FR-003/Q3); pausa suspensa e retomada restaurada; vitória/fim/menu silenciados (FR-006/SC-006/SC-007)
- Zero mudança de comportamento em `GameState`, sistemas de colisão, trânsito, UI, física — suíte legada deve permanecer verde sem ajustes (SC-009/FR-008)
- Reprodução exige nó na árvore (sonda R2) — guarda `is_inside_tree()` + estado lógico sempre atualizado (testes sintéticos legados intactos)
- MP3 nativos, sem dependências externas, sem conversão para OGG (FR-007/§5)
- Docs, comentários e mensagens em pt-BR (§VI); nenhum texto de usuário novo (§VI trivial)

**Scale/Scope**: 3 user stories, 8 FRs, 9 SCs, 7 edge cases, 2 entidades lógicas novas (efeito sonoro, veículo sonorizado/voz), ~7 parâmetros novos de configuração, 1 script novo (`audio_manager.gd`), 1 diretório novo (`src/audio/`), wiring aditivo em 1 script existente (`gameplay_manager.gd` — +campo, +bloco em `_ready`, +4 conexões de sinal [colisão ×2, trânsito ×2], +1 chamada em `_on_state_changed`, +1 chamada por quadro em `_processar_playing` [gate de aceleração]), `game_config.gd` +bloco, 0 mudanças em cenas `.tscn` e 0 mudanças de comportamento em scripts de gameplay existentes (além do wiring do `gameplay_manager.gd`)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Princípio | Status | Verificação |
|-----------|--------|-------------|
| I. Controles Simples, Gameplay Profundo | ✅ PASS | Zero controles novos; o áudio é feedback de eventos já existentes (colisão, motor), exatamente o "efeitos sonoro" previsto na Fase 7 da estratégia incremental |
| II. Prioridade da Experiência do Jogador | ✅ PASS | US1 (feedback de colisão imediato) é P1 por valor sozinho para o jogador; escolhas de pausa (suspender/retomar) e silêncio de menu priorizam percepção sobre sofisticação técnica |
| III. Arquitetura Modular | ✅ PASS | `AudioManager` é nomeado literalmente na §III como sistema esperado; responsabilidade única (reprodução); comunica-se por sinais/forwards do orquestrador; nenhuma dependência direta entre sistemas não relacionados (não conhece GameState/Traffic/Collision — só recebe chamadas) |
| IV. Design Orientado a Configuração | ✅ PASS | Bloco `## Áudio (SPEC-010)`: caminhos dos 3 arquivos, vozes de colisão, volumes, categoria de caminhão — zero caminho/número mágico na lógica; pool de motor derivada de `traffic_max_vehicles` (fonte única da densidade) |
| V. Autoridade da Constituição e Proteção de Escopo | ✅ PASS | Nada da lista proibida (armas/multijogador/RPG/etc.); áudio é efeito de apresentação; §Comportamento de Colisão exige feedback sonoro "quando o áudio for implementado" — **esta spec cumpre esse MUST** |
| VI. Suporte Multilíngue e Língua da Documentação | ✅ PASS | Nenhum texto de usuário novo (áudio não gera string); docs/comentários em pt-BR |
| Regras — Veículo do Jogador | ✅ PASS | Física, controles e limites intocados; o áudio não lê nem escreve velocidade |
| Regras — Física do Veículo | ✅ PASS | Nenhuma alteração — o áudio só observa eventos |
| Regras — Comportamento de Colisão | ✅ PASS | **Cumpre o MUST de feedback sonoro** reutilizando os eventos da SPEC-005/006; física, deriva, penalidade e cooldown permanecem idênticos (FR-001/SC-002-caso3) |
| Regras — Sistema de Combustível | ✅ PASS | Intocado — sem som de alerta/coleta (§7 da spec) |
| Regras — Pista | ✅ PASS | Intocada — sem sons de início/chegada (§7) |
| Regras — Trânsito | ✅ PASS | Nascimento/reciclagem intactos — o áudio só observa `vehicle_spawned/recycled`; identidade (`TrafficData.id`) reaproveitada sem mutação |
| Regras — Estado de Jogo | ✅ PASS | Transições continuam exclusivas do `GameState`; o áudio **observa** `state_changed` (forward) e nunca decide estado (FR-006) |
| Regras — Dificuldade | ✅ PASS | Zero referência a multiplicadores/fatores; sons funcionam nos 3 modos por construção (FR-005/SC-005); controles e alavas inalterados |
| Estratégia — Disciplina de Mudanças | ✅ PASS | 1 script novo isolado; alterações aditivas em 2 scripts (+bloco de config, +wiring de forwards); nenhum sistema reescrito, nenhuma cena alterada |
| Testes | ✅ PASS | Lógica determinística nova (gating por estado, 1:1 veículo→voz, mapeamento de tipo, política de pool, arquivo ausente) coberta por suítes automatizadas novas `audio_*` + aceite manual do quickstart (audição humana) |
| Qualidade de Código | ✅ PASS | Responsabilidade única; falhas seguras (arquivo mudo, fora da árvore, pool esgotada, estado desconhecido ⇒ parar tudo); comentários em pt-BR; sem valores mágicos |
| Performance | ✅ PASS | Orientado a eventos com 1 leitura de input por quadro em PLAYING (gate FR-003 — sem alocação, sem objetos novos); zero `_process` no `AudioManager`, zero criação de nós por quadro, pools reutilizadas (constitution §Performance: proíbe criação de objetos por quadro, não a leitura de input) |
| Independência de Assets | ✅ PASS | Classificação por `category.id` (dado de configuração), nunca por nome de arquivo; trocar um MP3 = trocar um path no `GameConfig`; lógica de gameplay não conhece áudio |

**Resultado: PASS — 0 violações.** A §Comportamento de Colisão prevê este entrega ("feedback sonoro quando o áudio for implementado") e a §III nomeia o `AudioManager`; nenhum gate de fase anterior fica aberto.

**Re-check pós-design (Fase 1)**: gerados `research.md` (R1–R11), `data-model.md` (2 entidades + matriz de estados) e `contracts/` (2 contratos) + `quickstart.md`. **Nenhuma violação nova**: a guarda `is_inside_tree()` e o estado lógico em `configurar()` mantêm os testes legados sem árvore intactos (R2/§Testes); pools pré-criadas confirmam zero alloc por quadro (Performance); o wiring por forwards mantém o `AudioManager` sem dependências de sistemas (§III) e o `GameState` como única autoridade de transição (§Estado de Jogo); volumes/caminhos no `GameConfig` (§IV); quickstart em pt-BR sem texto de usuário (§VI). **Resultado do re-check: PASS (0 pendências).**

## Project Structure

### Documentation (this feature)

```text
specs/010-basic-audio-system/
├── plan.md              # Este arquivo (/speckit.plan)
├── research.md          # Phase 0 — R1–R11
├── data-model.md        # Phase 1 — entidades, vozes e matriz de estados
├── quickstart.md        # Phase 1 — guia de validação (aceite manual + suíte)
├── contracts/
│   ├── audio_manager_api.md   # Interface pública do AudioManager + invariantes
│   └── audio_integration.md   # Wiring no GameplayManager + bloco GameConfig
└── tasks.md             # Phase 2 (/speckit.tasks — NÃO criado pelo plan)
```

### Source Code (repository root)

```text
src/
├── audio/
│   └── audio_manager.gd        # NOVO — streams, pools de vozes, gating por estado (Node)
├── game/
│   ├── gameplay_manager.gd     # wiring: criação, forwards de colisão/trânsito, estado no fim de _on_state_changed
│   └── game_state.gd           # intacto (só observado)
├── config/
│   └── game_config.gd          # +bloco ## Áudio (SPEC-010) (7 parâmetros)
├── collision/
│   ├── collision_system.gd     # intacto (sinal collision_occurred só observado)
│   └── npc_collision_system.gd # intacto (sinal npc_collision_occurred só observado)
├── traffic/
│   ├── traffic_manager.gd      # intacto (sinais vehicle_spawned/recycled só observados)
│   └── traffic_vehicle.gd      # intacto (category.id só lido)
└── (demais subsystems intactos — player, track, items, fuel, ui, difficulty)

tests/unit/
├── audio_manager_test.gd       # NOVO — configurar, streams, arquivo mudo, idempotência (SC-001/SC-008)
├── audio_collision_test.gd     # NOVO — 1 play por evento, gating PLAYING, pool/roubo de voz (SC-002)
├── audio_engine_test.gd        # NOVO — mapeamento caminhão/carro, 1:1 veículo→voz, saída sem órfãos (SC-003/SC-004)
├── audio_state_flow_test.gd    # NOVO — PLAYING/PAUSED/VICTORY/GAME_OVER/MENU/READY (SC-006/SC-007)
├── audio_modes_test.gd         # NOVO — áudio não altera fatores/velocidades nos 3 modos (SC-005)
└── (suítes existentes permanecem verdes — regressão SC-009)
```

**Structure Decision**: monogame Godot — `src/` por subsystem, como nas SPECs anteriores; o `AudioManager` é a **exceção documentada** ao padrão `RefCounted` de `TrackManager`/`FuelSystem`: precisa ser `Node` porque os `AudioStreamPlayer` exigem um dono na árvore para reproduzir (sonda R2), mas mantém o padrão de criação — **instanciado pelo `GameplayManager` em `_ready`, não é autoload, não é nó de cena** (não altera `gameplay.tscn`; testes sintéticos o têm como `null` com guards, como `ui_root`/`track_layer`).

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

Nenhuma violação — tabela vazia.
