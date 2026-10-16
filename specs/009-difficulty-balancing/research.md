# Research: Sistema de Dificuldade e Balanceamento (SPEC-009)

**Data**: 2026-10-12 | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

Decisões técnicas que resolvem os unknowns do plano. Nenhum NEEDS CLARIFICATION restante.

---

## R1 — Ponto único do multiplicador de velocidade (base × efetiva)

**Decision**: As velocidades-base permanecem intactas (`GameConfig.max_speed = 100.0` un; `TrafficData.max_speed` derivado de `max_speed_kmh × KMH_TO_SPEED_UNIT`). O fator de velocidade total (`multiplicador_modo × fator_ciclo`) vive no `DifficultyManager` e é **lido nos pontos de cálculo** de cada sistema, nunca gravado na config:

- `VehicleController.fator_dificuldade: float` — definido no início de cada corrida; `_apply_vertical_physics` usa `GameConfig.max_speed × fator`, `GameConfig.acceleration × fator`, `GameConfig.brake_force × fator` e `GameConfig.natural_deceleration × fator`; `get_vertical_position()` normaliza por `max_speed × fator` (razão continua em [0, 1]).
- `TrafficVehicle.fator_dificuldade: float` — definido no `activate()` pelo `TrafficManager`; `get_speed()` retorna `category.max_speed × fator` (hoje retorna `category.max_speed` puro).

**Rationale**: Um único ponto de cálculo por sistema (§5.4 da spec) sem nunca mutar `TRAFFIC_CATEGORIES`/`GameConfig` — mutação destrutiva seria sobrescrita permanente da base e causaria acúmulo em reexecuções (FR-003 proíbe). Injeção por float mantém `VehicleController`/`TrafficVehicle` testáveis sem o DifficultyManager (padrão já usado: `update_boundaries`, `fator` de scroll).

**Alternatives considered**:
- *Gravar `max_speed` efetivo em `GameConfig`/`TrafficData` no início da corrida*: rejeitado — sobrescreve a base (viola FR-003), quebra o cache de categorias compartilhadas e sobrevive a resets.
- *Singleton/autoload DifficultyManager*: rejeitado — estado global novo; o projeto instancia componentes no `GameplayManager` (§III).
- *Passar DifficultyManager como dependência tipada aos veículos*: rejeitado — acoplamento maior que um float; testes existentes do controller não mudam.

## R2 — Escala de aceleração, frenagem e posição vertical

**Decision**: O fator escala **teto, aceleração, frenagem e desaceleração natural** juntos. Tempo até a máxima em segundos é idêntico em todos os modos (`tmax = max/(accel)` invariante); a curva normalizada `speed/(max × fator)` coincide (SC-003). Movimento **lateral não é escalado** — a direção é a ferramenta de desvio e o spec mantém os 4 controles intactos; relativo ao avanço, desviar fica mais difícil (intenção do bônus de ciclo). `get_vertical_position()` usa o teto efetivo no denominador.

**Rationale**: §5.5 exige aceleração gradual sem "turbo instantâneo" e SC-003 exige curvas normalizadas coincidentes. Escalar só o teto dobraria o tempo até a máxima em Normal (percepção de "carro fraco"), por isso aceleração/frenagem acompanham.

**Alternatives considered**: *Escalar só o teto* — rejeitado (curva temporal não coincide); *escalar também o movimento lateral* — rejeitado (muda os controles/curva de desvio, que a constituição protege como inalterados).

## R3 — Consumo de combustível coerente (por km constante)

**Decision**: `FuelSystem` ganha `fator_velocidade: float` (definido por corrida, junto com a capacidade derivada). `_taxa_consumo(velocidade)` passa a:
`normalizada = clamp(velocidade / (GameConfig.max_speed × fator_velocidade), 0, 1)` e `taxa_final = taxa_modelo × fator_velocidade` (com o mesmo clamp [min, max] do modelo, agora sobre a taxa já escalada).

Efeito: em 3×/4× a taxa por segundo triplica/quadruplica junto com a velocidade → **consumo por km constante** → a fórmula da SPEC-008 (`capacidade = distância × consumo_por_distância + margem`, calibrada para 15%–35% de sobra) continua válida em todos os modos sem novo dimensionamento (SC-008). Aplicação única: o multiplicador entra só aqui — `update()` continua recebendo a velocidade efetiva e nada mais é multiplicado (FR-007/FR-013).

**Rationale**: O modelo atual é por tempo com normalização por velocidade; sem o ajuste, em 3×/4× a corrida consumiria ~1/3 a 1/4 de combustível por km (o tanque duraria 3–4× a distância — modo trivial). O consumo é o único efeito colateral não-movimento da velocidade e o spec exige coerência sem aplicação dupla.

