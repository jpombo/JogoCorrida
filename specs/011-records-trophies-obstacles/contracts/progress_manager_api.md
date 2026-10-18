# Contract — ProgressManager (SPEC-011)

Domínio puro de progressão/pontuação. `RefCounted`, sem nós, sem I/O. Dono único dos recordes, acumulados, troféus, ciclos, histórico e da fórmula de pontuação. O orquestrador (`GameplayManager`) é o único consumidor; a UI consome apenas o **snapshot** (contract da UI).

## 1. API pública

```gdscript
class_name ProgressManager
extends RefCounted

# --- Carga/serialização (domínio; I/O é do SaveManager) ---
func carregar_de(dados: Dictionary) -> void   # aceita {} ou o JSON de data-model §3; idempotente
func dados_para_salvar() -> Dictionary        # esquema v1 completo, com os 3 modos materializados

# --- Eventos de corrida (mutam estado) ---
func processar_vitoria(modo: String, ambiente: String, distancia: float,
        perda_colisao: float, data_hora: String = "") -> Dictionary
        # ordem: marcar ambiente → calcular pontuação → recorde → acumulada → histórico
        # devolve snapshot (§5) com "pontuacao" preenchido

func processar_derrota(modo: String) -> Dictionary
        # zera o ciclo do modo (trofeus preservados); devolve snapshot sem pontuacao

# --- Consultas ---
func snapshot(modo: String, pontuacao: float = -1.0) -> Dictionary
func get_recorde(modo: String) -> float
func get_acumulada(modo: String) -> float
func get_trofeus(modo: String) -> int
func get_ciclo(modo: String) -> Array          # ambientes marcados no ciclo atual
func obstaculos_disponiveis(modo: String) -> bool   # relaxing ⇒ trofeus ≥ 1; demais ⇒ true
func calcular_pontuacao(distancia: float, trofeus: int, perda_colisao: float) -> float
```

## 2. Regras e invariantes

- **Chaves de modo**: somente `"relaxing" | "normal" | "challenge"` (as mesmas de `difficulty_modes`). Na **carga** (`carregar_de`) só as 3 chaves canônicas são materializadas com defaults — chaves desconhecidas do arquivo são **ignoradas** e não entram em `_modos`; em **runtime**, `_modo()` materializa defensivamente qualquer chave ausente com defaults e `dados_para_salvar()` persiste `_modos` como está (após uma carga limpa, só as canônicas).
- **O ambiente vigente NÃO é domínio deste componente**: o `RaceProgression` (SPEC-009) continua fonte única do ambiente da progressão. `processar_vitoria` **recebe** o ambiente como parâmetro — o orquestrador captura `progresso_corrida.ambiente_atual()` **antes** de chamar `registra_vitoria()` (research R7).
- **Recorde**: atualização apenas com pontuação **estritamente maior** no **mesmo** modo (FR-002). Empate ou derrota ⇒ inalterado.
- **Troféu**: `marcar_ambiente` insere no `ciclo` só se ainda não marcado; ao chegar a 4 ambientes distintos: `trofeus += 1`, `ciclo = []` (FR-009). Repetição de ambiente já marcado ⇒ no-op total.
- **Derrota**: apenas `ciclo = []` do modo; `trofeus`, `recorde` e `acumulada` intactos; nenhum resultado no histórico (Q1-A/Q2-B).
- **Pontuação**: fórmula do data-model §2 com clamp ≥ 0; troféus usados são os do modo **após** marcar o ambiente da corrida (FR-006).
- **Histórico**: append por vitória; trim das entradas mais antigas acima de `GameConfig.score_historico_max`.
- **Desbloqueio**: derivado (`obstaculos_disponiveis`), nunca armazenado (FR-019).
- **Idempotência**: o orquestrador garante **uma** chamada de `processar_*` por corrida (latch de encerramento já existente); o componente não tem defesa própria contra dupla chamada além do estado ser determinístico — testes de fluxo cobrem o "não reaplicado" via orquestrador.

## 3. Pontos de chamada (GameplayManager)

| Momento | Chamada |
|---|---|
| `_ready()` | `progress_manager.carregar_de(save_manager.carregar())` |
| ramo vitória (`_avaliar_transicoes`) | captura ambiente → `RaceProgression.registra_vitoria()` → `snapshot = processar_vitoria(...)` → `save.gravar(dados_para_salvar())` → emit/UI |
| ramo derrota | `snapshot = processar_derrota(modo)` → `save.gravar(...)` → emit/UI |
| `_show_menu` / vitória / game over | `ui.atualizar_painel_progresso(snapshot)` |

## 4. SaveManager (par deste contrato)

```gdscript
class_name SaveManager
extends RefCounted

func _init(caminho: String = GameConfig.save_arquivo) -> void
func carregar() -> Dictionary   # {} se ausente/inválido; nunca grava; nunca lança erro
func gravar(dados: Dictionary) -> bool  # tmp + rename; false em falha (arquivo anterior intacto)
```

Zero conhecimento de domínio (só Dictionary/JSON). Caminho injetável para testes (research R2/R12).
