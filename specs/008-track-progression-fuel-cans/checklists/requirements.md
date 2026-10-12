# Specification Quality Checklist: Progressão da Pista, Estados do Jogo, Combustível e Itens Coletáveis

**Purpose**: Validar completude e qualidade da especificação antes de prosseguir para planejamento
**Created**: 2026-10-10
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain
- [x] Requirements are testable and unambiguous
- [x] Success criteria are measurable
- [x] Success criteria are technology-agnostic (no implementation details)
- [x] All acceptance scenarios are defined
- [x] Edge cases are identified
- [x] Scope is clearly bounded
- [x] Dependencies and assumptions identified

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria
- [x] User scenarios cover primary flows
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification

## Notes

- Validação final: **16 de 16 itens aprovados; 0 marcadores `[NEEDS CLARIFICATION]`**. Nenhuma ambiguidade exigiu consulta ao usuário: o texto-fonte é extremamente detalhado e cada lacuna tinha padrão razoável documentado em Assumptions (estado `READY` já existente e mantido com preparação breve; controle de pausa já existente; distância total configurável com valor provisório de 5,0 km calibrado no planejamento; asset `gasolina.png` já presente em `assets/decoracao/gasolina.png`, 32 × 51 px verificados; geração orientada por distância; precedência vitória × esgotamento conforme o texto).
- Estrutura: 8 histórias de usuário priorizadas (P1: US1–US5; P2: US6–US7; P3: US8), 41 requisitos funcionais (FR-001 a FR-041, em 9 grupos temáticos + lista de parâmetros), 17 critérios de sucesso (SC-001 a SC-017), 6 entidades-chave, 18 casos de borda, 18 premissas e 13 itens fora de escopo.
- **Cobertura dos 9 testes obrigatórios do texto-fonte (seção 16)**: cobertos pelas Acceptance Scenarios e mapeados na premissa "Testes obrigatórios" da seção Assumptions (A → US2 AS7–AS10; B → US2 AS1–AS6; C → US2 AS9 + US3 AS1–AS4; D → US4 AS1–AS4 + US5 AS2; E → US6 AS1–AS8; F → US7 AS1–AS7; G → US4 AS5–AS7 + US6 AS3–AS6; H → US1 AS4–AS8 + US7 AS7 + US6 AS8; I → US1 AS3 + FR-040/SC-013/SC-014).
- **Cobertura dos 24 critérios de aceitação do texto-fonte (seção 15)**: todos mapeados a FRs e SCs na premissa homônima da seção Assumptions.
- **Entrega escalonada da emenda constitucional v3.0.0**: cumprida — SPEC-007 emite `fuel_depleted`; a transição para `GAME_OVER` fica com esta spec (FR-015/FR-016), conforme registrado no plan.md da SPEC-007 (Complexity Tracking).
- **Conformidade com a constituição**: §Estado de Jogo (seis estados + transições centralizadas — FR-001), §Sistema de Combustível (sinal único de esgotamento + transição pelo sistema de estados — FR-015/FR-016), §Pista (corrida finita INICIAR → DIRIGIR → DESVIAR → GERENCIAR COMBUSTÍVEL → CHEGAR — US1–US6), §Dificuldade (distribuição por ambiente configurável — FR-029), §Configuração (sem valores mágicos — FR-039/SC-016), §Câmera e Apresentação / Independência de Assets (pixel art sem suavização, hitboxes inalteradas — FR-021/FR-040/SC-014), §VI (textos externalizados — FR-041).
- Os nomes `GameManager`, `TrackManager`, `FuelSystem`, `UIManager` e os parâmetros (`track_*`, `fuel_can_*`) vêm da constituição e do texto-fonte e são declarados como "nomes de referência, adaptáveis à convenção do projeto" — mesma convenção das SPEC-005 a SPEC-007; denotam responsabilidades (o quê), não implementação (como).
- Fora de escopo registrado com base nas listas explícitas do texto-fonte (seções 3, 13 e 17) e nas proibições da constituição §V, incluindo alteração de hitboxes, novos controles, reabastecimento fora dos galões e sistemas de progressão/pontuação entre corridas.
