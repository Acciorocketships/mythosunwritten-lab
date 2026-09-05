# What can answer here today: the arm list, established by trying

Every line below was produced by running the thing, on 2026-09-04, on this
machine. Nothing here is inferred from a version number.

**Terms, once.** *The card* — the single NVIDIA RTX 4090 in this machine,
24,564 MiB of video memory (VRAM). *Arm* — one candidate model in the
side-by-side comparison this roster feeds. *Runtime* — the program that loads
the weights and answers requests (here: `ollama`, or HuggingFace
`transformers`). *Diffusion language model* — a model that writes a whole
block of text at once and then repeatedly refines it, instead of emitting one
token after another; the reason to want one is that the refinement steps run
in parallel. *Quantisation* — storing weights in fewer bits than they were
trained in; *4-bit nf4* is a 4-bit format, and *Q4_K_M* is llama.cpp's
roughly-4-bit format. *GGUF* — the single-file weight format ollama reads.
*trust_remote_code* — the switch that lets `transformers` import Python
shipped inside the model repository, needed when a model's architecture is
not built into the library. *KV cache* — per-token scratch memory a model
keeps while answering; it grows with the context length, which is why every
measurement below pins the context to 4,096 tokens.

## The card, as found and as left

| | MiB used | MiB free | compute processes |
|---|---|---|---|
| at the start, 17:43:09Z | 667 | 23,472 | none |
| at the end, 18:58:33Z | 504 | 23,635 | none |

**The card was not reclaimed at any point during this run.** Every
measurement below ran against a card with more than 23 GiB free.

This is a **borrowed** card, not a won one. Its emptiness is eleven
`bash scripts/*_chain.sh` driver processes of the neighbouring project
`~/proj/self-improving-llm`, suspended with `SIGSTOP` at the user's own
request. All eleven were verified still suspended (kernel state `T`) at the
end of this run — 11 of 11 — and none was resumed, killed, sent `kill -CONT`
or otherwise touched. No file in that project was edited: the untracked files
its tree shows were written at 07:16Z and earlier by its own runs, hours
before this one began at 17:43Z. The hold ends on one `kill -CONT` or a
reboot, and that project's own scheduler could take the card back at any time.

## The roster

One line per candidate: the arm name, the runtime, and either the settings it
runs at or the reason it does not run. The **borrowed?** column is the one to
read before planning around any of this — "no" means this machine can run it
whenever, "yes" means it ran only because the neighbour's queue is paused.

| arm | runtime | verdict | borrowed? |
|---|---|---|---|
| **`gemma3n:e2b`** | ollama 0.17.4, HTTP `/v1/chat/completions` | **runs.** `num_ctx=4096`, `temperature=0`, 31/31 layers on GPU, 6,072 MiB | **no** — fits in ~6.1 GiB |
| **`gemma3n:e4b`** | ollama 0.17.4, same | **runs.** `num_ctx=4096`, `temperature=0`, 36/36 layers on GPU, 7,944 MiB | **no** — fits in ~7.8 GiB |
| **`LLaDA2.1-mini`** | HF `transformers` 5.5.0, `trust_remote_code=True`, bitsandbytes 4-bit nf4 | **runs, but slowly.** `gen_length=64`, `block_length=32`, `threshold=0.5`, `editing_threshold=0`, `temperature=0`; weights 8,955 MiB, process footprint ~16.4 GiB | **yes** |
| `DiffusionGemma` (26B-A4B-it) | — | **does not run.** ollama: `unknown model architecture: 'diffusion-gemma'`. Unchanged by the free card | n/a |
| `dream` (Dream-v0-Instruct-7B) | ollama | **loads, does not answer.** Weights load; sampler aborts, or emits `!!!!!!!!` | n/a |
| `llada` (LLaDA-8B-Instruct) | ollama | **loads, does not answer.** 100% GPU, 5,180 MiB; replies `'\n'` | n/a |
| `llada-moe` (LLaDA-MoE-7B-A1B) | ollama | **loads, does not answer.** 100% GPU, 4,952 MiB; replies `'7\frac'` | n/a |
| `rnd1` | ollama | **not attempted.** Only published GGUF is Q8_0 at 32.48 GB — larger than the 24,564 MiB card | n/a |
| `qwen3:4b-instruct` and the two other small dense models | ollama | already measured; unchanged | **no** |

## The two Gemma sizes: pulled, loaded, measured

Both pulled straight from the ollama library with nothing in the way — no
`trust_remote_code`, no draft loader, no quantisation work. `gemma3n:e2b`
took 58 s to download, `gemma3n:e4b` a few minutes.

Against a card with 23,471 MiB free, **both fit outright — neither is
tight, and neither spilled to the CPU.** Measured one at a time on an
otherwise-idle card:

| | layers on GPU | VRAM taken | `ollama ps` | cold call | warm median, 1,143-token prompt |
|---|---|---|---|---|---|
| `gemma3n:e2b` | 31/31 | 6,072 MiB | `100% GPU` | 11.7 s | **0.787 s** |
| `gemma3n:e4b` | 36/36 | 7,944 MiB | `100% GPU` | 14.2 s | **0.849 s** |

