# QSB Pinning experiment: restore-square-f8 cut A/B

## Objective

This submission tests one isolated change against the current promoted Pinning candidate: disable `QSB_RESTORE_SQR_F8`, allowing the existing `QSB_SQR_FOLD8_CUT` path to remove the square/fused-square first-fold `f8` carry capture and consumer. No harness, benchmark, problem, workflow, or sibling-track files are changed. The only submitted source change is inside `candidates/pinning/GPUMath.h`.

The current promoted source already contains the implementation, kill switch, host publication gate, and detailed arithmetic rationale for this path. The promoted default currently restores square/fused `f8` retention with `QSB_RESTORE_SQR_F8=1`. This experiment sets that switch to 0 so Yukon can measure the alternative on the authoritative RTX 4090 runner.

## Why this is a useful isolated test

The Pinning implementation is already heavily optimized, so a broad rewrite would make attribution difficult and would consume evaluation capacity without a clean hypothesis. This experiment changes exactly one existing compile-time switch. The intended effect is to remove a carry-capture operation and its corresponding use in the square/fused-square reduction path. The multiply-side cut remains unchanged.

The source comments document the relevant condition: `f8` is the carry out of the first pseudo-Mersenne fold. Under the existing short-carry and host-gate design, the cut path treats the rare carry as a speculative-candidate error class rather than allowing it to affect publication correctness. The exact host recover-and-hash gate independently checks nominations before publication. This experiment does not weaken that host verification mechanism.

The change is deliberately small because the official score is noisy enough that multiple simultaneous micro-optimizations would be hard to interpret. If the score does not improve sufficiently, the experiment should be discarded rather than combined with unrelated changes.

## Correctness boundary

The challenge's frozen verifier and ranked runner remain authoritative. This submission does not modify any file outside `candidates/pinning/`. It does not modify the benchmark configuration, problem generator, CPU verifier, score computation, GitHub workflows, or bridge. It relies on Yukon's normal candidate composition and Eigen Labs-operated evaluation infrastructure.

The candidate's existing host gate remains enabled. Any GPU nomination must still survive the exact host recovery and hash check before it can become an output hit, and every reported hit remains subject to the challenge's independent CPU verifier. A failure of verification or insufficient verified hits should invalidate the run normally.

This is not a claim that the rare-carry approximation is universally exact. It is an empirical performance experiment using an approximation class already described and guarded in the current promoted candidate source. The purpose of the Yukon run is to determine whether the instruction reduction is beneficial on the ranked RTX 4090 workload while satisfying the challenge's correctness and statistical gates.

## Expected performance mechanism

With `QSB_RESTORE_SQR_F8=0`, the existing conditional macros permit `QSB_SQR_F8_CAP` to become empty and `QSB_SQR_F8SRC` to become zero when the surrounding short-carry, Z9-subtraction, and square-fold conditions are active. This removes work from field-square reduction sites used in the hot elliptic-curve recovery path.

The expected gain, if any, is a microarchitectural throughput improvement rather than an algorithmic complexity change. The candidate still performs the same overall Pinning search, ECDSA public-key recovery, hashing, nomination, host gating, and hit reporting. The search space and output interface are unchanged.

Because the current kernel has many interacting instruction-scheduling and register-pressure optimizations, fewer source-level operations do not guarantee a faster kernel. Removing the carry may alter ptxas scheduling, dependency chains, occupancy, or instruction mix in a way that is neutral or negative. For that reason no performance gain is asserted in advance. The official Yukon measurement is the decision criterion.

## Experimental discipline

This run intentionally avoids changing `QSB_SAS_DBL_ADD`. The current promoted candidate already uses mode 2 for that optimization, so the earlier idea of merely introducing the macro is no longer novel. Keeping it unchanged prevents conflating the square-f8 A/B with the cross-sum doubling schedule.

Likewise, no changes are made to `QSB_MUL_FOLD8_CUT`, `QSB_C31`, `QSB_SHORT_CARRY`, `QSB_SAS_Z9SUB_ALL`, `QSB_HOST_GATE`, root recovery, SHA scheduling, GLV decomposition, persistent-window sizing, batching, or host readback. This gives the evaluation a single causal variable.

The runner first clones the Yukon-linked benchmark rather than using a plain Git clone. It checks that the expected current default exists, changes only that default, records the diff, runs Yukon setup, and submits through the Yukon CLI. Local GitHub-hosted runners do not contain the protected ranked bridge or RTX 4090, so they are not used to manufacture a local ranked score.

## Acceptance criterion

The only meaningful success criterion is an official Yukon evaluation that passes correctness and exceeds the promotion threshold relative to the current Pinning baseline. A locally generated number, CPU smoke-test rate, GitHub Actions duration, or unverified CUDA estimate is not evidence of improvement.

If Yukon accepts but does not promote the candidate, the result should be treated as a failed performance experiment and the current promoted baseline retained. If Yukon promotes it, the resulting official candidate throughput and submission identifier should be recorded for the Taskmarket evidence package.

## Attribution

Model: GPT-5.6 Sol.
Coding/orchestration environment: ChatGPT with GitHub integration and a standard public GitHub Actions runner used only for Yukon CLI orchestration.
Benchmark and authoritative GPU evaluation: Yukon / Quantum Safe Bitcoin Pinning track.

The optimization hypothesis was selected after inspecting the current promoted Pinning source rather than applying an older patch blindly. The present baseline already includes a hybrid `QSB_SAS_DBL_ADD=2` implementation, so this submission instead tests an existing but currently restored square-fold carry cut as an isolated A/B.

## Reproducibility

Conceptually, the candidate delta is equivalent to changing the default:

`#define QSB_RESTORE_SQR_F8 1`

to:

`#define QSB_RESTORE_SQR_F8 0`

inside `candidates/pinning/GPUMath.h`, with no other candidate modifications. The workflow verifies the exact source pattern before replacement and fails rather than silently submitting if the upstream baseline has changed. This guards against accidentally applying the experiment to an incompatible future candidate.

The authoritative run should be interpreted only against the baseline Yukon associates with the cloned Pinning benchmark at submission time. If the upstream promoted baseline changes before evaluation, Yukon's normal candidate composition and promotion rules remain authoritative.

## Decision after evaluation

On promotion: preserve the promoted implementation, capture the official score and receipt, and prepare Taskmarket evidence before its deadline.

On accepted but non-promoted result: do not represent it as an earning event. Revert the hypothesis and use the official measurement to select the next isolated experiment.

On correctness failure: do not retry the same approximation blindly. Treat the failure as evidence that the current host-gate/rare-carry assumptions are insufficient for the sampled ranked workload and restore square/fused f8 retention.

On infrastructure failure: distinguish it from a candidate failure using the Yukon submission status and logs. Do not repeatedly upload an identical queued submission.

This note intentionally makes no claim of earnings, prize entitlement, or payment before an accepted and promoted Yukon result and the separate Taskmarket eligibility/payment process are verified.
