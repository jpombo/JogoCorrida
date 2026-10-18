# Quickstart — Menu de Configurações Aprimorado e Menu Principal Dinâmico (SPEC-012)

Guia de validação ponta a ponta da feature (aceite manual dos Testes A–I da spec §6 + calibração dos parâmetros da demo). Pré-requisitos e execução seguem o padrão das specs anteriores.

## 1. Pré-requisitos

- Engine: `Godot_v4.7.2-stable_linux.x86_64` (binário em `~/Downloads/_installers/`);
- Abrir o editor **uma vez** na máquina para gerar os `*.import` dos assets (regra do AGENTS.md);
- Cena principal: `res://src/game/gameplay.tscn`; rodar o jogo pelo editor ou a suíte em `--headless`;
- Para o Teste C (persistência), poder apagar arquivos em `user://` (`~/.local/share/godot/app_userdata/JogoCorrida/` no Linux).

## 2. Suíte automatizada (obrigatória antes do manual)

```bash
GODOT_BIN=<caminho do godot> bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit
```

Saída esperada: **exit 101** com 100% verde — suíte legada intacta (74 suítes / 478 casos) + suítes novas `preferences_manager_test`, `menu_demo_test`, `settings_menu_test`, `audio_settings_test` (Clarificação Q3: ciclo de ambientes, validação/recuperação de preferências, limite/reciclagem de NPCs e mute central cobertos aqui).

## 3. Aceite manual — Parte A (configurações)

### 3.1 Controle geral de áudio (Teste A — RF-001)

1. Apagar `user://preferencias.json` e iniciar o jogo → menu principal com a demo animada; abrir **Configurações**;
2. Alternar `Áudio` para **Desativado**: navegar pelo menu, iniciar uma corrida → **nenhum** som (motor, colisão, caminhão) audível; interface 100% funcional;
3. Voltar ao menu → configurações → reativar `Áudio` → iniciar corrida → sons voltam (motor do jogador ao acelerar, motores de NPCs, colisão) sem reiniciar o jogo;
4. Alternar áudio repetidamente em sequência rápida: estado final coerente, nenhum som "preso".

### 3.2 Resolução (Teste B — RF-002)

5. Em 640 × 480 (padrão): conferir menu, configurações e uma corrida;
6. Trocar para 1024 × 768: janela muda **imediatamente**, centralizada, **não redimensionável** pelas bordas; menu/demo/corrida sem distorção, cortes ou botões inacessíveis;
   > **Nota (aceite T024, 2026-10-18)**: na janela embutida do editor (Game View → "Embed Game on Next Play") o motor **não permite** redimensionar a janela (`Embedded window can't be resized`); `_aplicar_resolucao` detecta via `Engine.is_embedded_in_editor()` e vira no-op silencioso — a preferência é persistida normalmente e passa a valer em janela standalone/exportada. Para validar a troca real de tamanho, desmarque a opção de embutir no Game View antes de jogar.
7. Repetir o menu e uma corrida em 640 × 480; título/opções legíveis nas duas (SC-008);
8. Trocar resolução e conferir que nada de gameplay foi reiniciado/alterado (FR-005).

### 3.3 Persistência (Teste C — RF-003)

9. Definir `Áudio: Desativado` + `Resolução: 1024 × 768`; fechar o jogo; relançar → preferências restauradas (`user://preferencias.json` contém `versao/audio/resolucao`; SC-002);
10. Apagar `user://preferencias.json` → jogo inicia com padrões (áudio Ligado, 640 × 480) sem erro (SC-003);
11. Corromper o arquivo (conteúdo `{"versao": 1, "audio": "sim", "resolucao": [800, 600]}`) → inicia com defaults, sem erro; alterar qualquer opção ⇒ arquivo regrava válido.

## 4. Aceite manual — Parte B (demonstração)

### 4.1 Ciclo de ambientes (Teste D — RF-005)

12. Abrir o menu → demo inicia sozinha em **Planície**; aguardar ~10 s ⇒ **Deserto** ⇒ **Floresta** ⇒ **Gelo** ⇒ **Planície** (SC-004, ciclo ≤ 60 s);
13. Estrada de 2 vias rolando com 2–4 NPCs de cima para baixo, sem jogador (RF-004/RF-007); título/opções legíveis em todos os ambientes (RF-010).

### 4.2 Transições (Teste E — RF-006)

14. Observar cada transição: escurecimento (~0,75 s) → troca → clareamento (~0,75 s); sem corte brusco, sem dois ambientes ao mesmo tempo, UI responsiva durante o efeito;
15. Iniciar uma corrida **durante uma transição** → demo encerra na hora, tela nunca fica escura, corrida inicia normalmente (SC-005).

### 4.3 Trânsito e recursos (Testes F/I — RF-007/RF-011)

16. Contar NPCs por amostragem durante 5 min: sempre 2–4 (SC-006); NPCs permanecem dentro da pista e somem pela borda inferior (reciclados);
17. Alternar menu ⇄ corrida 20 vezes: contagem de objetos da demo sempre volta ao inicial, sem acúmulo (SC-007), sem erros recorrentes de console (SC-010).

### 4.4 Isolamento e ciclo de vida (Testes G/H — RF-008/RF-009)

18. Deixar a demo por vários ciclos; iniciar corrida → combustível inicial, pontuação, troféus e recordes **intactos** (SC-009); velocidade dos NPCs da demo idêntica em Relaxante/Normal/Desafio (FR-017);
19. Menu → Configurações → voltar: demo **retoma** no mesmo ambiente (pausada, não reiniciada); menu → corrida → menu: demo **reinicia** em Planície, sem NPCs acumulados nem fade pendente;
20. Trocar resolução com a demo em transição: demo/transição continuam corretas na nova resolução.

## 5. Calibração (somente se o §4 acima apontar problema)

| Parâmetro (`GameConfig`) | Padrão | Gatilho para ajuste |
|---|---|---|
| `demo_duracao_ambiente` | `10.0` s | muito rápida/lenta a troca (faixa da spec: 8–12 s) |
| `demo_fade_escurecer` / `demo_fade_clarear` | `0.75` / `0.75` s | fade perceptivelmente brusco ou lento (faixa: 0,5–1 s) |
| `demo_velocidade` | `300.0` px/s | menu "devagar demais"/"rápido demais" (referência: cruzeiro do Normal = 100 × 3,0) |
| `demo_npc_intervalo` | `0.8` s | contagem fora de 2–4 visíveis (SC-006) |
| `demo_ui_scrim_alpha` | `0.3` | título/opções difíceis de ler em Floresta/Gelo ou véu pesado demais |

Registrar em `tasks.md` (Phase de aceite) qualquer valor ajustado, como nas specs anteriores.
