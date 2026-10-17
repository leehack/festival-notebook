import 'package:llamadart/llamadart.dart';

// Pinned downloads make the example reproducible. Change models here.
ModelSource _source(String repo, String revision, String file) =>
    ModelSource.huggingFace(repoId: repo, revision: revision, filePath: file);

const textParams = ModelParams(
  contextSize: 4096,
  numberOfThreads: 4,
  numberOfThreadsBatch: 4,
);
// Short replies need less speech context and smaller batches.
const speechParams = ModelParams(
  contextSize: 1024,
  batchSize: 64,
  microBatchSize: 64,
  numberOfThreads: 2,
  numberOfThreadsBatch: 2,
);

final dialogueModel = LlamaModel(
  _source(
    'unsloth/Qwen3.5-0.8B-GGUF',
    '6ab461498e2023f6e3c1baea90a8f0fe38ab64d0',
    'Qwen3.5-0.8B-Q4_K_M.gguf',
  ),
);
final embeddingModel = LlamaModel(
  _source(
    'ggml-org/embeddinggemma-300M-GGUF',
    '0f741b5a6585bd53aeb15cd1372c56f2a0f65e12',
    'embeddinggemma-300M-Q8_0.gguf',
  ),
);

const _asrRepo = 'ggml-org/Qwen3-ASR-0.6B-GGUF';
const _asrRevision = '928ab958557df9aa2ef1c93e0e83c7ad0933fae2';
final transcriptionModel = SpeechToTextModel(
  _source(_asrRepo, _asrRevision, 'Qwen3-ASR-0.6B-Q8_0.gguf'),
  projector: _source(_asrRepo, _asrRevision, 'mmproj-Qwen3-ASR-0.6B-Q8_0.gguf'),
  adapter: const Qwen3AsrAdapter(),
);

const _ttsRepo = 'mradermacher/Qwen3-TTS-12Hz-0.6B-Base-GGUF';
const _ttsRevision = '0762b31e9cd99274d49dca4e895bd81863134f08';
final speechModel = TextToSpeechModel(
  _source(_ttsRepo, _ttsRevision, 'Qwen3-TTS-12Hz-0.6B-Base.Q4_K_M.gguf'),
  projector: _source(
    _ttsRepo,
    _ttsRevision,
    'Qwen3-TTS-12Hz-0.6B-Base.mmproj-Q8_0.gguf',
  ),
  adapter: const Qwen3TtsAdapter(),
);

final fastImageModel = ImageGenerationModel(
  _source(
    'concedo/sdxs-512-tinySDdistilled-GGUF',
    '3144d898d61492f8382ffcabec055733fc5b2a0e',
    'sdxs-512-tinySDdistilled_Q8_0.gguf',
  ),
);
final detailedImageModel = ImageGenerationModel(
  _source(
    'Green-Sky/SD-Turbo-GGUF',
    '19a31586d02d64a73b4419bc193b3ecfaf38e1f0',
    'sd_turbo-f16-q8_0.gguf',
  ),
  components: [
    ImageModelComponent.auto(
      _source(
        'madebyollin/taesd',
        '614f76814bbe30edbe2e627ace1c2234c81a2c0e',
        'diffusion_pytorch_model.safetensors',
      ),
    ),
  ],
);
