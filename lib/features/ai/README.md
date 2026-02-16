# AI Feature Module

This feature follows clean architecture boundaries:

- `domain/`
  - `contracts/`: pure abstractions (`AIService`, `EmbeddingService`, `MemoryService`, `AIOrchestrator`)
  - `models/`: immutable request/response entities and policy/limit value objects
- `application/`
  - orchestration/use-cases and policy enforcement (next steps)
- `infrastructure/`
  - OpenAI/local-model adapters and persistence implementations (next steps)
- `presentation/`
  - controllers/widgets/pages for prompts, reflection, and chat (next steps)
