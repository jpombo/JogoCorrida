# Quickstart: Validação da SPEC-010 — Sistema Básico de Áudio

**Data**: 2026-10-16 | **Spec**: [spec.md](./spec.md) | **Contratos**: [audio_manager_api.md](./contracts/audio_manager_api.md), [audio_integration.md](./contracts/audio_integration.md)

Guia de validação ponta a ponta. Contagem final de suítes/casos na §4; código de implementação em `src/audio/` e `tests/unit/` — aqui só o que executar e o que observar.

## 1. Pré-requisitos

- Engine: `Godot_v4.7.2-stable_linux.x86_64` (binário em `~/Downloads/_installers/`).
- Abrir o editor **uma vez por máquina** (gera os `*.import`) — obrigatório também para `assets/audio/*.mp3`, senão os três streams não carregam (regra do AGENTS.md).
- Cena principal: `res://src/game/gameplay.tscn`.
- **Áudio ligado** nos fones/volume do sistema (a validação §3 é auditiva) e fones disponíveis.

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

### §3.1 Largada e motores (aceites 1, 3, 4, 12 — SC-001, SC-003)

1. Iniciar corrida → ao entrar em `PLAYING` o **motor do jogador NÃO começa sozinho**: sem tocar nada dele, **pressionar `accelerate`** → AUD-003 (`carro.mp3`) começa; **soltar o acelerador** → silência imediato do jogador (Clarification Q3). Repetir 2–3×.
2. Observar NPCs de passeio/esporte/utilitário: **todos tocam o mesmo som de carro** desde a largada, **continuamente** (inclusive com você parado/solto — um só arquivo, AUD-003; os NPCs não têm gate).
3. Encontrar um caminhão: ele toca o **som de caminhão** (AUD-002, `caminhao.mp3`), distinguível do carro. Verificar também com o modo do menu em Desafio (frequência de caminhões maior — SPEC-009).
4. **Freando ainda em movimento** (segurar `brake`, mesmo com `accelerate` pressionado) → som do jogador **silencia** (condição de aceleração idêntica à do controle do veículo); os NPCs continuam. Veículo totalmente **parado** → silêncio do jogador (critério 12 da §6 da spec).
5. Confirmar contínuo **sem interrupção/estalo perceptível** no loop dos motores (FR-007; §4 da spec) — pelo menos 30 s acompanhando a pista (você acelerando ou atrás de um caminhão).

### §3.2 Colisões (aceite 2 — SC-002, US1)

1. Provocar **uma** colisão do jogador com um NPC → exatamente **um** efeito de colisão (AUD-001) no impacto.
2. Repetir e confirmar que física, deriva, perda de velocidade e penalidade de combustível são **idênticas** ao antes da spec (SC-002-caso3 — nada muda no pipeline SPEC-005).
3. Cenário NPC×NPC (Clarification Q1): concentrar vários NPCs (ex.: colidir e deixar o embalo) e confirmar o **mesmo** efeito quando dois NPCs se batem, mesmo longe do jogador.
4. Sequência rápida de colisões: cada evento relevante sinaliza **uma** reprodução — sem "metralhadora" do mesmo efeito para um único encontro (dedup continua sendo dos sistemas SPEC-005/006).

### §3.3 Ciclo de vida dos veículos (aceite 5 — SC-004, US2-AC3)

1. Numa corrida longa, observar NPCs que nascem e são reciclados: o som do veículo **morre junto com ele** (nenhum "eco" continuando sem dono).
2. Fim de corrida + nova corrida imediata (início/fim rápidos consecutivos — edge case do spec): **sem acúmulo** de reproduções (o motor não fica mais alto nem duplicado).

### §3.4 Estados e interfaces (aceites 7, 8, 9 — SC-006, SC-007, US3)

1. `ESC` durante a corrida → **todos os sons suspensos** (inclusive uma colisão em voo, se houver); `ESC`/retomada → **voltam exatamente de onde pararam** — com o acelerador ainda pressionado na retomada, o som do jogador também volta (ciclo pausa→retomada, repetir 3×).
2. Entrar em corrida: durante o `READY` (contagem) **não toca motor** — os NPCs começam na largada (`PLAYING`) e o do jogador só quando você acelerar (§3.1).
3. Vitória (chegar ao fim) → na tela de resultado **0 sons de veículos** ativos.
4. Game Over (combustível zerado) → idem: **0 sons** na tela de fim.
5. Voltar ao `MENU` e navegar as linhas (veículo/modo/iniciar) com `ui_up`/`ui_down`/`ui_accept` → **nenhum som** durante a navegação nem nas interfaces.

