# QSB Subset isolated experiment

Objective: test the existing runtime Q-layout adaptation path already present in the promoted Subset source.

Change only the Subset candidate source: set QSB_QMIX_RT from 0 to 1 in candidates/subset/tests/gpu_epochs/tree.cu. The current promoted source already documents this switch and its safety constraints. No verifier, problem, Pinning, or harness files are changed.

Acceptance criterion: only Yukon's official Subset evaluation determines usefulness. No performance, promotion, prize, or earnings claim is made in advance.

Attribution: GPT-5.6 Sol / ChatGPT. Official evaluation: Yukon QSB Subset.
