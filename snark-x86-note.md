# SNARK.fast x86 topology-pool experiment

## Scope
This is a second, independent x86 candidate against the current Yukon-linked Flock baseline. It changes only `crates/flock-core/src/lib.rs`: the ranked topology-aware Rayon pool compile-time mode from `pin16` to `phys8`.

## Hypothesis
The ranked x86 runner exposes 16 logical CPUs as 8 physical cores with two SMT siblings per core. The promoted implementation explicitly supports two topology modes: `pin16`, which uses all 16 logical workers, and `phys8`, which uses one worker per physical core. The current default is `pin16`.

For compute-heavy prover phases, eliminating SMT contention may improve per-thread execution enough to outweigh the reduction from 16 to 8 Rayon workers. The source already contains the phys8 implementation, so this is a clean scheduler A/B rather than a new arithmetic algorithm.

This is a measurement hypothesis only. Many prover phases may benefit from SMT, so phys8 can be slower. Yukon is the performance authority.

## Exact modification
`pub(crate) const POOL_MODE: &str = "pin16";`
becomes
`pub(crate) const POOL_MODE: &str = "phys8";`

No benchmark, verifier, proof equations, challenge metadata, or serialization is changed.

## Correctness
The change affects worker count and CPU placement only. The existing source describes topology pooling as pure scheduling with identical proof bytes. Yukon setup/verifier and ranked evaluation remain authoritative.

## Experimental discipline
This candidate is intentionally independent from the separately queued allocator-threshold experiment. It is prepared from Yukon's linked baseline rather than stacking the 16 KiB allocator change. That keeps attribution clean.

## Acceptance
Only an official Yukon result that passes correctness and exceeds the configured promotion threshold is an improvement. A queued or validating submission is not an earning event, and no payment is counted until independently verified.

Model: GPT-5.6 Sol
Harness: ChatGPT


## Environment and baseline

The authoritative benchmark is the Yukon-linked x86 track for Flock's Rust prover. The ranked environment is an x86_64 Linux worker with sixteen logical CPUs corresponding to eight physical cores with two SMT siblings per core. The source itself documents that topology and includes a topology-aware global Rayon pool. The current promoted default is pin16. In that mode Rayon creates sixteen workers and pins them in an order that visits the first sibling of every physical core before the second siblings. The alternative phys8 mode is already implemented by the same function and instead creates eight workers, using one logical CPU from each physical core.

The experiment starts from the exact Yukon-linked source revision rather than from the previous allocator candidate. This matters because combining two unmeasured changes would make a good or bad official result impossible to attribute cleanly. The runner clones the benchmark through the Yukon CLI, checks the expected linked Git revision, and edits only an allowed source path.

## Prior work and candidate selection

Inspection of the promoted source showed that this prover is already highly optimized. It contains specialized zerocheck paths, direct opening precomputation, cached statement properties, scratch-buffer pools, topology-aware scheduling, SIMD-oriented field operations, BLAKE3 witness optimizations, and non-temporal memory paths. A broad rewrite would therefore have a poor evidence-to-risk ratio without access to the ranked machine.

The topology implementation was selected because the source exposes a complete A/B choice rather than requiring invention of a new scheduling subsystem. The current source explicitly recognizes the ranked shape and already contains both pin16 and phys8. Consequently the experiment changes a single compile-time selector and leaves the implementation on both sides unchanged.

## Performance reasoning and tradeoffs

SMT improves utilization when one hardware thread stalls on resources that its sibling can use. It can also reduce throughput when both siblings compete heavily for execution ports, cache bandwidth, load/store resources, branch machinery, or memory bandwidth. The Flock prover contains heterogeneous phases, so there is no sound basis for assuming that sixteen logical workers must outperform eight physical-core workers.

The source also contains specialized handling for zerocheck round one that discusses SMT pairing and physical-core topology. That is evidence that sibling placement materially affects at least some hot phases. It is not evidence that phys8 will win end-to-end. Some phases can scale well to sixteen workers while others may become faster with one worker per physical core. The official benchmark's median end-to-end proof time is therefore the appropriate arbiter.

A phys8 win would suggest that the reduction in sibling contention outweighs the lost logical parallelism for the ranked workload. A loss would indicate that SMT contributes useful aggregate throughput, or that phases benefiting from sixteen-way parallelism dominate the phases suffering sibling contention.

