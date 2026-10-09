# SNARK.fast x86: next optimization experiment (2026-10-09)

Status: source-backed experiment design, NOT a verified performance gain. Yukon submission remains disabled.

## Ground truth
Official ranked environment: Intel Sapphire Rapids c7i.4xlarge, 16 vCPU / 32 GiB, Ubuntu 24.04, Rust 1.97, target-cpu=native, 20 warmups and 100 measured trusted proofs. Scoring includes witness generation, proof construction, serialization and proof publication; compilation and trusted verification are not timed. Source: https://github.com/Layr-Labs/flock-challenge-multi/blob/main/docs/BLAKE3_X86_BENCHMARK.md

Latest source history reviewed: https://github.com/Layr-Labs/flock-challenge-multi/commit/1b55c6ee2c
The promoted code already has: ordered parallel PoW cursor scanning, tree hugepage-collapse park bookkeeping, dead-output transpose NTT skipping, multiple inverse-NTT sigma-image variants, and canonical-window zerocheck elimination. Do not claim these existing optimizations as new candidates.

## Priority 1: test DirectFold8 state-construction critical path
The repository's snark-x86-note.md documents direct_fold8_states_par, which has two existing routes:
* reuse Fold8 storage for W; A must read the input before W overwrites it (serial dependency)
* allocate independent W and run A/W state builders in parallel using rayon::join

Hypothesis: on the official 16-vCPU machine, independent state construction can shorten the critical path enough to offset additional allocation and memory bandwidth. This is a testable hypothesis, NOT a known gain. First verify that the currently promoted source still contains both paths and determine the exact predicate; avoid matching outdated code.

Do not introduce a novel patch until source diff and correctness baseline are confirmed. If both routes can be selected with a runtime flag in the same binary, use that for cheap paired screening; otherwise build exactly two variants from the same pinned source commit. Capture source SHA, compiler, CPU, flags, seed, proof verification and elapsed time.

## Priority 2: alternative high-impact path
Inspect ordered PoW grind scheduling in crates/flock-core/src/challenger.rs. Latest promotion already introduces grind_cursor_scan, so compare its chunk claiming, synchronization, and early-exit overhead rather than reintroducing the same optimization. A microbenchmark must show how much of whole-proof time is spent there before optimization.

## Reject/accept gates
1. Unmodified baseline proof must pass the trusted verifier on the test host. Never accept timings from a failing baseline.
2. Source must match latest promoted version; fail closed if predicates drift.
3. Cheap tests: identical pinned CPU, Rust flags, paired seeds, alternating A/B order; report median and win count, not one-shot best.
4. Full validation: at least +2% median paired speedup and >=5/6 paired seeds faster, all trusted proofs passing; official benchmark is authoritative.
5. No Yukon submission until the acceptance gate passes.

## Execution environment
GitHub-hosted ubuntu-22.04/24.04 repeatedly assigned AMD EPYC 7763/9V74; those runs were quarantined. Do not loop retries. Free Kaggle/Colab can be tried for smoke builds and directional comparisons, but neither guarantees Sapphire Rapids or an official score. GitHub official challenge runner is a separate dedicated host, not the generic ubuntu runner in our diagnostic workflow.

## Current blockers
No cloud notebook has been executed, no new optimized Rust binary built, and no qualifying speedup measured. The previous packed-AB reduction candidate is unmeasured. This document is a reproducible research plan, not a completed optimization.
