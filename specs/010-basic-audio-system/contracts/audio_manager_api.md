# Contrato: AudioManager — Reprodução de Áudio (SPEC-010)

**Dono**: `src/audio/audio_manager.gd` (`AudioManager` — novo, `extends Node`)
**Dados**: `Dictionary` de configuração montado pelo orquestrador a partir do bloco `GameConfig.audio_*` (autoload) — o componente **não** lê `GameConfig` diretamente
**Criado por**: `GameplayManager._ready()` (`AudioManager.new()` + `add_child` — filho do orquestrador; em testes, filho do teste)
**Referências**: [data-model.md](../data-model.md) §§2–6, research R1–R6/R8–R9/R11

## 1. Interface pública

```gdscript
## Ciclo de vida
func configurar(cfg: Dictionary) -> void          # idempotente (2ª chamada = no-op)
func esta_configurado() -> bool

## Eventos recebidos (forwards do GameplayManager — ver audio_integration.md)
func tocar_colisao() -> void                      # 1 play() por chamada
func ao_veiculo_surgir(veiculo: TrafficVehicle) -> void
func ao_veiculo_sair(veiculo: TrafficVehicle) -> void
func ao_alterar_estado(novo: int, antigo: int) -> void   # GameState.State
func ao_aceleracao_jogador(acionado: bool) -> void       # gate por quadro do jogador (R11)

## Consultas (testes e depuração — sem efeito colateral)
func voz_jogador_tocando() -> bool
func motor_tocando(veiculo: TrafficVehicle) -> bool
func vozes_motor_ocupadas() -> int
func vozes_motor_totais() -> int
func vozes_colisao_ocupadas() -> int
func efeito_mudo(id: String) -> bool              # "colisao" | "caminhao" | "carro"
```

## 2. Chaves do `cfg` (`configurar`)

| Chave | Tipo | Default do orquestrador | Observação |
|-------|------|--------------------------|------------|
| `colisao_path` | `String` | `GameConfig.audio_colisao_path` | AUD-001 |
| `caminhao_path` | `String` | `GameConfig.audio_caminhao_path` | AUD-002 |
| `carro_path` | `String` | `GameConfig.audio_carro_path` | AUD-003 |
| `vozes_colisao` | `int ≥ 1` | `GameConfig.audio_vozes_colisao` | pool de colisão |
| `vozes_motor` | `int ≥ 1` | `GameConfig.traffic_max_vehicles + 1` | derivado (R5) |
| `volume_motor` | `float` (linear) | `GameConfig.audio_volume_motor` | → `linear_to_db` uma vez |
| `volume_colisao` | `float` (linear) | `GameConfig.audio_volume_colisao` | → `linear_to_db` uma vez |
| `categoria_caminhao` | `String` | `GameConfig.audio_categoria_caminhao` | comparação com `TrafficData.id` |

Chave ausente/inválida ⇒ **default seguro do próprio componente**: path vazio ⇒ efeito mudo; `vozes_* < 1` ⇒ 1; volumes fora de 0..1 ⇒ clamp; `categoria_caminhao` vazia ⇒ nenhum veículo vira caminhão (todos AUD-003). O componente **não** aborta por configuração ruim (Qualidade de Código — falha segura).

## 3. Semântica por método e invariantes

**`configurar(cfg)`**
- Carrega os 3 streams (`ResourceLoader.exists` + `load`); falha ⇒ efeito mudo (`efeito_mudo == true`), sem `push_error` (SC-008).
- Aplica `loop = true` nos streams de motor (R1); volumes via `linear_to_db` (R8).
- Cria as pools de players **uma única vez** como filhos do componente; devolve os motores à lista livre; voz 0 já reservada ao jogador (sem play — o jogador só toca com PLAYING + aceleração, I9).
- Segunda chamada ⇒ no-op (`esta_configurado() == true`).

**`tocar_colisao()`**
- Pré-condições (qualquer uma falha ⇒ no-op silencioso): configurado · estado atual == PLAYING · AUD-001 não-muda · na árvore.
- Pega uma voz livre; se não houver, **rouba a mais antiga** (`iniciada_em` menor) — todo evento produz exatamente 1 `play()` (R5).
- Nunca deduplica além do 1:1 chamada→`play()` — o dedup de evento é upstream (FR-001).