One honest caveat on "100% GPU". Both models keep a constant **420.4 MiB of
weights on the CPU** — this is Gemma 3n's per-layer embeddings, which the
runtime places there by design. ollama still reports `100% GPU` and
`offloaded 31/31` / `36/36 layers`. This is *not* the KV-cache spill the
earlier probes warned about; the KV cache is 64.0 MiB on the GPU for both, at
`num_ctx=4096`. Nothing spilled that was not meant to.

Both answered the shipped run's prompt shape with a well-formed action line
(`go_to target=(7.3, -5.1)` and `go_to target=(5.6, -4.2)`), which is only a
smoke test — behaviour is the comparison's job, not this roster's.

For scale, the previously recorded numbers for `qwen3:4b-instruct` are a
0.252 s median over a 160-tick run and 0.290-0.301 s warm on the run's own
1,069-token prompt. So **the Gemma 3n models are roughly 3x slower per call
than that qwen baseline** — still far under the cloud recording's 3,493 ms
median. Note those qwen figures were taken under a ~6.5 GiB VRAM ceiling and
the Gemma figures on a free card, so the comparison is indicative, not
controlled; producing a controlled one is the comparison's job. The CPU-side
embedding lookup is a plausible cause of the gap but was not isolated here.

Gemma 3n is multimodal; only the text path was used, and no image was put to
any model.

## LLaDA2.1-mini: the window was worth spending, and the answer is "yes, but"

Memory was its only recorded blocker, and the free card removed it. It was
attempted and **it works.**

* **Precision it fits at:** 4-bit `nf4` (bitsandbytes, double-quantised),
  compute dtype bfloat16. A census of its parameters after loading reads
  **14,692 tensors in `uint8`** (the packed 4-bit weights) against 102 left
  in `bfloat16`.
* **Weights on the card: 8,955 MiB** — squarely inside the 9–10 GB that was
  predicted for a 4-bit build, and comfortably inside 24 GiB. The published
  bf16 weights are 32.5 GB and never fit.
* **Runtime it loaded under:** HuggingFace `transformers` 5.5.0 with
  `trust_remote_code=True`. Load took 68.8 s.
* **Does its remote code load under transformers 5.5 despite declaring
  4.57.1?** **Yes.** The config declares `transformers_version: 4.57.1`; the
  tokenizer loaded (`TokenizersBackend`, vocab 157,153) and the config class
  `LLaDA2MoeConfig` imported from the repository's own
  `configuration_llada2_moe.py` without error. **There is no traceback to
  quote — nothing broke across the major version.**

Two things a later reader needs, neither of which is a failure:

**One, the process footprint is much larger than the weights.** While the
weights are 8,955 MiB, PyTorch's caching allocator held 16,302 MiB and the
card's free memory dropped by 16,364 MiB. Peak usage during generation was
17,996 MiB. So *planning* around this model should budget ~18 GiB, not
~9 GiB — on a card that was not empty it would be far tighter than the weight
figure alone suggests. This is the clearest sense in which this arm is
**borrowed**.

**Two, it is slow here — about a hundred times slower than the Gemma arms.**
On the same 1,129-token prompt:

| setting | median | min | max |
|---|---|---|---|
| speed mode (`threshold=0.5`, `editing_threshold=0`) | **77.71 s** | 75.00 s | 84.12 s |
| quality mode (`threshold=0.7`, `editing_threshold=0.5`) | **89.32 s** | 87.54 s | 91.34 s |

On a trivial 26-token prompt the same calls took 5.6–6.0 s, so the cost is
scaling steeply with prompt length. Two reasons, and the roster should not
present this number as the architecture's verdict:

1. bitsandbytes 4-bit over a **256-expert** mixture-of-experts is not a fast
   path — this was flagged as a risk before the attempt and the measurement
   bears it out.
2. **The model card's own recommended fast runtime is SGLang**, with its
   diffusion decoding algorithm, which is where a diffusion model's parallel
   decoding actually pays off. SGLang is **not installed here**
   (`ModuleNotFoundError`); it resolves on PyPI at 0.5.18, as does vLLM at
   0.28.0. Installing it was not attempted — the stop condition for this item
   is that the roster moves on rather than forcing a candidate in.

So the honest line is: **LLaDA2.1-mini loads and answers correctly on this
machine at 4-bit, and the 78 s figure is a `transformers` + bitsandbytes
number that understates the architecture.** For a game asking for 7–18 token
replies it is not competitive as measured, and making it competitive is an
SGLang install, not a memory problem.

Its replies on the game prompt were also not on-form — it answered *"It looks
like your message got cut off or mixed up at the end..."* rather than an
action line — though on a short direct instruction it returned exactly
`examine target=#7`. Behaviour is the comparison's job.

## DiffusionGemma: still a loader-and-format question, and the free card does not touch it

Re-checked as a format question, not a memory one, and **answered by trying
it rather than by reading versions**. The real
`unsloth/diffusiongemma-26B-A4B-it-Q4_K_M.gguf` (16.81 GB) was downloaded and
handed to the installed ollama. Its GGUF header declares
`general.architecture: 'diffusion-gemma'`, `general.size_label: '128x2.6B'`.
`ollama create` accepted the file; the load then failed:

