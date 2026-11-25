#!/usr/bin/env bash
# One root, isolated backend caches, unchanged regional state keys.
set -euo pipefail
if [ "$#" -lt 2 ]; then echo "Usage: bash scripts/tf.sh region-a|region-b init|plan|apply|output|state|show|validate ..." >&2; exit 2; fi
repo=$(cd -- "$(dirname -- "$0")/.." && pwd)
region_key=$1
shift
case "$region_key" in region-a|region-b) ;; *) echo 'Use region-a or region-b' >&2; exit 2 ;; esac
export TF_DATA_DIR="${TF_DATA_DIR:-$repo/.terraform-data/$region_key}"
root="$repo/infra/envs/dr"
config="$repo/infra/envs/$region_key"
operation=$1
shift
case "$operation" in
  init) exec terraform -chdir="$root" init -input=false -lockfile=readonly -backend-config="$config/backend.hcl" "$@" ;;
  plan) exec terraform -chdir="$root" plan -input=false -lock-timeout=60s -var-file="$config/region.tfvars" "$@" ;;
  apply) [ "$#" -eq 1 ] && [ -f "$1" ] || { echo "Apply requires exactly one reviewed saved-plan file" >&2; exit 2; }; plan_file=$(realpath "$1"); exec terraform -chdir="$root" apply -input=false "$plan_file" ;;
  output|state|show|validate) exec terraform -chdir="$root" "$operation" "$@" ;;
  *) echo 'Use init, plan, apply (saved plan), output, state, show or validate' >&2; exit 2 ;;
esac
