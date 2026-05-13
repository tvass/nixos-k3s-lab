# Claude guidelines for this project

## Code style

- Keep code straightforward and human readable. No clever tricks.
- Simplify and deduplicate whenever possible.
- Prefer clarity over brevity when the two conflict.
- Default to writing no comments unless the reason behind something is non-obvious.

## NixOS conventions

- Shared NixOS config goes in `nix/base.nix`. Control plane (server) specific in `nix/k3s-vm.nix`, worker (agent) specific in `nix/k3s-agent.nix`.
- Optional features belong in `local.nix` (user-local, gitignored). Add them as commented-out options in `local.nix.dist` with a short explanation.
- New files must be `git add`ed before building — Nix flakes only see git-tracked files.

## Git

- When committing, always add as co-author:
  `Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>`
- The blank line before the trailer is required for GitHub to recognize it.
