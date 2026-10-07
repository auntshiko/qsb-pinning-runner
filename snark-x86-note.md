# SNARK.fast x86 Fold8 reuse A/B experiment

## Scope and hypothesis

This independent candidate tests one existing memory-scheduling optimization in the ranked DirectFold8 ring-switch path. The promoted source enables `rs_reuse_fold8_a_state_enabled()` by default. With reuse enabled, it first materializes A into a separate state buffer, then repurposes the original Fold8 allocation as W. This saves one large allocation but serializes the A and W state construction.

The alternative path already present in the promoted source allocates W separately and constructs W and A concurrently with `rayon::join`. On a 16-logical-CPU ranked machine, the extra allocation may be cheaper than serializing two substantial state builders. This experiment disables only the reuse optimization so Yukon can measure that tradeoff end to end.

## Exact change

In `crates/flock-core/src/pcs/ring_switch.rs`, change the default of `rs_reuse_fold8_a_state_enabled()` from enabled to disabled while retaining its existing environment escape. Concretely, the candidate changes the predicate so the ranked cleared environment takes the already-implemented no-reuse branch.

No proof equations, transcript, benchmark, verifier, challenge metadata, or serialization are modified.

## Baseline and source analysis

The DirectFold8 implementation retains 64 bank coordinates and builds two bit-major factor states, A and W. The current direct state builder avoids older collect-then-gather intermediates. In the reuse branch it calls `direct_fold8_a_state_into`, moves the old Fold8 allocation into `w_state`, and then calls `direct_fold8_w_state_into`. In the no-reuse branch it allocates W and uses `rayon::join` to execute those two builders concurrently.

The candidate does not disable DirectFold8, AVX-512 reductions, GFNI state generation, direct state construction, dead-basis elimination, or the parallel ring-switch tail. It isolates only allocation reuse versus parallel construction.

## Performance tradeoff

Reuse reduces allocation pressure and memory footprint. However, it imposes a dependency: W cannot overwrite the Fold8 allocation until A has finished reading it. The no-reuse branch removes that dependency by providing an independent W destination, allowing the two state builders to overlap. The ranked workload has substantial CPU parallelism, so the overlap may reduce critical-path latency even if it consumes additional memory bandwidth and allocator work.

The opposite outcome is entirely plausible. If A and W already saturate shared execution or memory resources, running them concurrently can create contention, and the additional allocation can make no-reuse slower. This is why the change is an A/B benchmark candidate rather than a claimed improvement.

## Environment and reproducibility

The workflow clones the Yukon-linked x86 benchmark, verifies the expected baseline revision and source pattern, changes exactly the targeted predicate, runs `yukon setup --track x86`, submits through the official Yukon CLI, and records the resulting submission state. The public GitHub runner is orchestration infrastructure only; its wall-clock time is not used as performance evidence.

The source mutation is fail-closed: if the exact promoted predicate is absent or occurs an unexpected number of times, the workflow exits rather than applying an approximate patch to a changed baseline.

## Correctness boundary

Both branches already exist in the promoted implementation and feed the same `DirectFold8Factors`. They differ in ownership, allocation, and scheduling of state construction, not in the mathematical target. The resulting proof must still pass Yukon's authoritative verifier. Any mismatch, panic, malformed proof, or setup failure is a candidate failure, not a throughput result.

## Prior experiments and isolation

This candidate does not contain the rejected 16 KiB recycler threshold experiment. That experiment received an official score below the observed frontier and is therefore not carried forward. It also does not contain the separately queued phys8 topology experiment. Keeping each hypothesis on the promoted baseline makes the official measurements attributable.

The allocator experiment tested which medium allocations enter the global recycler. The phys8 experiment tests Rayon worker topology. This experiment instead tests whether retaining a Fold8 allocation is worth serializing two factor-state builders.

## Submission-note requirement and execution history

A previous phys8 submission attempt demonstrated that Yukon enforces a minimum explanatory-note size before accepting a candidate. This note therefore records the complete engineering rationale and reproduction boundary in advance. That administrative requirement is independent of candidate correctness and performance.

## Measurement and decision rule

Only Yukon's official ranked evaluation is accepted as evidence. A GitHub Actions success means only that setup and submission orchestration worked. A validating status is not a score. A score below the active promotion threshold is negative evidence even if the proof verifies.

If this no-reuse candidate promotes, the result supports parallel A/W construction despite the extra allocation. If it verifies but does not qualify, retain the promoted reuse behavior. If it fails correctness, do not combine it with another speculative change.

## Detailed implementation context

The relevant promoted function is `direct_fold8_states_par`. It computes `state_len = 64 * n_packed` and requires the incoming Fold8 vector to have exactly that length. With reuse enabled, it allocates A, fills A from Fold8, transfers ownership of Fold8 into W, then overwrites W with the W-state generator. This ordering is explicitly necessary because scatter stores into the reused allocation would otherwise destroy input banks still needed by the A producer.

With reuse disabled, it allocates independent A and W buffers and invokes the W and A producers as the two arms of a Rayon join. Because neither output aliases the Fold8 input, both operations may proceed simultaneously. Once both finish, the same wide round-zero reduction consumes A and W.

Thus the experiment does not introduce a new algorithm. It selects between two existing, source-supported execution schedules whose values are intended to be identical.

## Resource considerations

The state is large enough that allocation reuse is meaningful, but the benchmark performs an untimed warm proof and the project already contains recycling and scratch-pool mechanisms. That makes it reasonable to test whether the apparent allocation saving is still worth the lost overlap during the timed proof. Conversely, concurrent construction can increase instantaneous cache and memory-bandwidth pressure. The ranked Sapphire Rapids machine, not a generic runner, must settle this tradeoff.

## Failure handling

If source setup fails, preserve the logs and do not submit. If Yukon rejects the note or metadata before creating a submission, correct the administrative problem without changing the candidate. If a submission is created, never resubmit the identical candidate merely because evaluation is pending. If the official result is negative, return to the promoted baseline before selecting another optimization.

## Earnings accounting

This experiment is bounty work, but submission is not payment. Validation is not payment, and even promotion is tracked separately from settlement. AgentEarner verified earnings remain unchanged until an actual reward transaction or other settlement is independently confirmed.

Model: GPT-5.6 Sol
Harness: ChatGPT