**Alternatives considered**: *Deixar como está (torrar mais por segundo, mesmo por-km)* — rejeitado (distorce o balanceamento entre modos); *multiplicador próprio de consumo por modo* — rejeitado (a spec não define fator de consumo; a coerência é derivada da velocidade); *renormalizar pelo teto base* — rejeitado (clamperia `normalizada > 1` e a taxa saturaria no máximo sempre).

## R4 — Colisões em 3× e 4× (tunneling)

**Decision**: **Sem substepping na entrega.** Análise: no pior caso (Desafio + ciclo alto), jogador a 400+ un/s ≈ 6–7 un/quadro a 60 FPS; hitbox do jogador 22×44 px e NPCs ≥ 22×38 px — o deslocamento por quadro segue cerca de 5× menor que a menor hitbox; a detecção AABB por quadro (SPEC-005) continua capturando o encontro. Relative speed NPC×NPC escala igual (ambos × fator) — a janela de previsão do SPEC-006 é em tempo e acompanha. Entrega inclui **suítes de regressão de colisão a 3×/4×** (cenários determinísticos de encontro); se um cenário manual revelar atravessamento, o plano de contingência é substepping no `CollisionSystem.update` (2–3 passos por quadro), isolado e configurável — não é arquitetura nova.

**Rationale**: §9 exige detecção confiável sem alterar desnecessariamente a arquitetura; a aritmética mostra margem folgada.

**Alternatives considered**: *Substepping preventivo* — rejeitado (complexidade sem necessidade demonstrada); *raycast de velocidade* — rejeitado (muda o modelo de detecção da SPEC-005).

## R5 — Densidade de NPCs por modo

**Decision**: `TrafficManager._maximo_visivel_atual()` (hoje: `traffic_max_visible_by_difficulty[dificuldade_ambiente]`) passa a `int(teto_ambiente × difficulty.fator_densidade())`, com clamp `[traffic_min_visible, traffic_max_vehicles]`. Assim: Relaxante 0,70× (5→3), Normal 1,00× (5→5), Desafio 1,20× (5→6 ≤ teto absoluto 12) — o **teto absoluto** `traffic_max_vehicles` é o "limite máximo existente" que nunca é ultrapassado (FR-008); o teto por dificuldade do ambiente é a base escalada. `GameConfig.npc_max_active()` permanece como projeção base (somente leitura). Nenhum mecanismo novo de quantidade/spawn/memória (FR-008).

**Rationale**: O mecanismo de densidade-alvo já existe (`_maximo_visivel_atual`); o modo é um fator por cima. Escalar também o `traffic_max_vehicles` criaria segundo ponto de verdade.

**Alternatives considered**: *Escalar `traffic_spawn_interval`* — rejeitado (muda a taxa de nascimento, não a densidade-alvo; a spec fala em densidade); *criar tabela densidade×ambiente×modo* — rejeitado (explosão de config; fator único basta, ambiente já varia pela base).

## R6 — Frequência e distância de galões

**Decision**: Duas alavas, como a spec define, aplicadas no único ponto de geração (`FuelCanManager._tentar_gerar`): `taxa_efetiva = fuel_can_spawn_rate[ambiente] × fator_frequência` e `intervalo_efetivo = (fuel_can_spawn_interval_distance × fator_distância) / taxa_efetiva`. Piso/teto por corrida, teto de ativos, espaçamentos e posição válida permanecem intactos (FR-009/FR-011).

**Rationale**: As chaves de config já são distintas (`fuel_can_spawn_rate` por ambiente × `fuel_can_spawn_interval_distance` global) — cada fator acopla na sua, sem duplicar semântica; a ordem de disponibilidade Relaxante > Normal > Desafio sai por construção (1,5/0,8 > 1,0/1,0 > 0,65/1,2).

**Alternatives considered**: *Aplicar só um dos fatores* — rejeitado (a spec lista os dois parâmetros); *tabela intervalo×ambiente×modo* — rejeitado (mesmo motivo de R5).

## R7 — Penalidade de combustível por colisão

**Decision**: `FuelSystem` ganha `fator_penalidade_colisao: float` (definido por corrida). `on_player_collision` aplica `penalidade = collision_fuel_penalty[ambiente] × fator_penalidade` (clamp a zero preservado; `<= 0` continua no-op). Pontos preservados: 1 evento `collision_occurred` = 1 desconto, sem deduplicação própria; autoridade exclusiva do FuelSystem sobre o valor (FR-010).

**Rationale**: O ponto de leitura da penalidade já é único (`on_player_collision`); multiplicar lá garante aplicação única e combinação modo × ambiente (0 × fator = 0; planície/deserto continuam sem penalidade conforme a constituição admite).

