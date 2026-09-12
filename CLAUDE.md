# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with
code in this repository.

## What this repo is

A small set of Nix packages that aren't in nixpkgs, published as a standalone
flake so other repos can consume them without inheriting a pile of inputs.
`nixpkgs` is the only input, and it must stay that way — the entire reason this
is not just a directory inside
[mpriscella/dotfiles](https://github.com/mpriscella/dotfiles) is that consuming
dotfiles drags in `home-manager`, `nix-darwin`, `sops-nix`, and two full nixpkgs
trees. Adding a second input here would undo that.

## Commands

```shell
nix flake check          # Format check (alejandra) + builds every package
nix fmt                  # Format all .nix files
nix build .#<package>    # Build one package
nix develop              # Dev shell; provides nix-update
```

Formatting is enforced: `alejandra --check` is a flake check, so unformatted
`.nix` files fail CI. Run `nix fmt` before finishing.

## Architecture

### `default.nix` is the registry

`default.nix` is a plain function from a Nixpkgs instance to the package set. It
is the single source of truth: `flake.nix` derives both `overlays.default` and
`packages.<system>` from it, so those two can never list different packages. A
file in `pkgs/` is invisible until it is added there.

The overlay applies `default.nix` to `final`, not `prev`, so a package's own
dependencies resolve against the overlaid set.

### Package shape

Both current packages follow the same pattern, and a new one of this kind should
match it rather than inventing a shape:

- `stdenvNoCC.mkDerivation (finalAttrs: { ... })` — the `finalAttrs` form so the
  `src` URL can interpolate `finalAttrs.version`, which is what lets
  `nix-update` rewrite the version in one place.
- `src = fetchurl` pointing at a tagged path in the upstream repo.
- `dontUnpack = true`, with an `installPhase` that installs the artifact and
  wraps it via `makeWrapper`.
- `meta.mainProgram` set, since the binary name rarely matches `pname`.

### PHAR packaging gotchas

Both packages wrap a laravel-zero PHAR, and each hit a different sharp edge
worth knowing before packaging a third:

- **Writes beside the PHAR.** `laravel-lsp` hardwires its log directory to
  `dirname(Phar::running())` and aborts on boot from a read-only store. It is
  worked around by extracting the PHAR at build time and running the plain
  entrypoint, which makes `Phar::running()` false. `laravel-cloud-cli` needs
  none of this — it keeps state in `~/.config/cloud` — so it runs as a PHAR.
  Check which case a new package is in before copying either one.
- **Completion command names.** Symfony derives the completion command name from
  `basename(argv[0])`, so `laravel-cloud-cli` installs its PHAR as `cloud`
  rather than `cloud.phar`. A `.phar` suffix silently produces completions bound
  to the wrong command.
- **Banner on stdout.** `cloud completions <shell> --print` prefixes a Laravel
  Prompts banner whenever stdout is not a TTY, which it never is during a build.
  It is stripped with `sed -n '/^#/,$p'`.

## Adding a package

1. Create `pkgs/<name>.nix`.
2. Register it in `default.nix`.
3. Add a row to the README's Packages table.
4. Run `nix fmt` and `nix flake check`.

## Consumers

`mpriscella/dotfiles` consumes `overlays.default` in both its nix-darwin and
standalone Home Manager paths, so its packages appear as `pkgs.laravel-lsp` and
`pkgs.laravel-cloud-cli` in `home-manager/modules/php.nix`. A breaking change
here surfaces in that repo's `nix flake check`.
