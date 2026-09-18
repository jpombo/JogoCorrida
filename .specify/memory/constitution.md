<!--
Sync Impact Report:
- Version change: 1.0.0 → 1.1.0 (concrete values added for language and documentation policy)
- Modified principles: template placeholders replaced with concrete principles
- Added sections: Core Gameplay, Player Vehicle, Vehicle Physics, Collision Behavior, Fuel System, Track, Traffic, Difficulty, Camera/Presentation, Architecture, Game State, Configuration, Development Strategy, AI-Assisted Development Rules, Change Discipline, Testing, Code Quality, Performance, Asset Independence, Git Discipline, Definition of Done, Design Principle, Priority Rule, Scope Protection, Constitution Authority
- Added items: Language support (US English + Brazilian Portuguese); Documentation language policy (PT-BR mandatory)
- Removed sections: none
- Follow-up TODOs: none
-->

# JogoCorrida Constitution

## Core Principles

### I. Simple Controls, Deep Gameplay
The player should understand the game immediately through four primary controls: Accelerate, Brake, Move Left, and Move Right. The challenge must come from traffic, speed, collisions, drift, fuel, and distance — not from complicated controls or unnecessary game systems. Any new mechanic must reinforce this principle. This is the primary guiding principle of the project.

### II. Player Experience Priority
When two implementation decisions conflict, the priority order is: (1) Player experience, (2) Core gameplay, (3) Simplicity, (4) Maintainability, (5) Testability, (6) Performance, (7) Visual polish, (8) Technical sophistication. Technical sophistication must never be prioritized over a simple and reliable gameplay implementation. This principle governs all architectural and feature decisions.

### III. Modular Architecture
The project MUST use a modular architecture with separated responsibilities: GameManager, PlayerVehicle, VehicleController, FuelSystem, CollisionSystem, TrafficManager, TrafficVehicle, Road, TrackManager, UIManager, AudioManager. Responsibilities must not be unnecessarily duplicated. Avoid monolithic scripts — a script should have one primary responsibility. Systems MUST communicate through well-defined interfaces, signals/events, or equivalent engine mechanisms. Direct dependencies between unrelated systems must be minimized.

### IV. Configuration-Driven Design
Gameplay parameters MUST NOT be hard-coded throughout the source code. Whenever practical, parameters should be centralized or exposed through engine-supported configuration mechanisms. Examples include player_max_speed, player_acceleration, player_brake_force, player_lateral_speed, fuel_capacity, fuel_consumption_rate, collision_fuel_penalty, traffic_spawn_rate, traffic_min_speed, traffic_max_speed, collision_speed_loss, drift_duration, drift_strength. This allows gameplay balancing without modifying core logic.

### V. Constitution Authority and Scope Protection
This document is the primary design and architectural constraint for AI-assisted development. AI agents must verify consistency with this constitution before implementing any feature. The following features are OUT OF SCOPE unless explicitly approved: weapons, combat, multiplayer, online services, character progression, RPG mechanics, complex vehicle customization, realistic vehicle simulation, open-world exploration, complex economy, procedurally generated worlds, artificial intelligence requiring machine learning, additional player controls. Future features may be added through explicit project decisions but must not be assumed by the AI agent.

### VI. Multilingual Support and Documentation Language
The game MUST support the following languages: **US English (en-US)** and **Brazilian Portuguese (pt-BR)**. All user-facing text, audio, and localization assets MUST be implemented for both languages. For development, ALL written documentation, comments, commit messages, and project communications MUST be maintained in Brazilian Portuguese (pt-BR). This applies to all project artifacts including constitution documents, specs, plans, tasks, and any written deliverables. This ensures consistent communication across the team and aligns with the project's cultural and linguistic identity.

## Core Gameplay Rules

The game is a 2D top-down arcade racing game with pixel-art aesthetics. The player controls a vehicle traveling continuously along a road and must reach the end of each track before running out of fuel. The game is focused on: driving control, avoiding traffic, collision consequences, fuel management, track progression, and increasing difficulty.

