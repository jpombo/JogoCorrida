# Research: Sistema de Colisão entre NPCs (SPEC-006)

**Date**: 2026-10-07 | **Branch**: `006-npc-collision-system`

O Technical Context não deixou nenhum item como NEEDS CLARIFICATION — Godot/GDScript, GdUnit4 e os contratos das SPECs 001–005 são o stack consolidado. As decisões abaixo resolvem os pontos de design em aberto, incluindo os dois itens adiados para o plano pela clarificação de 2026-10-07 (ordem determinística de processamento de pares e valores de limiares).

## R1 — Modelo de previsão: tempo até o encontro (TTC) contra janela de atividade conjunta

- **Decision**: Para cada par de candidatos (trajetórias lateralmente sobrepostas), calcular `diferenca = v_traseiro − v_dianteiro`; se `diferenca <= npc_min_relative_speed`, não há aproximação relevante. Caso contrário, `ttc = distancia_longitudinal / diferenca`. A colisão é **potencial** somente quando `ttc <= janela`, onde a janela é o menor tempo até o descarte dos dois veículos (baseado na distância de cada um até a borda de reciclagem ÷ sua velocidade aparente na tela) acrescido de `npc_active_area_margin` e limitado por `npc_collision_prediction_horizon`. A janela é recalculada com o estado atual da pista (largura/vias vigentes), as velocidades correntes e o movimento relativo.
- **Rationale**: FR-003/FR-004 exigem exatamente essa relação (distância ÷ diferença de velocidade, comparada à janela); usar o tempo até o descarte de **cada um dos dois** resolve simultaneamente o falso positivo (encontro só depois da reciclagem — SC-001 Cenário 2) e o falso negativo (encontro ainda dentro da área ativa). Limiar `npc_min_relative_speed` cobre o Edge Case "diferença de velocidade menor que o limiar".
- **Alternatives considered**: Distância fixa de segurança (rejeitada: não se adapta à velocidade nem ao tempo de permanência, violaria FR-005); previsão por simulação de N quadros (rejeitada: custo maior e dependente de passo de simulação — TTC analítico é exato para velocidades constantes no intervalo).

## R2 — Detecção por interseção de Rect2 e classificação em 2 tipos

- **Decision**: Reusar o padrão da SPEC-005 — `Rect2.intersects` sobre as hitboxes configuradas por categoria (`GameConfig.NPC_HITBOX_SIZES`, fallback em `get_occupied_area()`), sem `Area2D` nem servidor de física. Classificar em exatamente um de dois tipos pelo eixo de menor penetração: penetração vertical menor → **longitudinal** (o traseiro com maior velocidade relativa é quem alcança → causador); penetração horizontal menor → **lateral** (quem fecha a trajetória do outro é o causador — o veículo cujo deslocamento lateral invadiu a coluna do vizinho). Empates e margem neutra resolvidos por `npc_relative_position_threshold`, de forma determinística.
- **Rationale**: FR-010/FR-011 exigem geometria do contato, não direção fixa; o critério de menor penetração já está validado e testado na SPEC-005 (mesma convenção, um tipo a menos). Identificar causador/atingido pela dinâmica (quem alcança / quem invadiu) atende FR-013 sem heurística nova.
- **Alternatives considered**: Classificação pela velocidade de aproximação apenas (rejeitada: dois veículos lado a lado não têm aproximação longitudinal e ainda assim colidem); 4 tipos como a SPEC-005 (rejeitada: a spec exige 2 tipos, jogador não participa).

## R3 — Drift por veículo: `NpcDriftState` com fallback de borda e transferência ao causador