**Alternatives considered**: *Escalar no CollisionSystem antes de emitir o sinal* — rejeitado (move autoridade do combustível para fora dele); *tabela penalidade×ambiente×modo* — rejeitado (fator basta e a spec define multiplicador, não tabela).

## R8 — Componente central: DifficultyManager + RaceProgression

**Decision**: Dois `RefCounted` novos, instanciados pelo `GameplayManager` (padrão `TrackManager`/`FuelSystem`):

- `src/difficulty/difficulty_manager.gd`: dono do modo vigente e dos 5 fatores lidos de `GameConfig.difficulty_modes`; `definir_modo(id)` (inválido → `difficulty_default_mode` = "normal"); `aplicar_fator_ciclo(f)`; getters puros (`fator_velocidade_total`, `fator_densidade`, …, `efetiva(base)`); `ciclar_modo()` para o menu.
- `src/game/race_progression.gd`: `posicao`, `vitorias_ciclo`, `ciclos_concluidos`; `ambiente_atual()`, `registra_vitoria()`, `zerar_ciclo_por_derrota()`, `fator_ciclo() = 1 + GameConfig.difficulty_cycle_bonus_increment × ciclos_concluidos`. Só memória de sessão (FR-023).

Injeção por referência (`traffic_layer.dificuldade = dificuldade`, `player_vehicle.controller.fator_dificuldade = …` etc.) feita uma vez no `_ready` + refresh por corrida em `_on_start_race` (fator de ciclo muda entre ciclos). Sistemas tratam referência nula/fator ausente como 1,0 (testes sem wiring).

**Rationale**: §III (módulos de responsabilidade única), §IV (dados no GameConfig, estado fora dele — misturar estado runtime no autoload já causou acoplamento nas specs anteriores). `DifficultyManager` = configuração efetiva (entidade da spec); `RaceProgression` = progresso da sessão (outra entidade da spec).

**Alternatives considered**: *Só GameConfig com campos runtime* — rejeitado (autoload vira estado global; dificulta reset/teste); *um único componente* — rejeitado (parâmetros do modo são config; progresso é estado — ciclos de vida diferentes; vitória não deve tocar nos parâmetros).

## R9 — Sequência de ambientes e propagação

**Decision**: `GameConfig.environment_sequence: Array = ["PLAINS", "DESERT", "FOREST", "ICE"]` (ordem da spec §7 + ponto 3 do adendo). O avanço usa a **propagação já existente**: escrever `GameConfig.current_environment_id` e o `GameplayManager._process` detecta a troca por quadro e chama `_propagar_ambiente` (fundo + decoração) — zero sinal novo, zero mudança no `EnvironmentManager` (FR-019). Pontos de sincronização:

- **Vitória** (`_avaliar_transicoes` → `race_won`): `progresso.registra_vitoria()` ANTES de `game_state.victory()` (a tela já mostra o estado avançado).
- **"Continuar próxima fase"** (`_on_continue_next_phase`): `GameConfig.current_environment_id = progresso.ambiente_atual()` → `_reset_corrida()` + `start_game()` (mesmo preparo do menu→READY).
- **"Voltar ao menu"** / início pelo menu (`_on_start_race`): sincroniza `current_environment_id = progresso.ambiente_atual()` antes do reset (cobre o pós-vitória com id ainda antigo e o pós-derrota já zerado para PLAINS).
- **Derrota** (`race_lost`): `progresso.zerar_ciclo_por_derrota()` (posição/vitórias zeradas; ciclos preservados — FR-023).
- **Reiniciar (pausa)**: mesma corrida/mesmo ambiente — não sincroniza nem avança.

**Rationale**: A detecção por quadro de `current_environment_id` foi desenhada exatamente para troca em runtime (SPEC-008/T061, comentário em `gameplay_manager.gd`); reutilizá-la fecha o requisito com mudança zero em SPEC-003.

**Alternatives considered**: *Sinal novo em EnvironmentManager* — rejeitado (dívida evitada na T061: "nada escreve em SPEC-003"); *passar ambiente por parâmetro do start_game* — rejeitado (alinha com o mecanismo já testado de propagação).

## R10 — Fluxos de fim de corrida e menu (UI)

**Decision**: `UIManager`:

