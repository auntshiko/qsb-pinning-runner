#!/usr/bin/env bash
# Focused, trusted 2^18 correctness isolation. Not a performance claim.
set -euo pipefail
cd "${1:-$PWD}"
test -f benchmark-tools/harness/src/main.rs
test -x target/cloud-df8/challenge/flock-benchmark-worker
python3 - <<'PY'
from pathlib import Path
p=Path("benchmark-tools/harness/src/main.rs")
s=p.read_text()
old='.envs(std::env::vars().filter(|(key, _)| key == "FLOCK_NO_RS_REUSE_FOLD8_A"))'
new='.envs(std::env::vars().filter(|(key, _)| matches!(key.as_str(), "FLOCK_NO_RS_REUSE_FOLD8_A" | "FLOCK_NO_RS_TAIL_PAR" | "FLOCK_NO_RS_ELIDE_DEAD_BASIS")))'
if old in s:
    p.write_text(s.replace(old,new,1))
elif new not in s:
    anchor='.env_clear()'
    if s.count(anchor)!=1:
        raise SystemExit("HARNESS_ENV_FORWARDING_NOT_FOUND; refusing untrusted comparison")
    p.write_text(s.replace(anchor,anchor+'\\n        '+new,1))
PY
. "${CARGO_HOME:-$HOME/.cargo}/env"
CARGO_INCREMENTAL=0 CARGO_NET_OFFLINE=true RUSTFLAGS="-C target-cpu=native" cargo +1.97.0 build --locked --offline --profile challenge --target-dir target/cloud-df8 -p flock-benchmark-harness
harness="$PWD/target/cloud-df8/challenge/flock_benchmark_harness"
worker="$PWD/target/cloud-df8/challenge/flock-benchmark-worker"
mkdir -p cloud-df8-results/isolation
printf 'variant\texit\tverified\terror\n' > cloud-df8-results/isolation/results.tsv
for variant in baseline no_reuse no_tail_parallel no_dead_basis_elision; do
  unset FLOCK_NO_RS_REUSE_FOLD8_A FLOCK_NO_RS_TAIL_PAR FLOCK_NO_RS_ELIDE_DEAD_BASIS || true
  case "$variant" in
    no_reuse) export FLOCK_NO_RS_REUSE_FOLD8_A=1 ;;
    no_tail_parallel) export FLOCK_NO_RS_TAIL_PAR=1 ;;
    no_dead_basis_elision) export FLOCK_NO_RS_ELIDE_DEAD_BASIS=1 ;;
  esac
  set +e
  "$harness" "$worker" "$PWD/cloud-df8-results/isolation/${variant}-scratch" "$PWD/cloud-df8-results/isolation/${variant}.json" "$PWD/cloud-df8-results/isolation/${variant}.md" 18 1 0 1 > "cloud-df8-results/isolation/${variant}.log" 2>&1
  status=$?
  set -e
  if [[ "$status" == 0 ]] && grep -q 'verified=true' "cloud-df8-results/isolation/${variant}.log"; then verified=yes; else verified=no; fi
  error=$(tail -n 1 "cloud-df8-results/isolation/${variant}.log" | tr '\t' ' ')
  printf '%s\t%s\t%s\t%s\n' "$variant" "$status" "$verified" "$error" >> cloud-df8-results/isolation/results.tsv
  echo "$variant: $verified (exit $status)"
done
cat cloud-df8-results/isolation/results.tsv
echo "CORRECTNESS_ONLY: no bounty performance claim"
