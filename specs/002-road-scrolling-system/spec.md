# Feature Specification: Road Scrolling System

**Feature Branch**: `002-road-scrolling-system`

**Created**: 2026-09-18

**Status**: Draft

**Input**: User description: "SPEC-002 — Sistema de Estrada e Progressão Visual"

## User Scenarios & Testing

### User Story 1 - Road Visual with Scrolling (Priority: P1)

The player sees a continuous road that scrolls vertically based on vehicle speed, creating the sensation of forward movement.

**Why this priority**: This is the core visual feedback for the racing game — without scrolling, the player cannot perceive movement or progression.

**Independent Test**: Can be fully tested by accelerating and observing road movement, delivering the fundamental racing game visual experience.

**Acceptance Scenarios**:

1. **Given** game starts with speed zero, **When** no input is given, **Then** road remains stationary
2. **Given** game is in PLAYING state, **When** player presses accelerate, **Then** road begins scrolling vertically downward
3. **Given** vehicle is at maximum speed, **When** player maintains acceleration, **Then** road scrolls at maximum visual speed
4. **Given** vehicle is accelerating, **When** speed increases, **Then** road scrolling speed increases proportionally

---

### User Story 2 - Road Loop and Segments (Priority: P1)

The road is composed of segments that loop continuously without visible gaps or breaks, maintaining the illusion of an infinite road.

**Why this priority**: Without proper looping, the road would end after one screen height, breaking the gameplay experience entirely.

**Independent Test**: Can be fully tested by driving at constant speed for extended periods, verifying no gaps or breaks appear.

**Acceptance Scenarios**:

1. **Given** road segments are active, **When** a segment exits the visible area, **Then** it is repositioned above the visible area
2. **Given** road segments are looping, **When** viewed during scrolling, **Then** no gaps or breaks are visible between segments
3. **Given** road uses standard segment, **When** composing the road, **Then** segments align seamlessly

---

### User Story 3 - Braking and Inertia (Priority: P2)

When the player brakes or releases the accelerator, the road scrolling decelerates naturally following the vehicle's inertia, stopping only when speed reaches zero.

**Why this priority**: Natural deceleration preserves the sensation of momentum and prevents jarring visual stops.

**Independent Test**: Can be tested by accelerating to high speed then releasing accelerator, verifying smooth deceleration.

**Acceptance Scenarios**:

1. **Given** vehicle is at high speed, **When** player releases accelerator, **Then** road scrolling decelerates gradually
2. **Given** vehicle is decelerating, **When** player presses brake, **Then** road scrolling decelerates faster
3. **Given** vehicle reaches zero speed, **When** deceleration completes, **Then** road stops scrolling completely

---

### User Story 4 - Segment Transitions (Priority: P3)

The system supports rendering road transition segments (expansion and reduction) within the road sequence, maintaining visual continuity.

**Why this priority**: While not needed for initial MVP, road width variations are essential for future track diversity and challenge.

**Independent Test**: Can be tested by inserting transition segments and verifying visual continuity.

**Acceptance Scenarios**:

1. **Given** road sequence contains expansion segment, **When** rendering, **Then** expansion asset is displayed correctly
2. **Given** road sequence contains reduction segment, **When** rendering, **Then** reduction asset is displayed correctly
3. **Given** transition between 2-way and 4-way, **When** segments are in sequence, **Then** visual transition is seamless

---

### Edge Cases

- What happens when vehicle is at speed zero and player presses accelerate? Road starts scrolling proportionally to speed increase
- What happens when vehicle is at maximum speed and player brakes? Road decelerates following vehicle deceleration curve
- What happens when vehicle collides with obstacle? Road continues scrolling based on remaining vehicle speed

## Requirements

### Functional Requirements

