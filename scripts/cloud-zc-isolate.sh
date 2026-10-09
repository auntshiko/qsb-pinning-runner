#!/usr/bin/env bash
# Zerocheck correctness isolation on existing compiled worker. Not a performance benchmark.
set -euo pipefail
cd "${1:-$PWD}"
test -f benchmark-tools/harness/src/main.rs
test -x target/cloud-df8/challenge/flock-benchmark-worker
python3 - <<'PY'
from pathlib import Path
p=Path("benchmark-tools/harness/src/main.rs")
s=p.read_text()
keys=["FLOCK_NO_ZC_LOOKAHEAD","FLOCK_NO_ZC_SWEEP_NOMAT","FLOCK_NO_ZC_CASCADE2","FLOCK_NO_ZC_CASCADE3","FLOCK_NO_ZC_CASCADE4","FLOCK_NO_ZC_CASCADE5","FLOCK_NO_ZC_DEEP_CASCADE"]
anchor='.env_clear()'
# Strip earlier isolation's forwarding line to ensure one canonical allowlist.
lines=s.splitlines(keepends=True)
lines=[line for line in lines if not ('.envs(std::env::vars().filter(' in line)]
s=''.join(lines)
assert s.count(anchor)==1, "Expected exactly one harness environment clearing point"
allow=' | '.join('"'+k+'"' for k in keys)
insertion='\n        .envs(std::env::vars().filter(|(key, _)| matches!(key.as_str(), '+allow+')))'
s=s.replace(anchor,anchor+insertion,1)
p.write_text(s)
print("Harness forwards only explicit zerocheck diagnostic switches")
PY
. "${CARGO_HOME:-$HOME/.cargo}/env"
CARGO_INCREMENTAL=0 CARGO_NET_OFFLINE=true RUSTFLAGS="-C target-cpu=native" cargo +1.97.0 build --locked --offline --profile challenge --target-dir target/cloud-df8 -p flock-benchmark-harness
harness="$PWD/target/cloud-df8/challenge/flock_benchmark_harness"
worker="$PWD/target/cloud-df8/challenge/flock-benchmark-worker"
out="$PWD/cloud-df8-results/zc-isolation"
mkdir -p "$out"
printf 'variant\texit\tverified\terror\n' > "$out/results.tsv"
variants=(baseline no_lookahead no_nomat no_cascade2 no_cascade3 no_cascade4 no_cascade5 no_deep_cascade)
for variant in "${variants[@]}"; do
  unset FLOCK_NO_ZC_LOOKAHEAD FLOCK_NO_ZC_SWEEP_NOMAT FLOCK_NO_ZC_CASCADE2 FLOCK_NO_ZC_CASCADE3 FLOCK_NO_ZC_CASCADE4 FLOCK_NO_ZC_CASCADE5 FLOCK_NO_ZC_DEEP_CASCADE || true
  case "$variant" in
    no_lookahead) export FLOCK_NO_ZC_LOOKAHEAD=1 ;;
    no_nomat) export FLOCK_NO_ZC_SWEEP_NOMAT=1 ;;
    no_cascade2) export FLOCK_NO_ZC_CASCADE2=1 ;;
    no_cascade3) export FLOCK_NO_ZC_CASCADE3=1 ;;
    no_cascade4) export FLOCK_NO_ZC_CASCADE4=1 ;;
    no_cascade5) export FLOCK_NO_ZC_CASCADE5=1 ;;
    no_deep_cascade) export FLOCK_NO_ZC_DEEP_CASCADE=1 ;;
  esac
  echo "START $variant" 
  set +e
  "$harness" "$worker" "$out/${variant}-scratch" "$out/${variant}.json" "$out/${variant}.md" 18 1 0 1 > "$out/${variant}.log" 2>&1
  status=$?
  set -e
  if [[ "$status" == 0 ]] && grep -q 'verified=true' "$out/${variant}.log"; then verified=yes; else verified=no; fi
  error=$(tail -n 1 "$out/${variant}.log" | tr '\t' ' ')
  printf '%s\t%s\t%s\t%s\n' "$variant" "$status" "$verified" "$error" >> "$out/results.tsv"
  echo "DONE $variant: $verified (exit $status)"
  if [[ "$verified" == yes ]]; then echo "VALID_PATH_FOUND: $variant"; break; fi
done
cat "$out/results.tsv"
echo "CORRECTNESS_ONLY: no bounty performance claim"