### Player Vehicle
The player vehicle MUST: move left and right within road boundaries; accelerate; brake; have a configurable maximum speed; have configurable acceleration and braking parameters; consume fuel while moving; react to collisions with other vehicles. The vehicle MUST NEVER leave the valid road area. Road boundaries must be represented by an explicit collision or boundary system rather than relying only on visual positioning.

### Vehicle Physics
The game is an arcade racing game and MUST NOT attempt to simulate realistic vehicle physics. Physics MUST prioritize: responsiveness, predictability, simplicity, fun, and consistent behavior. The vehicle should have a configurable sense of inertia. Acceleration and braking should influence the vehicle's forward speed. Lateral movement should feel responsive but should not behave like a realistic racing simulator.

### Collision Behavior
Collision with another vehicle MUST NOT immediately result in Game Over. A collision MUST produce a noticeable gameplay consequence. At minimum, a collision MUST: reduce vehicle speed; produce a temporary drifting/skidding effect; consume additional fuel; provide visual feedback; provide audio feedback when audio is implemented. The drifting effect MUST be configurable and isolated from the main vehicle-control logic. The collision system MUST support future balancing without requiring architectural changes. Example configurable parameters: collision_speed_loss, collision_fuel_loss, drift_duration, drift_strength, drift_recovery, collision_cooldown.

### Fuel System
Fuel is a fundamental gameplay resource. The player MUST complete the track before fuel reaches zero. Fuel consumption MUST be configurable. At minimum: fuel_capacity, fuel_consumption_rate, collision_fuel_penalty. Fuel consumption SHOULD be influenced by vehicle movement. The system MUST prevent fuel values from becoming negative. When fuel reaches zero, the vehicle can no longer continue normal progression and the game enters the appropriate failure state. The fuel system MUST be independent from the user interface. The UI SHOULD observe the fuel system rather than directly modifying its internal state.

### Track
The track is finite in normal gameplay. Each track has: Start, End, Road boundaries, Lane structure, Traffic, Distance/progression. The primary objective is: START → DRIVE → AVOID TRAFFIC → MANAGE FUEL → REACH FINISH. Victory occurs when the player reaches the end of the track with sufficient fuel. Failure occurs when the player is unable to continue because of fuel depletion or another explicitly defined failure condition.

### Traffic
Traffic consists initially of: passenger cars and trucks. Traffic vehicles MUST: spawn according to configurable rules; move relative to the player's progression; remain inside the valid road area; have configurable speed; have configurable dimensions; have collision detection. Traffic generation MUST be separated from individual vehicle behavior. A Traffic Manager/Spawner SHOULD control creation and removal of traffic. Individual vehicles should not be responsible for managing the entire traffic system.

### Difficulty
Difficulty MUST be data/configuration driven whenever practical. Difficulty MAY increase through: number of traffic vehicles, traffic density, vehicle speed, truck frequency, road width, track length, fuel availability, collision consequences. Difficulty MUST NOT be increased by introducing unnecessary control complexity. The four primary player controls MUST remain unchanged.

### Camera and Presentation
The game uses a top-down 2D perspective. The player vehicle remains approximately centered in the gameplay area while the world/road moves relative to the player. The visual style is pixel art. The implementation MUST preserve pixel-art characteristics: pixel-aligned rendering where appropriate, consistent sprite resolution, no unnecessary smoothing, consistent pixel scale, consistent visual proportions. Artistic assets should not dictate gameplay architecture. Gameplay systems MUST remain independent from specific sprite assets.

### Game State
The game MUST explicitly represent its major states. At minimum: MENU, READY, PLAYING, PAUSED, VICTORY, GAME_OVER. Game state transitions MUST be controlled by a central game-state mechanism. Individual gameplay objects MUST NOT independently decide global game state.

## Development Strategy and Quality Standards

### Development Strategy
Development MUST follow an incremental vertical-slice approach. Do NOT implement the complete game before validating the core gameplay. Recommended development order: Phase 1 — Core Movement (Road, Player vehicle, Left/right movement, Acceleration, Braking, Road boundaries, Basic camera/world movement); Phase 2 — Traffic (Traffic spawning, Cars, Trucks, Traffic movement, Collision detection); Phase 3 — Collision Consequences (Speed reduction, Drifting, Fuel penalty, Visual feedback); Phase 4 — Fuel (Fuel capacity, Fuel consumption, Fuel HUD, Fuel depletion, Game Over); Phase 5 — Track Completion (Track distance, Progression, Finish line, Victory state); Phase 6 — Difficulty (Traffic density, Different vehicle speeds, Trucks, Track variations, Progressive difficulty); Phase 7 — Presentation (Pixel-art assets, Animations, Sound effects, Music, UI polish, Effects).