- **FR-001**: Road MUST use `estrada_2_vias.png` as default segment
- **FR-002**: Road MUST cover the entire visible area during gameplay
- **FR-003**: Road MUST scroll vertically when vehicle speed > 0
- **FR-004**: Road scrolling speed MUST be proportional to vehicle speed via configurable multiplier
- **FR-005**: Road MUST loop segments continuously without visible gaps
- **FR-006**: Road MUST support expansion segment (`estrada_expansao_4_vias.png`)
- **FR-007**: Road MUST support reduction segment (`estrada_reducao_2_vias.png`)
- **FR-008**: Road scrolling MUST NOT directly affect vehicle physics
- **FR-009**: Road segments MUST obtain real dimensions from assets (not hardcoded)
- **FR-010**: Road MUST maintain pixel-art rendering characteristics (no smoothing, pixel-aligned)
- **FR-011**: scroll_multiplier MUST be configurable in GameConfig
- **FR-012**: segment_spacing MUST be configurable if needed by implementation
- **FR-013**: visible_segment_count MUST be configurable
- **FR-014**: Road MUST use current road boundaries from SPEC-001
- **FR-015**: Lateral movement MUST continue working during scrolling
- **FR-016**: Diagonal movement MUST continue working during scrolling
- **FR-017**: Road boundaries MUST remain consistent during scrolling
- **FR-018**: Road MUST NOT control vehicle velocity
- **FR-019**: VehicleController MUST NOT directly control segment positions
- **FR-020**: Asset changes MUST NOT require changes to main scrolling logic
- **FR-021**: Road MUST use placeholder (gray square) and log error when segment asset fails to load
- **FR-022**: Road segments MUST align by left edge when transitioning between different widths
- **FR-023**: Pool size MUST be calculated as ceil(screen_height / segment_height) + 2 buffer segments
- **FR-024**: Road boundaries MUST update dynamically every frame based on player Y position within each segment
- **FR-025**: Expansion segments MUST use trapezoidal interpolation (linear lerp) for boundary width from narrow (144px) to wide (176px)
- **FR-026**: Reduction segments MUST use trapezoidal interpolation (linear lerp) for boundary width from wide (176px) to narrow (144px)
- **FR-027**: Boundary interpolation MUST account for segment scroll direction (player encounters segment bottom first, then top)
- **FR-028**: Expansion transitions MUST NOT cause vertical speed reduction on the vehicle
- **FR-029**: Reduction transitions MUST gradually narrow boundaries, not abruptly push the vehicle inward

### Key Entities

- **Road**: Manages road segment pool, scrolling, and segment recycling
- **RoadSegment**: Represents individual road segment with position, type (straight, expansion, reduction), and dimensions
- **GameConfig**: Stores configurable scrolling parameters (scroll_multiplier, visible_segment_count)

## Success Criteria

### Measurable Outcomes

- **SC-001**: Player sees road scrolling when accelerating within 0.5 seconds
- **SC-002**: Road scrolling speed is proportional to vehicle speed (correlation > 0.95)
- **SC-003**: Road loops seamlessly with zero visible gaps during 5-minute continuous driving
- **SC-004**: Vehicle maintains lateral movement control during scrolling (no input lag)
- **SC-005**: Road decelerates naturally following vehicle inertia (no abrupt stops)
- **SC-006**: Transition segments render correctly within the road sequence
- **SC-007**: Zero errors in console during 5-minute scrolling test
- **SC-008**: Frame rate remains stable at 60 FPS during scrolling

## Assumptions

- Road assets (`estrada_2_vias.png`, `estrada_expansao_4_vias.png`, `estrada_reducao_2_vias.png`) are available in `assets/estrada/`
- Assets are properly sized for seamless tiling
- Vehicle speed from SPEC-001 is available for scrolling calculation
- Screen resolution remains at 640x480 from SPEC-001
- Current road boundaries from SPEC-001 are sufficient for initial implementation
- No automatic track progression logic is needed in this SPEC
- Dynamic boundary changes ARE implemented for transition segments using trapezoidal interpolation
- Segment type decisions will be made by future TrackManager (not in this SPEC)

## Clarifications

### Session 2026-09-18

- Q: Como o sistema deve armazenar e gerenciar a fila de segmentos da estrada? → A: Pool simples de segmentos reutilizáveis
- Q: Como o sistema deve lidar com falha no carregamento de um asset de segmento? → A: Usar placeholder visual (quadrado cinza) e logar erro, continuar jogo
- Q: Quando um segmento de expansão ou redução é inserido, como o sistema deve lidar com diferenças de largura? → A: Alinhar todos os segmentos pela borda esquerda da estrada
- Q: Quantos segmentos devem ser mantidos no pool para garantir cobertura completa da tela? → A: Calcular automaticamente: ceil(tela_altura / asset_altura) + 2 (buffer)
- Q: Quando a estrada muda de largura, os limites de movimento lateral devem ser atualizados? → A: Atualizar limites imediatamente conforme cada segmento é processado
