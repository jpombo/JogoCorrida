# Contract — PreferencesManager (SPEC-012)

Domínio e validação das preferências do jogador (áudio geral + resolução). `RefCounted`, sem nós. I/O 100% delegado ao `SaveManager` existente com caminho injetável (research R1). `GameplayManager` é o único consumidor direto; a `UIManager` só exibe e emite sinais (contract `settings_menu_commands.md`).

## 1. API pública

```gdscript
class_name PreferencesManager
extends RefCounted

func _init(caminho: String = GameConfig.preferencias_arquivo) -> void
        # cria o SaveManager par (mesmo caminho) — caminho injetável p/ testes

# --- Estado ---
var audio_ativo: bool        # default GameConfig.preferencias_padrao_audio
var resolucao: Vector2i      # default GameConfig.preferencias_resolucao_padrao

# --- Ciclo de vida ---
func carregar() -> void      # lê o arquivo; valida campo a campo; nunca grava; nunca falha
func salvar() -> bool        # grava o esquema v1 completo; false em falha (arquivo anterior intacto)

# --- Mutação (atualiza o campo E persiste) ---
func definir_audio_ativo(valor: bool) -> void
func definir_resolucao(valor: Vector2i) -> void
        # valor fora de GameConfig.preferencias_resolucoes ⇒ ignorado (sem mudança, sem gravação)

# --- Consultas ---
func dados_para_salvar() -> Dictionary   # {"versao": 1, "audio": bool, "resolucao": [w, h]}
func resolucao_valida(valor: Vector2i) -> bool
```

## 2. Regras e invariantes

- **Esquema v1**: `{"versao": 1, "audio": true, "resolucao": [640, 480]}` (data-model §2).
- **Validação campo a campo**: `audio` não-bool ⇒ default; `resolucao` fora do conjunto válido ⇒ default; `versao` ausente/diferente de 1 ⇒ todos os defaults. Campos válidos sobrevivem a campos vizinhos inválidos (recuperação parcial).
- **`carregar()` nunca grava** (inclusive ausente/corrompido) e nunca lança — é o comportamento já garantido pelo `SaveManager.carregar()`.
- **`definir_*`**: valor inválido ⇒ no-op total (nem estado, nem gravação).
- **Arquivo separado** de `user://progresso.json` — preferências nunca são lidas/escritas pelo `ProgressManager` (Clarificação Q1, FR-010).
- **Zero nós, zero `_process`** — aplicação (áudio/resolução) é do orquestrador, não deste componente.

## 3. Pontos de chamada (GameplayManager)

| Momento | Chamada |
|---|---|
| `_ready()` | `preferencias = PreferencesManager.new()` → `carregar()` → aplicar resolução (no-op em headless **e na janela embutida do editor** — `Engine.is_embedded_in_editor()`, aceite T024) → após criar `AudioManager`: `set_geral_ativo(preferencias.audio_ativo)` |
| sinal `settings_audio_alterado(ativo)` | `preferencias.definir_audio_ativo(ativo)` → `audio_manager.set_geral_ativo(ativo)` |
| sinal `settings_resolucao_alterada(res)` | `preferencias.definir_resolucao(res)` → `aplicar_resolucao(res)` |

## 4. SaveManager (par deste contrato — já existente, intocado)

```gdscript
class_name SaveManager
extends RefCounted

func _init(caminho: String = GameConfig.save_arquivo) -> void
func carregar() -> Dictionary    # {} se ausente/inválido; nunca grava
func gravar(dados: Dictionary) -> bool   # tmp + rename; false em falha
```

## 5. Aplicação de resolução (helper no orquestrador)

```gdscript
# GameplayManager (privado)
func _aplicar_resolucao(res: Vector2i) -> void
        # headless (DisplayServer.get_name() == "headless") ⇒ no-op
        # DisplayServer.window_set_size(res) + recentralização
```

Tamanho fixo: `project.godot` declara `window/size/resizable=false` (research R3); a janela só muda por este contrato.