- **Decision**: Um `NpcDriftState` por `TrafficVehicle` (máximo 1 ativo), com as mesmas fases da SPEC-005 (`NORMAL → IMPACTO → DRIFT → RECUPERACAO → NORMAL`), mas **sem fator de controle** (o NPC não tem input) e **sem `x_origem`** — a Clarificação Q1 determinou permanência onde o drift terminar (FR-022). Direção normal = lado oposto ao impacto (posição relativa com margem neutra, FR-015). Se o atingido está dentro de `npc_border_margin` da borda e a direção normal não comporta o deslocamento → tenta o lado oposto; se nenhum lado comporta → o deslocamento é aplicado **ao causador** (também clampado) — FR-019. Todo `update` recebe os limites vigentes **na altura do próprio veículo** por quadro (`Road.get_boundaries_for_player_y(y)`), nunca largura memorizada (FR-018, FR-040).
- **Rationale**: Copia deliberada do padrão `DriftState` (máquina explícita, substituição em novo impacto — Clarificação Q4/FR-014), o que mantém consistência entre os dois sistemas de colisão e reutiliza a lógica de clamp que já existe. A transferência ao causador é o único mecanismo que satisfaz o invariante "nenhum sai da pista" no caso de corredor estreito com dois veículos largos (Edge Case).
- **Alternatives considered**: Retorno à faixa de origem como o `NpcOvertakeState` (rejeitado: Clarificação Q1 manteve a permanência); rotação/angulação do veículo (rejeitada: FR-043 proíbe física realista); cancelar o drift ao encontrar a borda (rejeitado: perderia a consequência perceptível exigida pela constituição).

## R4 — Cadeia: registro explícito de processados + cadeias paralelas independentes

- **Decision**: Um objeto `NpcChainState` por cadeia ativa: `id` monotônico, `profundidade_atual`, `tempo_restante` (de `npc_chain_timeout`), `profundidade_maxima` (`npc_max_chain_depth`) e conjunto de `instance_id`s já processados. O **elo de encadeamento** é exclusivamente o deslocamento do NPC atingido: um impacto herdou a cadeia (e `profundidade + 1`) apenas quando o atingido, **durante o seu drift**, atinge um terceiro veículo. Colisões paralelas sem esse elo iniciam cadeia própria, mesmo dentro do tempo de expiração da anterior (Clarificação Q5, FR-024, US5-CA8). Veículo já processado na cadeia → impacto descartado (FR-025, SC-008 = 0 loops).
- **Rationale**: A clarificação Q5 exige separação de cadeias por **relação**, não por tempo — o conjunto de processados + o portador do elo (drift ativo herdeiro) é o estado mínimo que distingue os dois casos de forma determinística. Profundidade real limitada pelo teto de ativos (5), então `npc_max_chain_depth` é o limite efetivo (Edge Case).
- **Alternatives considered**: Herdar cadeia por proximidade temporal (rejeitado: viola Q5/US5-CA8); grafo de colisões persistente (rejeitado: complexidade sem ganho — a cadeia expira e é descartada); limite global de colisões por segundo (rejeitado: não garante 0 loops nem profundidade).

## R5 — Cooldown por par não ordenado, com rearmento após separação

- **Decision**: Dicionário com chave canônica do par `"{min(idA,idB)}:{max(idA,idB)}" → tempo_restante`, decrementado por quadro. Enquanto ativo: nenhum evento e nenhuma consequência (FR-027). Pares distintos são independentes — A↔B bloqueado não impede B↔C (SC-009). Rearmamento somente após os dois caírem fora da sobreposição **e** o cooldown expirar (mesmo critério R5 da SPEC-005: protege o impacto, não o veículo), resolvendo o Edge Case "cooldown expira com os dois ainda sobrepostos".
- **Rationale**: A chave canônica elimina a simetria A,B / B,A; o conjunto de sobrepostos por par é o que impede recontagem do mesmo contato físico. Padrão já validado e testado na SPEC-005, agora generalizado de `npc_id` para `par de npc_ids`.
- **Alternatives considered**: Cooldown global (rejeitado: SC-009 exige B↔C livre); cooldown por veículo (rejeitado: um veículo em cooldown bloquearia pares legítimos); rearmento só por tempo (rejeitado: geraria evento novo sem novo contato real).

## R6 — Evento informativo e encaminhamento ao sistema da SPEC-005

