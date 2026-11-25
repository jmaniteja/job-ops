---
id: native-local
title: Local Setup Without Docker
description: Install and run JobOps locally with Node, Python, JobSpy, and Typst.
sidebar_position: 2
---

## What it is

The native setup script installs the development runtime inside your checkout. It supports macOS and Linux on Intel or ARM. For Windows, use [Docker Compose](/docs/next/getting-started/self-hosting) or WSL2 with the Linux instructions.

## Why it exists

The local server needs Node for the app, Python and JobSpy for LinkedIn, Indeed, and Glassdoor search, and Typst for PDF generation. The repository ignores downloaded binaries, dependencies, credentials, and search data, so each machine needs its own installation.

## How to use it

```bash
git clone https://github.com/jmaniteja/job-ops.git
cd job-ops
bash scripts/bootstrap-local.sh
bash scripts/run-local.sh
```

Open `http://localhost:5173` and complete the first-run account setup. The API runs at `http://localhost:3001`. Keep the terminal running while you use JobOps. Press Ctrl+C to stop both servers.

The bootstrap script downloads Node 22.22.1, uv 0.13.10, Python 3.11, and Typst 0.14.2 into `.local-tools`, installs npm workspaces and the JobSpy Python packages, then migrates the local database. It does not install software globally. The binary archives are checked against their published SHA-256 hashes. It requires `bash`, `curl`, `tar`, and `shasum` or `sha256sum`.

On another machine, clone the repository and run the same two scripts. JobOps account data and search results are stored locally and are not transferred by Git. To move them, use the app's [database backup workflow](/docs/next/getting-started/database-backups) rather than committing them.

## Common problems

- **`Typst binary not found`:** Start the app with `bash scripts/run-local.sh`; it puts the installed Typst binary on `PATH` and sets `TYPST_BIN`.
- **Search results do not appear:** A source may be rate limited or blocked by a challenge. For example, Gradcracker can present a Cloudflare challenge. Cancel the active run, deselect Gradcracker in **Sources**, and start a new search. A run keeps its original source list after it starts.
- **Port already in use:** Stop the other process using ports 5173 or 3001 before starting JobOps.
- **Installer download fails:** Check access to `nodejs.org`, GitHub releases, npm, and PyPI, then rerun the bootstrap script.

## Related pages

- [Self-Hosting with Docker Compose](/docs/next/getting-started/self-hosting)
- [Database Backups](/docs/next/getting-started/database-backups)
