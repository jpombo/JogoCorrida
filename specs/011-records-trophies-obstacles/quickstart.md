# Quickstart — Recordes, Persistência, Troféus, Pontuação e Obstáculos (SPEC-011)

Guia de aceite manual da feature e da calibração de balanceamento (research R13). Pré-requisitos e execução seguem o padrão das specs anteriores.

## 1. Pré-requisitos

- Engine: `Godot_v4.7.2-stable_linux.x86_64` (binário em `~/Downloads/_installers/`);
- Abrir o editor **uma vez** na máquina para gerar os `*.import` dos assets (regra do AGENTS.md) — inclusive de `assets/trofeus/` e `assets/obstaculos/` se ainda não importados;
- Cena principal: `res://src/game/gameplay.tscn`; rodar o jogo pelo editor ou `--headless` para a suíte.

## 2. Suíte automatizada (obrigatória antes do manual)

```bash
GODOT_BIN=<caminho do godot> bash addons/gdUnit4/runtest.sh --headless --ignoreHeadlessMode -c -a res://tests/unit
```

Saída esperada: **exit 101** com 100% verde (suíte legada intacta + suítes novas `progress_*`, `score_*`, `save_*`, `obstacle_*`). A sonda de 100 encontros em Desafio (SC-009) roda aqui — nenhum atravessamento.

## 3. Aceite manual

### 3.1 Primeira execução (defaults)

1. Apagar `user://progresso.json` (ou o arquivo configurado em `save_arquivo`) e iniciar o jogo;
2. Menu: recorde 0, acumulada 0, `0 troféus — Próximo: 0/4 ambientes`, obstáculos **bloqueados** apenas se o modo for Relaxante — sem erros de console.

### 3.2 Vitória, pontuação e recorde (US1)

3. Iniciar corrida no **Normal**, concluir sem colisões; conferir na tela de vitória: `Pontuação: 500` (5,0 km × 100 + 0 troféus × 500 − 0), recorde igual à pontuação, acumulada igual;
4. Vencer de novo com pontuação menor ou igual (mesma corrida sem troféus): recorde **inalterado**;
5. Voltar ao menu: recorde/acumulada exibidos iguais aos da vitória;
6. Repetir um passo de vitória no **Relaxante** e no **Desafio**: cada modo com seu próprio recorde/acumulada — nenhum cruzamento (SC-001/SC-005).

### 3.3 Colisão e penalidade (US1)

7. No Normal, vencer com 2 colisões que custem combustível: pontuação = 500 − (perda real × 10); consumo normal sem colisão não desconta nada; a perda aparece contada uma vez só;
8. Em **planície/deserto** (penalidade de colisão 0), colidir: perda 0, penalidade 0 (edge case).

### 3.4 Derrota (US1/US2)

9. Perder uma corrida (combustível zerado sem concluir): tela de Fim de Jogo **sem** pontuação de corrida; nenhum resultado novo; recorde/acumulada inalterados; ciclo de troféus do modo **zerado** (se estava parcial), total de troféus preservado.

### 3.5 Troféus (US2)

10. No Normal, vencer os 4 ambientes em sequência (planície → deserto → floresta → gelo, conforme a progressão da SPEC-009): após a 4ª vitória, `1 troféus — Próximo: 0/4 ambientes`, ícone `trofeu-normal.png` de 32 px;
11. Vencer de novo um ambiente já marcado num ciclo parcial: progresso inalterado (ambiente conta 1× por ciclo);
12. Trocar de modo no menu: ícone/contador/progresso passam a ser os do novo modo, sem mistura.

### 3.6 Obstáculos (US3/US4)

13. No **Normal/Desafio** (1ª corrida): poça e cascalho aparecem nos 4 ambientes, dentro da pista, sem sobrepor NPCs/obstáculos e sem fechar a passagem; atingir uma **poça**: o carro é desviado de meio carro para o lado do impacto, a poça permanece na pista inerte até sair da tela e não repete o desvio; atingir **cascalho** nos 3 modos: velocidade cai perceptível, término automático dentro da duração configurada (±10%); em ambos: combustível intocado, nada congelado/errado na pausa;
14. No **Relaxante** sem troféus: **zero** obstáculos; conquistar o 1º troféu no Relaxante: os dois desbloqueiam e passam a aparecer;
15. Colidir com o mesmo obstáculo duas vezes seguidas: renova o efeito, não empilha intensidade nem dobra a duração;
16. Velocidade máxima do Desafio: os efeitos ativam em todos os encontros (sonda automatizada cobre os 100; o manual confirma a percepção).

### 3.7 Persistência (US1/US4)

17. Após as conquistas acima, fechar e reabrir o jogo: recordes, acumuladas, troféus, ciclos e desbloqueio do Relaxante restaurados exatamente; menu já abre com os valores;
18. Corromper o arquivo (colar lixo no JSON) e reabrir: defaults em memória, zero travamento, arquivo não sobrescrito até o próximo encerramento;
19. Reiniciar/voltar ao menu logo após uma vitória: o resultado anterior não é reaplicado nem duplicado no histórico.

## 4. Critérios de saída

Todos os passos §3 sem problemas + suíte exit 101 + console limpo. Achados viram tarefas de correção ou itens de calibração §5.

## 5. Calibração (gatilhos)

Ajustar **apenas** `game_config.gd` (research R13); nenhum ajuste de código esperado.

| Se o aceite observar... | Ajustar |
|---|---|
| Pontuação "grande demais"/pequena demais vs recorde percebido | `score_peso_distancia`, `score_peso_trofeu` |
| Penalidade de colisão irrelevante ou punitiva demais | `score_peso_penalidade` |
| Desvio da poça "fraco"/"forte" (quer-se meio carro) ou poça repete o desvio | `poca_desvio_lateral` |
| Cascalho "imperceptível" ou "arruína a corrida" | `cascalho_velocidade_fator`, `cascalho_duracao` |
| Estabilidade do cascalho desejada (hoje desligada, fator 1,0) | `cascalho_aderencia_fator` (ex.: 0,85) |
| Muito/pouco obstáculo por corrida | `obstaculo_intervalo_km`, pesos poca/cascalho |
| Ativação faltando em fps baixos (só fora da meta de 60) | hitbox dos obstáculos (`obstaculo_tamanho_*`) |
| Layout dos novos labels apertado em alguma resolução suportada | posições Y do bloco (contrato da UI §2) |
