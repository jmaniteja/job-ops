#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
node_version="22.22.1"
case "$(uname -s):$(uname -m)" in
  Darwin:x86_64) target="darwin-x64" ;;
  Darwin:arm64) target="darwin-arm64" ;;
  Linux:x86_64) target="linux-x64" ;;
  Linux:aarch64|Linux:arm64) target="linux-arm64" ;;
  *) echo "Unsupported platform. See the native setup guide." >&2; exit 1 ;;
esac

node_dir="$repo_root/.local-tools/node-v${node_version}-${target}"
if [[ ! -x "$node_dir/bin/node" || ! -x "$node_dir/bin/typst" ]]; then
  echo "Local runtime missing. Run ./scripts/bootstrap-local.sh first." >&2
  exit 1
fi

export PATH="$node_dir/bin:$PATH"
export TYPST_BIN="$node_dir/bin/typst"
cd "$repo_root"
exec npm --workspace orchestrator run dev