- **Decision**: Sinal `npc_collision_occurred(data: NpcCollisionData)` emitido **uma única vez** por colisão válida, com os 7 campos de FR-041 (causador, atingido, tipo, intensidade, direção do drift, id da cadeia, profundidade). Nenhum ouvinte obrigatório. A detecção **jogador×NPC continua exclusiva do `CollisionSystem`** (FR-037): o novo sistema ignora o jogador na sua própria avaliação; se um NPC deslocado pelo drift tocar o jogador, é o próprio `CollisionSystem` da SPEC-005 que detecta e emite o seu evento — exatamente um (FR-038, SC-015), sem código de contato jogador duplicado.
- **Rationale**: Constituição III exige comunicação por eventos; FR-041 lista os 7 campos. A divisão de responsabilidade é o ponto de integração mais simples possível: dois sistemas, dois sinais, zero duplicação — o jogador permanece fora da avaliação NPC×NPC (FR-009: presença do jogador não bloqueia previsão entre NPCs, mas também não gera evento novo).
- **Alternatives considered**: Um único sistema para jogador e NPCs (rejeitado: violaria FR-037 e arriscaria regressão da SPEC-005); barramento global de eventos (rejeitado: indireção prematura, mesmo racional da R6 da SPEC-005).

## R7 — Validação de spawn como API consultada pelo TrafficManager

- **Decision**: `NpcCollisionSystem` expõe `validar_spawn(categoria, x, y, bounds) -> Dictionary` com veredito `{"aceito": bool, "x": float, "y": float, "adiar": bool}`: (1) testa sobreposição imediata (`traffic_min_separation` + hitbox) e conflito imediato; (2) testa o futuro pela mesma R1 (TTC dentro da janela → conflito; encontro após o descarte → aceita, FR-030); (3) se conflitante, o `TrafficManager` tenta a próxima posição/lane candidata e depois outras faixas; (4) sem opção → **mantém o candidato pendente e o revalida no quadro seguinte** (Clarificação Q3, FR-029), sem zerar o cronômetro de intervalo — a reposição abaixo de `traffic_min_visible` (FR-063 do SPEC-004) continua um-por-quadro e nunca é perdida.
- **Rationale**: O fluxo "outra posição → outra faixa → adiar" cabe exatamente onde o `_tentar_spawn` já recusa hoje (retornos cedo). Revalidar por quadro com posições atualizadas reproduz o comportamento já usado pelo SPEC-004 para faixa ocupada. A janela garante que conflitos pós-descarte não bloqueiem (FR-030, SC-010).
- **Alternatives considered**: Perder o nascimento até o próximo intervalo (rejeitado: Clarificação Q3 e FR-029 — quebraria a densidade mínima); validação dentro do próprio TrafficManager (rejeitada: duplicaria a regra da janela e misturaria geração com colisão, contra FR-036/§Trânsito).

## R8 — Reavaliação orientada a eventos + periódica configurável

- **Decision**: Dois gatilhos, ambos configuráveis: (a) **eventos** — spawn/reciclagem de NPC, início/fim de drift, mudança de configuração da pista (`segment_type_changed`/`boundary_changed`), entrada/saída de PLAYING; (b) **periódico** — a cada `npc_reevaluation_interval` segundos; além disso, uma **mudança relevante da velocidade do jogador** (variação absoluta > `npc_player_speed_change_threshold`, medida por quadro) dispara reavaliação imediata (FR-032/FR-033, US8). A reavaliação recalcula os vereditos dos pares candidatos; ela **nunca cria** colisão — só o contato (interseção) gera evento, sempre sujeito à regra da janela no momento da avaliação (FR-035, SC-012).
- **Rationale**: FR-008/FR-045 proibem avaliar todos os pares a cada quadro sem exigir frequência fixa; a combinação eventos+periódico é o trade-off clássico custo×respostividade e satisfaz "sob demanda e por atualização periódica configurável". O limiar do jogador resolve US8 sem reagir a micro-variações (ruído do analógico/aceleração).
- **Alternatives considered**: Reavaliação a cada quadro (rejeitada: FR-045 — desnecessária com teto de 5 ativos e custa em GC/alocação); somente por eventos (rejeitada: não capta a mudança de tempo de permanência sem evento novo — US8); batch a cada N quadros fixos (mantida como implementação do periódico, mas com intervalo em segundos para ser configurável).

## R9 — Ordem de processamento determinística e wiring

