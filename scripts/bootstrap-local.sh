#!/usr/bin/env bash
set -euo pipefail

# Install the native development runtime inside this checkout. Nothing is
# installed globally, and user data stays outside version control.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tools_dir="$repo_root/.local-tools"
node_version="22.22.1"
typst_version="0.14.2"
uv_version="0.13.10"

case "$(uname -s):$(uname -m)" in
  Darwin:x86_64)
    node_target="darwin-x64"
    tool_target="x86_64-apple-darwin"
    typst_sha256="4e91d8e1e33ab164f949c5762e01ee3faa585c8615a2a6bd5e3677fa8506b249"
    ;;
  Darwin:arm64)
    node_target="darwin-arm64"
    tool_target="aarch64-apple-darwin"
    typst_sha256="470aa49a2298d20b65c119a10e4ff8808550453e0cb4d85625b89caf0cedf048"
    ;;
  Linux:x86_64)
    node_target="linux-x64"
    tool_target="x86_64-unknown-linux-musl"
    typst_sha256="a6044cbad2a954deb921167e257e120ac0a16b20339ec01121194ff9d394996d"
    ;;
  Linux:aarch64|Linux:arm64)
    node_target="linux-arm64"
    tool_target="aarch64-unknown-linux-musl"
    typst_sha256="491b101aa40a3a7ea82a3f8a6232cabb4e6a7e233810082e5ac812d43fdcd47a"
    ;;
  *)
    echo "Unsupported platform. Use Docker Compose or install Node 22, Python 3.11, and Typst 0.14.2 manually." >&2
    exit 1
    ;;
esac
uv_target="$tool_target"

for command_name in curl tar; do
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "Missing required command: $command_name" >&2
    exit 1
  fi
done
if command -v shasum >/dev/null 2>&1; then
  checksum_command=(shasum -a 256)
elif command -v sha256sum >/dev/null 2>&1; then
  checksum_command=(sha256sum)
else
  echo "A SHA-256 checker (shasum or sha256sum) is required." >&2
  exit 1
fi

mkdir -p "$tools_dir"
cd "$tools_dir"

node_archive="node-v${node_version}-${node_target}.tar.xz"
node_dir="$tools_dir/node-v${node_version}-${node_target}"
if [[ ! -x "$node_dir/bin/node" ]]; then
  echo "Installing Node $node_version..."
  curl --fail --location --retry 3 --output "$node_archive" "https://nodejs.org/dist/v${node_version}/${node_archive}"
  curl --fail --location --retry 3 --output "node-SHASUMS256.txt" "https://nodejs.org/dist/v${node_version}/SHASUMS256.txt"
  expected="$(awk -v name="$node_archive" '$2 == name { print $1 }' node-SHASUMS256.txt)"
  actual="$("${checksum_command[@]}" "$node_archive" | awk '{ print $1 }')"
  if [[ -z "$expected" || "$actual" != "$expected" ]]; then
    echo "Node archive checksum mismatch." >&2
    exit 1
  fi
  tar -xf "$node_archive"
fi
export PATH="$node_dir/bin:$PATH"

uv_dir="$tools_dir/uv-${uv_target}"
uv_bin="$uv_dir/uv"
if [[ ! -x "$uv_bin" ]]; then
  echo "Installing uv $uv_version..."
  curl --fail --location --retry 3 --output "uv.tar.gz" \
    "https://github.com/astral-sh/uv/releases/download/${uv_version}/uv-${uv_target}.tar.gz"
  curl --fail --location --retry 3 --output "uv.tar.gz.sha256" \
    "https://github.com/astral-sh/uv/releases/download/${uv_version}/uv-${uv_target}.tar.gz.sha256"
  expected="$(awk '{ print $1 }' uv.tar.gz.sha256)"
  actual="$("${checksum_command[@]}" uv.tar.gz | awk '{ print $1 }')"
  if [[ -z "$expected" || "$actual" != "$expected" ]]; then
    echo "uv archive checksum mismatch." >&2
    exit 1
  fi
  tar -xzf uv.tar.gz
fi
export UV_PYTHON_INSTALL_DIR="$tools_dir/python"
export UV_CACHE_DIR="$tools_dir/uv-cache"

typst_dir="$tools_dir/typst-${tool_target}"
typst_bin="$typst_dir/typst"
if [[ ! -x "$typst_bin" ]]; then
  echo "Installing Typst $typst_version..."
  curl --fail --location --retry 3 --output "typst.tar.xz" \
    "https://github.com/typst/typst/releases/download/v${typst_version}/typst-${tool_target}.tar.xz"
  actual="$("${checksum_command[@]}" typst.tar.xz | awk '{ print $1 }')"
  if [[ "$actual" != "$typst_sha256" ]]; then
    echo "Typst archive checksum mismatch." >&2
    exit 1
  fi
  tar -xf typst.tar.xz
fi
if [[ "$("$typst_bin" --version)" != typst\ "$typst_version"* ]]; then
  echo "Unexpected Typst version; expected $typst_version." >&2
  exit 1
fi
ln -sf "$typst_bin" "$node_dir/bin/typst"

cd "$repo_root"
echo "Installing Node workspaces..."
npm_config_cache="$tools_dir/npm-cache" npm ci
echo "Installing Python 3.11 and JobSpy..."
"$uv_bin" python install 3.11 --no-bin
if [[ ! -x extractors/jobspy/.venv/bin/python ]] || \
  [[ "$(extractors/jobspy/.venv/bin/python --version 2>&1)" != Python\ 3.11.* ]]; then
  "$uv_bin" venv --python 3.11 --clear extractors/jobspy/.venv
fi
"$uv_bin" pip install --python extractors/jobspy/.venv/bin/python \
  -r extractors/jobspy/requirements.txt

echo "Migrating the local database..."
npm --workspace orchestrator run db:migrate
echo "Setup complete. Start JobOps with: ./scripts/run-local.sh"
