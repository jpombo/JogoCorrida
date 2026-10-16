# Quickstart — Validação da SPEC-008 (Progressão, Estados, Combustível e Galões)

**Data**: 2026-10-10 | **Objetivo**: rodar a suíte automatizada e validar manualmente os 9 testes obrigatórios (A–I) e os critérios de aceitação que exigem gameplay.

## 1. Pré-requisitos

```bash
# Binário do engine (versão do projeto)
export GODOT_BIN=$HOME/Downloads/_installers/Godot_v4.7.2-stable_linux.x86_64

# Imports dos assets: abrir o editor Godot UMA vez por máquina (arquivos *.import não vão para o git)
"$GODOT_BIN" -e --path . --quit
```

## 2. Suíte automatizada (SC-003/SC-004/SC-005/SC-009/SC-010/SC-011/SC-012/SC-013 + testes A–I)

```bash
GODOT_BIN=$GODOT_BIN bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit
```

**Esperado**: exit **101** = verde. Baseline atual: **41 suítes** (SPEC-007) → com a SPEC-008: **+9 suítes** abaixo (**50 suítes, 324 casos**); regressão zero nas SPECs 001–007 (SC-013/SC-014).

### Suítes novas e mapeamento aos 9 testes obrigatórios

| Suíte | Teste (texto-fonte) | User story | SC principais |
|---|---|---|---|
| `track_progression_test.gd` | A (início) + B (distância) | US2 | SC-002, SC-003, SC-004 |
| `track_finish_test.gd` | C (chegada) | US2/US3 | SC-004, SC-005 |
| `fuel_sizing_test.gd` | D (dimensionamento) + parte de F | US5 | SC-006, SC-008, SC-016 |
| `fuel_can_collection_test.gd` | E (coleta) | US6 | SC-009, SC-011 |
| `fuel_can_generation_test.gd` | F (dificuldade e geração) | US7 | SC-010, SC-011 |
| `fuel_game_over_flow_test.gd` | G (esgotado + coleta) | US4 | SC-007, SC-005 |
| `ui_screens_test.gd` | H (ciclo de vida — telas) | US1 | SC-001, SC-017 |
| `race_reset_test.gd` | H (ciclo de vida — reset) + I (regressão) | US1 | SC-012, SC-013 |
| `game_config_008_test.gd` | I (configuração) | US8 | SC-016 |

## 3. Validação manual (aceitação de gameplay)

Executar em `"$GODOT_BIN" --path .` (janela 640×480):

| # | Passo | Esperado |
|---|---|---|
| 1 | Abrir o jogo | Abre em `MENU` com **3 linhas** — "Selecionar veículo" + nome (azul/vermelho), "Modo: …" e "Iniciar corrida" (3ª linha e linha de modo acrescentadas pela SPEC-009); a opção ativa aparece com retângulo semitransparente de destaque, alternável com `ui_up`/`ui_down`; nenhum sistema avança |
| 2 | Destacar "Iniciar corrida" (`ui_down`) e iniciar | Corrida com o veículo **azul** (ou o escolhido); a banda `INÍCIO` (área quadriculada) e seu rótulo aparecem **imediatamente** com a pista, e some da tela ao avançar; indicador `Distância: 0,0 km / 5,0 km` |
| 3 | Acelerar / parar / só trocar de faixa | Distância cresce só com o avanço; parado e em mudança de faixa: **0** crescimento |
| 4 | Pausar (Escape) | `PAUSED` com "Continuar", "Reiniciar", "Voltar ao menu"; rolagem, consumo, trânsito, galões e indicador **congelados**; retomar sem salto |
| 5 | Dirigir até o fim sem coletar nada | `CHEGADA` se aproxima pela rolagem; ao cruzar **com combustível**: `VICTORY` uma única vez, com "Continuar próxima fase" e "Voltar ao menu" (opções da SPEC-009 FR-020 — substituem o "Tentar novamente" do FR-034 original) |
| 6 | Zerar o combustível (rodar sem coletar em ambiente difícil) | Aviso `BAIXO` (SPEC-007); com zero: sem aceleração, desaceleração **gradual**, distância ainda crescendo; ao parar sem concluir: `GAME_OVER` uma única vez, com **apenas "Voltar ao menu"** (SPEC-009 FR-021) |
| 7 | Coletar um galão durante a desaceleração | Combustível sobe na hora (cap no máximo), aceleração volta a funcionar, corrida continua |
| 8 | Passar por um galão sem coletar | Galão que chega à base some e reaparece mais adiante (pool), em nova posição |
| 9 | Conferir coleta × colisão | Encostar em galão: **zero** efeitos de colisão; encostar em NPC: efeitos SPEC-005 intactos |
| 10 | Conferir posicionamento | Nenhum galão nasce sobre NPC; coletar nunca exige colidir com NPC |
| 11 | Reiniciar (pela pausa) ou voltar ao menu (pausa/fim) | Nova corrida limpa (distância 0, tanque derivado cheio, sem galões/marcadores resíduais); no menu, nada roda em segundo plano — nas telas de fim só há "Voltar ao menu" (SPEC-009 FR-020/FR-021), o reinício por derrota é feito a partir do menu |
| 12 | Trocar de veículo e conferir gameplay | Mesma velocidade/aceleração/hitboxes (SC-001/SC-014) |

## 4. Calibração (tarefa explícita — FR-039)

Ajustar no `GameConfig` (bloco SPEC-008), sem tocar na lógica: `track_total_distance`, `fuel_consumption_per_distance`, `fuel_safety_margin` (corrida de referência deve terminar com sobra de ~15%–35%), `fuel_can_*` (frequência percebida planície > deserto > floresta > gelo; piso ≥ 4 e teto ≤ 12 galões por corrida). Revalidar com a suíte + passos 3–8.
