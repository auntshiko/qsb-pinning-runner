# SNARK.fast x86 allocator-threshold experiment

## Scope
This candidate tests exactly one source-level change against the current Yukon-linked x86 SNARK.fast baseline: lower the existing prover recycling allocator threshold from 32 KiB to 16 KiB in crates/flock-prover/src/recycle_alloc.rs. No benchmark, verifier, workload, proof-system equation, transcript, serialization, or challenge metadata is changed.

## Hypothesis
The promoted prover already uses exact-size recycling for large allocations. The ranked worker performs an untimed warm proof before the timed proof, so repeated exact-size allocations can be resident for the measured request. The current cutoff excludes allocations between 16 KiB and 32 KiB. If a meaningful population of recurrent prover scratch or phase-local buffers lies in that interval, broadening the existing recycler can reduce allocator/system traffic during the timed proof. Eligible buffers also receive the recycler's existing 64-byte alignment treatment, which can avoid cache-line splits for wide x86 loads and stores.

This is a measurement hypothesis, not a performance claim. The tradeoff can be negative: more allocations enter the class lookup and Mutex-protected freelists, additional size classes may be populated, and non-recurrent medium allocations may pay bookkeeping without reuse. Yukon is the authority for deciding the end-to-end effect.

## Exact modification
The promoted source contains:
const RECYCLE_MIN: usize = 32 * 1024;

The candidate changes only that line to:
const RECYCLE_MIN: usize = 16 * 1024;

The workflow refuses to continue if the expected promoted line is absent. It then runs git diff --check and requires exactly one changed solver file. This prevents silently applying the experiment to a materially different future baseline.

## Correctness
The threshold does not change requested allocation sizes, layouts visible to callers, object lifetimes, proof values, transcript values, or verifier behavior. It only broadens which allocations satisfying the existing recyclable predicate use the already-promoted exact-size freelist mechanism. The same alignment constraint, size-class matching, push/pop implementation, and System backing allocator remain in place. A recycled allocation still comes from the exact same requested size class.

No cryptographic output is intentionally changed. Yukon's pinned verifier remains the correctness authority. Any build, memory-safety, proof, serialization, or verification failure must be treated as rejection rather than as a throughput result.

## Reproduction
1. Clone the Yukon-linked x86 challenge worktree.
2. Confirm the current submission state with yukon submissions --json.
3. Locate crates/flock-prover/src/recycle_alloc.rs.
4. Require the exact 32 KiB promoted constant.
5. Replace it with 16 KiB.
6. Run git diff --check.
7. Require git status under the editable source to show only recycle_alloc.rs.
8. Run yukon setup --track x86.
9. Submit with this note and model/harness metadata.
10. Query submissions again and preserve the receipt.

The GitHub runner is used only to construct and submit the source candidate. It is not treated as a representative performance machine and no local throughput number is claimed.

## Why isolate this axis
The current x86 tree already contains extensive specialized work in zerocheck kernels, Ligerito, NTT, BLAKE3 witness generation, streaming stores, proof publication, SIMD transposition, and memory handling. Bundling another large kernel rewrite without the ranked hardware would make attribution poor. The allocator cutoff is a compact systems parameter inside an optimization mechanism that is already part of the promoted source.

A one-line experiment gives an unambiguous result. If it promotes, the broader threshold becomes part of the baseline. If it verifies but fails to improve enough, restore 32 KiB and choose a different axis. Do not stack another speculative optimization on a losing threshold.

## Measurement and promotion
The only accepted performance evidence is the official Yukon evaluation. A valid but non-qualifying result is not represented as an improvement. A validating submission is not represented as earned money. Promotion is distinct from payment, and payment is not counted as AgentEarner earnings until settlement is independently verified.

The challenge requires an improvement over the applicable frontier according to its configured promotion rule. The frontier can change while this submission is queued, so this note intentionally does not encode a guaranteed target score.

## Safety and provenance
The change remains within the challenge's declared solver-editable Rust source. It does not alter protected benchmark infrastructure or attempt to bypass verification. The experiment was prepared with GPT-5.6 Sol through ChatGPT. The reasoning here is a reproducible engineering rationale and does not include hidden model reasoning.

## Expected interpretation
Outcome A: correctness passes and the score qualifies. Keep the change and use the newly promoted tree as the next baseline.

Outcome B: correctness passes but score is below promotion. Treat the experiment as negative evidence for this cutoff at the ranked shape, revert completely, and test a different isolated optimization.

Outcome C: build/correctness fails. Inspect the evaluator receipt, restore the promoted baseline, and do not combine this change with another candidate.

This experiment deliberately makes no claim that 16 KiB is intrinsically superior to 32 KiB. Its purpose is to let the controlled end-to-end benchmark answer that question with minimal confounding.
