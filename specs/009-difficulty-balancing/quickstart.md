# Quickstart: Validação da SPEC-009 — Dificuldade e Balanceamento

**Data**: 2026-10-12 | **Spec**: [spec.md](./spec.md) | **Contratos**: [difficulty_manager_api.md](./contracts/difficulty_manager_api.md), [environment_cycle.md](./contracts/environment_cycle.md), [ui_commands.md](./contracts/ui_commands.md)

Guia de validação ponta a ponta. Código de implementação e suítes completas ficam em `tasks.md`/`tests/unit/` — aqui só o que executar e o que observar.

## 1. Pré-requisitos

- Engine: `Godot_v4.7.2-stable_linux.x86_64` (binário em `~/Downloads/_installers/`).
- Abrir o editor uma vez por máquina (gera `*.import`) ou garantir que já existem.
- Cena principal: `res://src/game/gameplay.tscn`.

## 2. Comandos

```bash
# Jogo (janela)
GODOT_BIN=$HOME/Downloads/_installers/Godot_v4.7.2-stable_linux.x86_64
"$GODOT_BIN" --path .

# Suíte completa (headless — exit 101 quando verde)
GODOT_BIN=$HOME/Downloads/_installers/Godot_v4.7.2-stable_linux.x86_64 \
  bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit
```

## 3. Validação manual (aceite)

### §3.1 Menu e seleção de modo

1. Abrir o jogo → estado `MENU` com **3 linhas**: "Selecionar veículo", "Modo: Normal", "Iniciar corrida"; destaque navegável com `ui_up`/`ui_down`.
2. Na linha "Modo", `ui_accept` cicla **Relaxante → Normal → Desafio → Relaxante**; o rótulo acompanha.
3. Iniciar com **Normal** (padrão): corrida deve parecer **o triplo da velocidade atual** — jogador e NPCs mais rápidos juntos; contagem de largada de 1 s continua normal; partida sem aceleração instantânea.
4. Reiniciar várias vezes (menu → iniciar) e confirmar que a velocidade não "acumula" (a 5ª corrida é igual à 1ª).

### §3.2 Os três modos (velocidade)

5. **Relaxante**: sensação idêntica ao jogo atual (1,0×) — regressão zero.
6. **Normal**: máximo teórico do jogador 375 km/h (3× de 125); NPCs ao triplo das bases (caminhão/utilitário 270, passeio 300, esportivo 360 km/h).
7. **Desafio**: máximo teórico 500 km/h (4×); NPCs ao quádruplo (caminhão/utilitário 360, passeio 400, esportivo 480 km/h); confirmar que **colisões continuam detectadas** (nada de atravessar carros) e que a pausa congela tudo.
8. Em qualquer modo: aceleração/frenagem respondem igual (só a escala muda); direção inalterada; trocar de modo no menu **não** altera corrida em andamento.

### §3.3 Balanceamento por modo

9. **Relaxante**: menos carros na tela (~0,7× da densidade), galões mais frequentes, colisões gastam menos combustível.
10. **Desafio**: mais carros (nunca acima do máximo absoluto de 12), galões mais escassos, colisões gastam mais combustível (penalidade do ambiente × 1,5).
11. Corrida de referência completa (5 km) em **cada modo**: deve ser **concluível** com sobra de combustível razoável — se Desafio se mostrar inconcluível de forma consistente, registrar para calibração (§5).

### §3.4 Progressão infinita (vitória/derrota/ciclos)

12. Vencer na planície → tela **Vitória** com exatamente 2 opções: **"Continuar próxima fase"** e **"Voltar ao menu"** (sem "Tentar novamente").
13. "Continuar próxima fase" → nova corrida no **deserto**, tanque cheio, distância zerada, mesmo modo.
14. Vencer deserto → floresta; floresta → gelo; **gelo → planície** (novo ciclo).
15. Ao completar as 4 vitórias, a planície do novo ciclo deve ter jogador e NPCs **0,2% mais rápidos** (percepção sutil — conferir numericamente via suíte `cycle_*`).
16. **Derrota** (esgotar combustível) em qualquer ambiente → tela **Fim de Jogo** com **apenas "Voltar ao menu"**.
17. Após a derrota, iniciar do menu → corrida começa na **planície** (ciclo zerado), mantendo o bônus de ciclos já concluídos.
18. Os 4 ambientes funcionam nos 3 modos (combinações livres — ex.: Desafio no gelo) sem quebra de decoração/fundo/penalidades ambientais.

### §3.5 Combustível e estados

19. Em 3×/4×: consumir o tanque até parar → desaceleração gradual e `GAME_OVER`; vitória exige cruzar a chegada **com combustível**.
20. Pausar/retomar em qualquer modo/ciclo → multiplicador e velocidades inalterados; voltar ao menu → nenhum sistema avança em segundo plano.

## 4. Validação automatizada

Rodar a suíte completa (comando §2 — **63 suítes, 389 casos, exit 101**). Além das 50 suítes legadas (regressão — devem permanecer verdes sem ajuste), as **13** suítes novas cobrem:

| Suíte | Cobre |
|-------|-------|
| `difficulty_manager_test` | modos, fatores, fallback Normal (SC-001/012) |
| `difficulty_speed_test` | 1×/3×/4× jogador+NPCs, base preservada, sem acúmulo, curva normalizada (SC-001–003) |
| `difficulty_fuel_test` | consumo por km constante, penalidade × fator, aplicação única (SC-007/008) |
| `difficulty_traffic_can_test` | densidade e teto absoluto, ordem de frequência, distância positiva (SC-005/006) |
| `difficulty_environment_matrix_test` | fatores de modo independentes do ambiente, penalidade/taxa com base intacta, modos independentes (SC-011) |
| `difficulty_stability_test` | cenário máximo com ordem canônica completa, ciclos simulados, nascimentos contínuos, NPC×NPC a 3×/4× (SC-013/005/009) |
| `difficulty_state_flow_test` | cadeia de estados nos 3 modos, pausa sem mudanças, reinício reaplica configuração (SC-010) |
| `difficulty_combo_reference_test` | corrida de referência automatizada nas 12 combinações 4×3, injeção por largada, limites absolutos (SC-011) |
| `difficulty_menu_selector_test` | menu de 3 linhas: navegação `wrapi`, rótulo "Modo: Normal", `select_next_mode`/`start_race` por linha (FR-016/017) |
| `difficulty_menu_flow_test` | composição do seletor no orquestrador: sinal → `_on_select_next_mode` cicla o modo, rótulo acompanha, guardas de null (FR-016/US1-AC9) |
| `cycle_progression_test` | sequência % 4, fator 1+0,002×ciclos, derrota zera ciclo (SC-015–017) |
| `cycle_flow_test` | opções das telas, `continue_next_phase`, sync de ambiente (SC-014) |
| `pause_esc_test` | guarda de quadro do ESC: pausa/retomada nunca no mesmo quadro; painel de pausa sempre desenhado (T037) |

## 5. Calibração (após o aceite)

- Fatores provisionais no bloco `## Dificuldade e Progressão (SPEC-009)` do `GameConfig` (research R13) — ajustar sem tocar na lógica.
- Pontos de atenção: sobra de combustível 15%–35% em **cada modo**; sensação de Desafio no gelo (4× + densidade + galões escassos) concluível; bônus de ciclo 0,002 configurável se o rampa estiver lenta/demais a longo prazo.
