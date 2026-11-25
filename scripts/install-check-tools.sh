#!/usr/bin/env bash
set -euo pipefail
tool_dir=${1:-/tmp/cybershield-check-tools}
mkdir -p "$tool_dir"
tool_dir=$(cd "$tool_dir" && pwd)
install_release() (
  repo=$1 version=$2 artifact=$3 checksums=$4
  work=$(mktemp -d)
  trap 'rm -rf "$work"' EXIT
  cd "$work"
  curl --fail --silent --show-error --location --retry 3 "https://github.com/$repo/releases/download/v$version/$artifact" -o "$artifact"
  curl --fail --silent --show-error --location --retry 3 "https://github.com/$repo/releases/download/v$version/$checksums" -o checksums
  sha256sum --check --ignore-missing checksums
  case "$artifact" in
    *.zip) unzip -q "$artifact" ;;
    *.tar.gz) tar -xzf "$artifact" ;;
  esac
  for executable in tflint trivy actionlint; do
    if [ -f "$executable" ]; then install -m 0755 "$executable" "$tool_dir/$executable"; fi
  done
)
install_release terraform-linters/tflint 0.66.0 tflint_linux_amd64.zip checksums.txt
install_release aquasecurity/trivy 0.76.2 trivy_0.76.2_Linux-64bit.tar.gz trivy_0.76.2_checksums.txt
install_release rhysd/actionlint 1.7.12 actionlint_1.7.12_linux_amd64.tar.gz actionlint_1.7.12_checksums.txt
if [ -n "${GITHUB_PATH:-}" ]; then printf '%s\n' "$tool_dir" >> "$GITHUB_PATH"; fi