**`ao_veiculo_surgir(veiculo)`**
- Já registrado no dicionário ⇒ **no-op** (I1 — sem som duplicado, FR-008).
- Sem voz livre ⇒ registra **sem voz** (silêncio) — com o default a pool cobre todos os ativos.
- Stream escolhido por `veiculo.category.id == categoria_caminhao` (R6).
- `play()` **somente** se estado == PLAYING **e** na árvore (nascimentos durante READY/registros pré-largada ficam parados até o PLAYING ligar — ordem do wiring, R4).

**`ao_veiculo_sair(veiculo)`**
- Desconhecido ⇒ no-op.
- Conhecido ⇒ `stop()` + devolver voz à pool + remover do dicionário — **em qualquer estado** (SC-004; recycle durante pausa/vitória não deixa eco).

**`ao_alterar_estado(novo, antigo)`**
- `PLAYING` ⇒ `stream_paused = false` em todas as vozes e liga **todos os veículos registrados com voz** (streams não-mudos, na árvore); **a voz do jogador não é ligada aqui** — só pelo gate `ao_aceleracao_jogador` (I9).
- `PAUSED` ⇒ `stream_paused = true` em todas as vozes ativas (motor e colisão em voo).
- `MENU`/`READY`/`VICTORY`/`GAME_OVER` ⇒ `stop()` em todas + `stream_paused = false` (reset — próxima corrida começa limpa).
- Estado **desconhecido** ⇒ mesmo que saída: parar tudo (falha segura).
- O componente **não decide** transições — só reage (§Estado de Jogo).

**`ao_aceleracao_jogador(acionado)`**
- Gate por quadro do jogador (FR-003/Clarification Q3, R11) — chamado pelo orquestrador apenas enquanto o estado é PLAYING.
- Pré-condições (configurado · estado == PLAYING · AUD-003 não-muda · na árvore): qualquer falha ⇒ silenciar a voz 0 (estado lógico atualizado, `play()` real suprimido — padrão R2/I8).
- `acionado == true` e voz 0 não tocando ⇒ `play()`; já tocando ⇒ no-op (nunca reinicia o loop).
- `acionado == false` ⇒ `stop()` na voz 0 — soltar o acelerador, frear ou estar parado ⇒ silêncio, mesmo em movimento.
- `true` fora de PLAYING ⇒ no-op silencioso (o estado só liga via `ao_alterar_estado` + próximo forward).
- NPCs não têm gate (contínuos — FR-002).

**Invariantes** (numerados como no data-model §5):

| # | Invariante | Critério |
|---|------------|----------|
| I1 | ≤ 1 player tocando por veículo registrado | FR-008 |
| I2 | 0 players tocando de veículos fora do gameplay | SC-004 |
| I3 | 1 `play()` de AUD-001 por evento recebido (pool exausta rouba, não descarta) | SC-002 |
| I4 | 0 `play()` de motor fora de PLAYING; 0 reproduções em MENU/interfaces | FR-006, SC-007 |
| I5 | 0 nós novos por quadro; pools de tamanho constante | RF-004, SC-009 |
| I6 | 0 leituras/escritas de velocidade ou fatores de modo | FR-005, SC-005 |
| I7 | Arquivo ausente/inválido ⇒ só aquele efeito mudo, execução sem falha | SC-008 |
| I8 | Estado lógico sempre coerente mesmo fora da árvore (guarda `is_inside_tree`) | R2, SC-009 |
| I9 | Voz do jogador só toca com estado == PLAYING **e** aceleração ativa (entrada em PLAYING não a liga sozinha; silêncio ao soltar/frear/parar) | FR-003, Q3, §6-critério 12, US2-AC5 |

## 4. Fora do contrato

- Qualquer efeito além de AUD-001/002/003 (§7 da spec: trilha, música de menu, aceleração/frenagem/drift, alertas/coleta de combustível, vitória/game over, ambiente).
- Áudio espacial, efeitos 3D, buses customizados, filtro de ambiente.
- Volume por categoria na UI, controle de volume do jogador, persistência de preferências.
- Ajuste dinâmico de volume/pitch por velocidade ou modo (R8 — adição futura isolada se a calibração exigir).
- Qualquer texto de usuário (o componente não gera string — §VI).
