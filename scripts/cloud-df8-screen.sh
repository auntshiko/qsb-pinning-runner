#!/usr/bin/env bash
# Free-cloud screening for the *existing* DirectFold8 reuse-vs-parallel switch.
# This is NOT the official Yukon benchmark; do not submit based on its result.
set -euo pipefail
ROOT="${1:-$PWD}"
cd "$ROOT"
test -f crates/flock-core/src/pcs/ring_switch.rs || { echo "Run inside a checked-out flock-challenge-multi source tree"; exit 2; }
grep -q 'FLOCK_NO_RS_REUSE_FOLD8_A' crates/flock-core/src/pcs/ring_switch.rs || { echo "Expected promoted switch absent; stop"; exit 2; }
grep -q 'fn direct_fold8_states_par' crates/flock-core/src/pcs/ring_switch.rs || { echo "Expected DirectFold8 function absent; stop"; exit 2; }
echo "SOURCE_REVISION=$(git rev-parse HEAD)"
echo "CPU=$(grep -m1 'model name' /proc/cpuinfo || true)"
echo "RUST=$(rustc --version)"
echo "CONTROL=default memory reuse; TREATMENT=FLOCK_NO_RS_REUSE_FOLD8_A=1 (independent A/W)"
echo "WARNING: On generic free-cloud CPUs, results are directional only."
# Do not burn compute on hosts that cannot exercise the ranked x86 kernel.
python3 - <<'PY'
from pathlib import Path
flags=next((line.split(':',1)[1].split() for line in Path('/proc/cpuinfo').read_text().splitlines() if line.startswith('flags')),[])
needed={'avx512f','gfni','vpclmulqdq'}
missing=sorted(needed-set(flags))
if missing:
    raise SystemExit("UNSUITABLE_CPU: missing "+", ".join(missing)+". Stop before setup/build.")
print("CPU_FEATURE_PREFLIGHT_PASSED")
PY
# The trusted harness calls env_clear() when spawning the worker.
# Allow ONLY the DirectFold8 experimental switch to cross this boundary.
python3 - <<'PY'
from pathlib import Path
p=Path("benchmark-tools/harness/src/main.rs")
s=p.read_text()
old='''.env_clear()
        .env("RAYON_NUM_THREADS", config.threads.to_string())'''
new='''.env_clear()
        .envs(std::env::vars().filter(|(key, _)| key == "FLOCK_NO_RS_REUSE_FOLD8_A"))
        .env("RAYON_NUM_THREADS", config.threads.to_string())'''
if s.count(old)!=1:
    raise SystemExit(f"HARNESS_ENV_PATCH_MISMATCH: {s.count(old)} matches")
p.write_text(s.replace(old,new,1))
print("HARNESS_SWITCH_FORWARDING_APPLIED")
PY
./setup.sh
. "${CARGO_HOME:-$HOME/.cargo}/env"
CARGO_INCREMENTAL=0 CARGO_NET_OFFLINE=true RUSTFLAGS="-C target-cpu=native" cargo +1.97.0 build --locked --offline --profile challenge --target-dir target/cloud-df8 -p flock-benchmark-worker -p flock-benchmark-harness
WORKER="$PWD/target/cloud-df8/challenge/flock-benchmark-worker"
HARNESS="$PWD/target/cloud-df8/challenge/flock_benchmark_harness"
test -x "$WORKER" && test -x "$HARNESS"
mkdir -p cloud-df8-results
printf 'variant\ttrial\tscore\n' > cloud-df8-results/scores.tsv
# Same binary, controlled environment switch. Fresh worker process per harness invocation.
# First establish that the trusted verifier accepts a baseline proof.
for trial in 1 2 3 4 5 6; do
  if (( trial % 2 )); then variants=(baseline parallel); else variants=(parallel baseline); fi
  for variant in "${variants[@]}"; do
    mkdir -p "cloud-df8-results/$variant-$trial"
    rm -f score.json
    if [[ "$variant" == parallel ]]; then export FLOCK_NO_RS_REUSE_FOLD8_A=1; else unset FLOCK_NO_RS_REUSE_FOLD8_A || true; fi
    "$HARNESS" "$WORKER" "$PWD/cloud-df8-results/$variant-$trial" "$PWD/score.json" "$PWD/cloud-df8-results/$variant-$trial.md" 18 1 0 1 > "cloud-df8-results/$variant-$trial.log" 2>&1 || { echo "TRUSTED_PROOF_OR_HARNESS_FAILURE variant=$variant trial=$trial; see log"; exit 3; }
    python3 - "$variant" "$trial" <<'PY'
import json,sys
d=json.load(open("score.json"))
score=d.get("score")
if not isinstance(score,(int,float)) or score<=0:
    raise SystemExit("missing trusted verification score")
with open("cloud-df8-results/scores.tsv","a") as f:
    f.write(f"{sys.argv[1]}\t{sys.argv[2]}\t{score}\n")
PY
  done
done
python3 - <<'PY'
import csv,statistics
d={(r["variant"],int(r["trial"])):float(r["score"]) for r in csv.DictReader(open("cloud-df8-results/scores.tsv"),delimiter="\t")}
gains=[100*(d["parallel",i]/d["baseline",i]-1) for i in range(1,7)]
print("paired_gain_percent",*[round(x,4) for x in gains])
print("median_paired_gain_percent",round(statistics.median(gains),4))
print("wins",sum(x>0 for x in gains),"/6")
print("DIRECTIONAL_ONLY: generic cloud host is not official Sapphire Rapids scoring")
PY