- **Menu**: 3 linhas (0 = Selecionar veículo, 1 = **Modo: `<modo>`**, 2 = Iniciar corrida); navegação `ui_up`/`ui_down` (`wrapi(0, 3)`), destaque existente reposicionado; `ui_accept` na linha 1 emite `select_next_mode` (o `GameplayManager` cicla via `DifficultyManager.ciclar_modo()` e atualiza o rótulo — estado do modo fica no DifficultyManager, a UI só exibe/emite).
- **Vitória**: opções `[continue_next_phase, back_to_menu]` com sinal novo `continue_next_phase` ("Continuar próxima fase"); "Tentar novamente" removido (FR-020).
- **Game Over**: opções `[back_to_menu]` apenas (FR-021).
- `_process_fim` ganha mapeamento por painel (vitória: 0→`continue_next_phase`, 1→`go_to_menu`; fim: 0→`go_to_menu`).
- Novas chaves em `ui_strings`: `mode_label`, `mode_relaxing`, `mode_normal`, `mode_challenge`, `continue_next_phase`.

**Rationale**: Reusa o padrão de painéis/destaque já entregue (SPEC-008 Phase 13/14); o seletor é o placeholder da SPEC-013 aprovado na Q1-A; o estado do modo vive no DifficultyManager para não virar estado de UI (UI só observa/emite — FR-005/008 herdados).

**Alternatives considered**: *Linha de modo com setas esquerda/direita* — rejeitado (menu já usa up/down + accept; ações novas de nav horizontal poluem o padrão); *UIManager guarda o modo* — rejeitado (estado de gameplay na UI; a troca precisaria de sync extra).

## R11 — NPCs existentes e novos refletem o modo

**Decision**: Modo (e fator de ciclo) são **fixos por corrida**; todos os NPCs são resetados no início de cada corrida (`traffic_layer.reset()` em `_reset_corrida`) e o fator é gravado por veículo no `activate()` (nascimento). "NPCs ativos refletem o modo" é garantido porque (a) nenhum NPC sobrevive a troca de corrida e (b) o fator é um campo do veículo lido a cada quadro — se o fator de ciclo mudasse (só muda entre corridas), bastaria atualizar o campo compartilhado; o TrafficManager mantém também `fator_dificuldade` próprio para semear novos nascimentos.

**Rationale**: Sem mecanismo de "reatualizar todos os veículos" (frágil, O(n) por evento) — o ciclo de vida por corrida já torna a aplicação no nascimento equivalente à aplicação global.

**Alternatives considered**: *Atualizar todos os ativos a cada virada de corrida* — desnecessário (reset); *NPCs leem GameConfig diretamente* — rejeitado (acoplamento a estado global e impossível de simular modo nos testes sem GameConfig mutável).

## R12 — Regressão 1,0× (Relaxante = comportamento atual)

**Decision**: Relaxante = {velocidade 1,0; densidade 1,0; frequência 1,0; penalidade 1,0; distância 1,0} e ciclo 1 = fator 1,000 → fator total **exatamente 1,0**. Todos os cálculos novos são `valor × 1,0` — a suíte atual (324 casos) deve permanecer verde **sem nenhum ajuste**, servindo de prova de não-regressão (SC-003/SC-012). Normal (padrão) é 3,0× — só corridas explicitamente em Normal mudam de sensibilidade; os testes existentes que rodam corridas sem UI usam o estado default — **atenção na implementação**: sistemas sem injeção (`dificuldade == null`) devem usar fator 1,0, de modo que os testes legados (que não instanciam DifficultyManager) continuem no comportamento atual; o GameplayManager injeta 3,0× como default de sessão via Normal (comportamento intencional da spec).

**Rationale**: Fallback "valor ausente = 1,0" isola testes legados e torna a injeção opcional (robustez); o default do jogo (Normal) é decisão explícita da spec.

**Alternatives considered**: *Fallback 3,0× (Normal)* — rejeitado (quebraria 300+ casos legados e violaria a separação config/estado); *migrar toda a suíte* — rejeitado (esforço sem valor; o fallback já resolve).

## R13 — Calibração e testes de balanceamento

**Decision**: Os fatores provisionais da spec (0,70/1,00/1,20; 1,50/1,00/0,65; 0,50/1,00/1,50; 0,80/1,00/1,20; bônus 0,002) entram como sementes de config com comentários de calibração (padrão SPEC-005/008). Suítes automatizadas validam **relações e invariantes** (ordens, fórmulas, limites, não-acúmulo), não valores absolutos de gameplay; o ajuste fino perceptivo (concluibilidade em Desafio, sobra de combustível 15%–35% por modo, "sensação" de 4×) fica no **aceite manual do quickstart** (passos §3), como nas specs anteriores.

**Rationale**: Padrão já estabelecido (T055/calibração SPEC-008): automatizar o verificável, validar o perceptivo manualmente.

**Alternatives considered**: *Testes de simulação longa por modo* — parcialmente incluídos (corridas de referência curtas por modo), mas corridas de 5 km × 3 modos × 4 ambientes manteriam a suíte lenta demais; o quickstart cobre a ponta longa.