### §3.5 Modos de dificuldade (aceite 6 — SC-005, FR-005)

1. No menu, ciclar **Relaxante → Normal → Desafio** e rodar uma corrida em **cada modo**: os sons dos motores funcionam nos 3 (gating por estado — e, no jogador, por aceleração —, nunca por modo).
2. Durante os testes, as velocidades devem ser **exatamente as da SPEC-009** (1,0×/3,0×/4,0×) — o áudio não altera velocidades nem multiplicadores (comprovação executável: suíte `audio_modes_test`, §4).

### §3.6 Arquivo ausente (aceite 10 — SC-008)

1. Com o jogo fechado, renomear `assets/audio/carro.mp3` (ex.: `carro.mp3.bak`).
2. Reabrir → jogo **inicia e roda normalmente**; colisão e caminhão continuam com som; **apenas** o som do jogador/ NPCs-carro fica mudo (sem erro crítico).
3. Restaurar o nome e reabrir → som de volta. Repetir o raciocínio mentalmente para `caminhao.mp3`/`colisao.mp3` (mesmo código de falha segura).

### §3.7 Desempenho (aceite 11 — SC-009, US2-AC4)

1. Jogar no **Desafio** (maior densidade) até a pista cheia (12 veículos ativos + jogador = 13 vozes de motor) **e** provocar colisões em sequência → corrida **sem travamento nem engasgo perceptível** de fluidez.
2. Confirmar visualmente que nada do comportamento pré-existente mudou (colisões, combustível, progressão, UI — zero regressão).

## 4. Validação automatizada

Rodar a suíte completa (comando §2 — **exit 101**, zero failures). Contagem final entregue (T015, 2026-10-16): **68 suítes / 414 casos** — as **63 suítes / 389 casos legados verdes sem ajuste** (SC-009) + as **5 suítes / 25 casos novas** abaixo (lista confere com o entregue — T017):

| Suíte | Cobre |
|-------|-------|
| `audio_manager_test` | `configurar` idempotente, 3 streams carregados, `loop` dos motores, volume aplicado, efeito mudo com arquivo ausente (SC-001/SC-008) |
| `audio_collision_test` | 1 `play()` por evento, gating em PLAYING, pool exausta rouba a voz mais antiga, colisão em voo na pausa/vitória (SC-002/SC-006) |
| `audio_engine_test` | mapeamento caminhão×carro por `category.id`, jogador sempre AUD-003, gate de aceleração do jogador (Q3/I9), 1:1 veículo→voz, spawn duplicado/saída desconhecida no-op, zero som órfão (SC-003/SC-004) |
| `audio_state_flow_test` | matriz de estados: PLAYING liga (NPCs; jogador só via gate), PAUSED pausa (`stream_paused`), VICTORY/GAME_OVER/MENU/READY param, estado desconhecido falha segura, virada no mesmo quadro (SC-006/SC-007) |
| `audio_modes_test` | áudio ativo nos 3 modos sem alterar `fator_velocidade_total()` nem velocidades-base (SC-005) |

Observações da camada de teste: a lógica roda **sem árvore** (estado lógico do componente) e a integração usa `add_child` para assertar `AudioStreamPlayer.playing` real no driver dummy do `--headless` (research R2/R7).

## 5. Calibração (após o aceite)

Ajustes somente no bloco `## Áudio (SPEC-010)` do `GameConfig` (nunca na lógica):

- **Colisões em rajada começam a "secar"** (vozes roubadas em cascata percebidas como corte) → subir `audio_vozes_colisao` (3 → 4/5).
- **Motor abafado sob o efeito de colisão** → subir `audio_volume_motor`; **colisão ofuscante** → baixar `audio_volume_colisao` (lineares 0..1).
- **Loop dos motores com seam perceptível** (clique na virada do loop) → registrar na calibração: os arquivos da §4 da spec devem permitir loop sem interrupção; melhoria de crossfade é **futura** (fora do escopo desta spec).
- **Caminhão e carro difíceis de distinguir** → é asset, não código (AUD-002/003 são arquivos distintos por design); avaliar troca de arquivo com o usuário antes de qualquer código.
- Se **nenhum** ponto acima se manifestar no aceite (§3.1–§3.7), nenhuma calibração é necessária — registrar em `tasks.md` (aceite manual concluído sem ajustes), como nas specs anteriores.