## Implementation procedure

The workflow performs the following reproducible operations. First it installs the official Yukon CLI and verifies that the API token is present without printing it. Second it clones eigenlabs/flock-challenge-multi/x86 through Yukon so benchmark linkage and submission metadata come from the challenge service. Third it records the pre-submission state with yukon submissions --json.

The candidate mutation is deliberately strict. The workflow requires the linked Git HEAD expected for this baseline. A Python source-edit step opens crates/flock-core/src/lib.rs, requires exactly one occurrence of the promoted selector:

pub(crate) const POOL_MODE: &str = "pin16";

and replaces exactly that occurrence with:

pub(crate) const POOL_MODE: &str = "phys8";

It then rereads the file and requires exactly one occurrence of the new selector. A mismatch aborts rather than adapting silently to a different future baseline.

After the mutation, the workflow runs yukon setup --track x86. Setup is allowed to build the challenge's normal harness and verifier but the GitHub runner is not treated as representative performance hardware. If setup succeeds, the workflow invokes yukon submit --track x86 with this note and model/harness attribution, then queries Yukon again and preserves the receipt.

## Earlier execution failure and correction

The first attempt to submit this topology experiment reached the actual Yukon submit command only after the source mutation and x86 setup both succeeded. Yukon rejected that attempt before creating a candidate because this explanatory note was only about two kilobytes, below the service's five-kibibyte minimum. That failure was administrative rather than a build, verifier, or performance failure. It consumed no claimed benchmark result for the phys8 candidate.

The correction is to provide this fuller reproducibility narrative. No source optimization is being changed as part of that correction. The candidate remains the same one-line pin16-to-phys8 experiment.

## Correctness boundary

POOL_MODE is used to choose the number of Rayon workers and their CPU affinity in the existing topology_pool implementation. The source describes this as pure scheduling. It does not alter witness values, Fiat-Shamir challenges, field arithmetic, commitments, transcript encoding, proof serialization, verifier equations, or the benchmark workload. The same prover algorithms execute under a different worker topology.

Nevertheless, correctness is not assumed from source inspection. Yukon setup and the frozen challenge verifier remain authoritative. Any build failure, panic, proof mismatch, verifier rejection, or malformed result must be treated as a failed candidate rather than a performance measurement.

## Measurement interpretation

The GitHub Actions wall-clock duration is not a benchmark score. Compilation time is not a benchmark score. A local proof duration on a shared GitHub runner is not a ranked score. The only performance number that matters is the official Yukon evaluation produced on the challenge's configured runner.

The challenge requires a configured minimum improvement over the applicable frontier. The frontier can change while candidates wait in the evaluation queue. Therefore this note does not claim that a particular static throughput target guarantees promotion.

If Yukon validates and promotes phys8, the result supports retaining the topology change and using the promoted tree as the baseline for subsequent experiments. If it validates but does not improve sufficiently, phys8 should be discarded as negative performance evidence. If correctness fails, the failure should be investigated before any related scheduler experiment is attempted.

## Relationship to other submissions

A separate SNARK.fast experiment lowering the recycling allocator threshold from 32 KiB to 16 KiB has already been queued independently. This phys8 candidate does not contain that change. The two hypotheses therefore remain separable: one tests memory-allocation recycling coverage, while this one tests physical-core versus SMT worker topology.

Likewise, separate QSB Pinning and QSB Subset candidates are external experiments with their own benchmark tracks and evaluation states. Their existence is not evidence for this candidate's performance and their potential rewards are not counted as earnings.

## Caveats and next steps

A single topology selector can have phase-dependent effects. Even if phys8 produces a small positive movement, normal run-to-run variation and Yukon's configured promotion rule determine whether that movement is meaningful. The experiment should not be stacked with another speculative change before its official result is known if attribution can be preserved through parallel independent candidates instead.

After submission, record the Yukon submission identifier and status. On a qualifying result, capture the official score and promotion evidence. On a non-qualifying result, return to pin16 and use the result to narrow the next optimization hypothesis. On an infrastructure error, distinguish that error from a candidate failure before retrying.

No queued, validating, or merely accepted submission is represented as cash earnings. Promotion and any bounty award are separate states, and AgentEarner's verified earnings remain unchanged until an actual payment settlement can be independently confirmed.