### AI-Assisted Development Rules
AI agents are development assistants and MUST NOT redefine the game design autonomously. Before implementing a feature, the agent MUST verify that it is consistent with this constitution. If a requested implementation conflicts with the constitution, the agent MUST identify the conflict before modifying the architecture. The agent MUST prefer: existing project conventions, existing reusable components, simple solutions, modular solutions, minimal changes. The agent MUST avoid unnecessary abstraction. Do NOT create frameworks, systems, or design patterns merely because they are technically possible.

### Change Discipline
Each development task MUST have a clearly defined scope. The agent MUST avoid modifying unrelated systems. When implementing a feature: Understand → Inspect existing code → Identify affected systems → Implement minimum required change → Run tests → Validate gameplay → Review changes. Do NOT rewrite working systems without a specific reason. Do NOT introduce breaking architectural changes during small feature tasks.

### Testing
Every gameplay system SHOULD be testable independently whenever practical. At minimum, automated tests SHOULD cover critical deterministic logic such as: fuel consumption, fuel depletion, collision fuel penalty, speed reduction, track progression, victory condition, game-over condition, road boundary constraints. Tests MUST be executed after significant gameplay-system changes.

### Code Quality
Code MUST prioritize readability over cleverness. Use descriptive names. Avoid: magic numbers, global mutable state, duplicate logic, large monolithic functions, unnecessary inheritance, unnecessary dependencies, dead code, temporary debugging code in production systems. Comments SHOULD explain WHY something exists when the reason is not obvious. Do NOT write comments that merely repeat what the code already says.

### Performance
The game is a 2D arcade game. Performance optimization MUST remain proportional to actual needs. Do NOT prematurely optimize. However: avoid unnecessary object creation every frame; reuse objects where practical; remove traffic vehicles that are no longer relevant; avoid expensive processing in _process/per-frame loops when event-driven logic is sufficient; keep collision detection limited to relevant gameplay objects. Performance decisions MUST NOT unnecessarily complicate the architecture.

### Asset Independence
Gameplay logic MUST NOT depend directly on specific artwork. The player vehicle has separate concerns for gameplay, collision, physics, and visual representation. Changing the player sprite MUST NOT require rewriting vehicle physics. The same principle applies to traffic vehicles, road graphics, UI, and effects.

### Definition of Done
A feature is considered complete ONLY when: the implementation works; existing functionality still works; relevant automated tests pass; no obvious errors are present in the runtime; the implementation follows this constitution; no unnecessary architectural complexity was introduced; the Git diff contains only changes related to the task.

## Git and Commit Discipline

Each meaningful change SHOULD produce a focused Git commit. Commits SHOULD represent a coherent change. Examples: feat: add player vehicle movement; feat: add road boundary collision; feat: add traffic spawning; feat: add vehicle collision response; feat: add fuel consumption; feat: add track completion; fix: prevent player from leaving road; test: add fuel system tests. Avoid mixing unrelated changes in the same commit. Do NOT commit generated build artifacts, temporary files, IDE-specific files, or secrets.

## Governance

This constitution is the primary design and architectural constraint for AI-assisted development in this project. When implementing a feature, the AI agent MUST consider this constitution before making architectural or gameplay decisions. The AI agent MUST NOT silently change the constitution to accommodate an implementation. If a requirement cannot be satisfied without violating the constitution, the conflict MUST be reported before implementation. The constitution MAY evolve, but changes MUST be intentional, documented, and version controlled.

All PRs/reviews MUST verify compliance with this constitution. Complexity MUST be justified. Use this document as the primary reference for runtime development guidance.

**Version**: 1.1.0 | **Ratified**: 2026-09-18 | **Last Amended**: 2026-09-18
