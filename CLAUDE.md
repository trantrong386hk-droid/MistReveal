# MistReveal Project

## Project Overview
- iOS app (SwiftUI) for soul mate analysis using Chinese astrology (BaZi/八字)
- Uses LunarSwift for BaZi calculation, Aliyun Bailian for LLM text generation, Volcano Engine JiMeng for image generation
- Key flow: BaZi calculation → LLM soul analysis → LLM image prompt → image generation

## Architecture (single-step pipeline)
- **TextGenerationService.swift**: Core service. Single LLM call (`fetchSoulAnalysis`) outputs JSON with `image_prompt` field. ChatRequest includes `temperature: 0.95` for diversity.
- **SoulmateManager.swift**: Orchestrator, manages state transitions
- **ImageGenerationService.swift**: Post-processing pipeline: `appendPaletteAndPhoto()` does age calibration + cleanup + redemption lighting + element-differentiated clothing style suffix + photo suffix. Random seed ensures variation. `elementClothingStyle()` maps 五行 to distinct English style keywords.
- **SoulAnalysisModels.swift**: Data models (BaZiInfo, SoulAnalysisResult, SoulmateAppearance)
- **Note**: No `fetchImagePrompt` Step 2 exists. The old `enhancePrompt()` is deprecated/unused.

## Key Files
- `TextGenerationService.swift`: System prompts, BaZi calculation, LLM API calls
- `SoulmateManager.swift`: State machine, flow orchestration
- `ImageGenerationService.swift`: Image generation, visual palettes, shishen persona mappings
- `SoulAnalysisModels.swift`: BaZiInfo, SoulAnalysisResult, SoulmateAppearance

## Environment Notes
- xcodebuild requires `sudo xcode-select -s /Applications/Xcode.app` (can't run without password)
- LunarSwift is an SPM dependency, can't typecheck standalone Swift files