```
llama_model_load: error loading model: error loading model architecture: unknown model architecture: 'diffusion-gemma'
```

That is the direct answer: **no installed or obtainable ollama loads a
checkpoint whose header declares this architecture.** The installed binary
contains no `diffusion-gemma` string at all.

The size-and-kernels statement is unchanged and the free card does not change
it. Of the published checkpoints, BF16 is 51.6 GB and FP8-dynamic 27.2 GB —
both larger than this 24,564 MiB card — and only **NVFP4 at 18.1 GB fits**.
NVFP4 tensor cores exist only on Blackwell (SM100+); this card is **Ada
(SM89)**, confirmed by the runtime log reading
`NVIDIA GeForce RTX 4090, compute capability 8.9`. So the checkpoint that
fits is in a number format this card has no kernels for. **This is said
plainly rather than retried because there is now room.**

Upstream state, re-checked today, **2026-09-04**:

| item | state |
|---|---|
| `ggml-org/llama.cpp#24423` "DiffusionGemma" | **open, draft**, updated 2026-09-04 |
| `ggml-org/llama.cpp#24427` "Add diffusion-gemma block-diffusion support" | **open, draft**, updated 2026-08-24 |
| `ggml-org/llama.cpp#17454` "model : add LLADA 2.0 diffusion support" | **open, draft**, updated 2026-07-22 |
| `ollama/ollama#16664` "Support GGUF models with diffusion-gemma architecture" | **open, unassigned**, updated 2026-07-06 |

**No draft-PR CUDA build was attempted.** The card being free is not on its
own a reason to spend that cycle, and there is no loadable checkpoint at the
end of it: the one that would fit is NVFP4, which this Ada card cannot
execute anyway.

## The four architectures ollama already builds

The installed ollama 0.17.4 contains `llm_build_dream`, `llm_build_llada`,
`llm_build_llada_moe` and `llm_build_rnd1`, and answers to the architecture
names `dream`, `llada`, `llada-moe` and `rnd1`. None of these is in the
ollama library (all four registry manifests return HTTP 404), so each was
fetched as a GGUF from HuggingFace and imported with a `Modelfile`.

| architecture | checkpoint tried | result |
|---|---|---|
| `llada-moe` | `LLaDA-MoE-7B-A1B-Instruct.Q4_K_M.gguf` (4.52 GB) | **loads**, 100% GPU, 4,952 MiB — replies `'7\frac'` |
| `llada` | `LLaDA-8B-Instruct.Q4_K_M.gguf` (4.93 GB) | **loads**, 100% GPU, 5,180 MiB — replies `'\n'` |
| `dream` | `Dream-v0-Instruct-7B-Q4_K_M.gguf` (4.68 GB) | **loads then aborts** — see below |
| `rnd1` | none small enough | only published GGUF is Q8_0 at **32.48 GB** > 24,564 MiB card |

`dream` reads its header correctly (`arch = dream`,
`dream.attention.causal = false`) and allocates, then dies inside the
sampler:

```
ollama: llama-sampling.cpp:660: void llama_sampler_dist_apply(llama_sampler*, llama_token_data_array*): Assertion `found' failed.
SIGABRT: abort
```

Retried on a completely clean card, with the same result. Forced to a greedy
sampler (`temperature=0, top_k=1`) it survives but emits `!!!!!!!!!!!!!!!!`.

**Why all three fail the same way, and it is not the checkpoints.** The
installed ollama binary contains **zero** occurrences of the string
`diffusion`, and none of its shipped runtime libraries exposes a diffusion
decoding entry point. ollama builds these models' *computation graphs* but
has no *diffusion decoding loop*: it runs them through the ordinary
left-to-right next-token sampler. A diffusion language model produces a
masked block that must be iteratively denoised; sampling its raw outputs one
token at a time yields noise, which is exactly what all three returned.

So the finding is sharper than "no small candidate loads": **three of the
four load onto the GPU and none of them answers, for one shared reason that
no choice of checkpoint will fix.** They are not arms.

## What this cost the repository

Nothing above this file. No engine change and no `net/` change — the
`LOCAL_MODEL_ENDPOINT` / `LOCAL_MODEL` seam in `net/model_call.gd` already
exists, and every model above that runs speaks the OpenAI-shaped
`/v1/chat/completions` that seam already calls, or (LLaDA2.1-mini) would need
a server put in front of it.

All weights, the ollama model store and all server state went to a writable
project-local `HOME` and `OLLAMA_MODELS` under the session scratchpad —
about 102 GB across the two Gemma pulls, four imported GGUFs and LLaDA2.1-mini's 31 GB
of shards. **Nothing large landed in the repository or in git.** The
repository is unchanged except for this roster.

---

## What the roster was for

Every arm on this list that runs was then put through the same seeded run end to
end and compared side by side with the cloud model that ships. That comparison,
with the recommendation it leads to, is
[reports/local-bench.md](local-bench.md).