- **Decision**: (1) **Ordem determinística de pares**: os pares candidatos são ordenados a cada avaliação por `(y_candidato_cima, instance_id)` estável — resolve o Edge Case "três ou mais NPCs sobrepostos" sem aleatoriedade (item adiado para o plano). (2) **Wiring em `gameplay_manager.gd`**: `npc_collision_system.update()` roda **depois** de `traffic_layer.update()` e **antes/depois** do `collision_system.update()` — escolha: **antes** do SPEC-005, para que um NPC já deslocado pela colisão NPC×NPC ocupe a posição final do quadro quando o sistema do jogador for avaliar (coerente com "colisão roda depois do trânsito, posições finais do quadro"). Limites virão de `Callable(road, "get_boundaries_for_player_y")`, como já faz o SPEC-005.
- **Rationale**: Chaves ordenadas estáveis são a forma mais simples de determinismo testável; a ordem de wiring garante que SC-015 (1 evento do SPEC-005 quando o NPC deslocado toca o jogador) seja observável no mesmo quadro do contato, sem frame de atraso.
- **Alternatives considered**: Ordem aleatória/da pool (rejeitada: não determinística, quebra testes); avaliação em `_physics_process` (rejeitada: introduce passo de física onde não existe; todo o gameplay é manual por quadro).

## R10 — Invariante de velocidade: isolamento e verificação

- **Decision**: O `NpcCollisionSystem` e o `NpcDriftState` **não possuem qualquer caminho de escrita em velocidade** — os únicos campos de `TrafficVehicle` tocados são `position.x` (drift, clampado) e o novo estado de drift. A velocidade continua vindo exclusivamente da categoria (`get_speed()`), já que nem scroll nem dificuldade podem ser afetados (Assumptions). A verificação é automatizada: teste que amostra `get_speed()` antes/durante/depois de colisões e cadeias e exige igualdade exata (SC-014), além da regressão `test_traffic_speed_ordering.gd` (SPEC-004) que valida as taxas por corredor.
- **Rationale**: A Clarificação Q2 elevou "nenhuma mudança de velocidade" a restrição dura; a forma mais robusta de garantir é **não existir o código**, não confiar em disciplina. O teste de igualdade exata captura qualquer tentativa futura de acoplar física de impacto ao trânsito.
- **Alternatives considered**: Salvar/restaurar velocidade após o impacto (rejeitada: cria caminho de escrita desnecessário e falharia em cadeias; não é mais simples); multiplicador temporário de velocidade (rejeitado: viola Q2 explicitamente).

## Valores de configuração (adiados pela clarificação)

Todos em `GameConfig`, blocos `npc_*` (FR-044), com estes iniciais — nenhum fixo na lógica (SC-017):

| Parâmetro | Padrão | Papel |
|-----------|--------|-------|
| `npc_collision_cooldown` | 0.8 s | cooldown por par (R5) |
| `npc_drift_force_min/max` | 40 / 120 px/s | força do drift interpolada pela intensidade |
| `npc_drift_duration_min/max` | 0.3 / 0.9 s | duração do drift |
| `npc_drift_recovery_rate` | 1.4 /s | taxa de recuperação das fases |
| `npc_relative_position_threshold` | 4.0 px | margem neutra da direção (R2/R3) |
| `npc_border_margin` | 20.0 px | distância que define "próximo da borda" (R3) |
| `npc_max_chain_depth` | 3 | profundidade máxima da cadeia (R4) |
| `npc_chain_timeout` | 2.0 s | expiração da cadeia (R4) |
| `npc_displacement_limit` | 48.0 px | teto de deslocamento lateral por impacto (FR-020) |
| `npc_spawn_safety_distance` | 60. px | distância mínima de segurança de spawn (R7) |
| `npc_collision_prediction_horizon` | 3.0 s | teto do horizonte de previsão (R1) |
| `npc_min_relative_speed` | 1.0 px/s | limiar de aproximação relevante (R1) |
| `npc_active_area_margin` | 40. px | margem da área ativa na janela (R1) |
| `npc_max_active` | projeção somente leitura do teto por dificuldade do SPEC-004 (nenhum valor novo) | teto de ativos (FR-042) |
| `npc_reevaluation_interval` | 0.25 s | atualização periódica (R8) |
| `npc_player_speed_change_threshold` | 10.0 unidades/s | "mudança relevante" do jogador (R8) |

*Notas de abertura*: os padrões são ponto de partida calibrável (a suíte valida invariantes, não valores); `npc_displacement_limit` deve acomodar 176 px de pista expandida com dois caminhões (30 px de largura) — o teste de borda calibra o valor junto com `npc_border_margin`.
