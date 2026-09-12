# Nix Packages

Custom Nix packages that aren't in nixpkgs. Kept in a standalone flake whose
only input is `nixpkgs`, so adding it costs a consumer nothing beyond this
repo itself.

## Packages

| Package             | Binary        | Description                                   |
| ------------------- | ------------- | --------------------------------------------- |
| `laravel-cloud-cli` | `cloud`       | CLI for Laravel Cloud (prebuilt PHAR)         |
| `laravel-lsp`       | `laravel-lsp` | Official Laravel language server (prebuilt PHAR) |

Both are `laravel-zero` applications distributed upstream as self-contained
[Box](https://box-project.github.io/box/) PHARs committed to their repos. They
are fetched and wrapped with a PHP interpreter rather than rebuilt from source,
which would require Box plus a full Composer install.

## Usage

Run one without installing anything:

```shell
nix run github:mpriscella/nix-packages#laravel-cloud-cli -- --version
```

### As an overlay

The ergonomic option when a project wants more than one of these — the packages
land in your own `pkgs` alongside everything else. The `follows` line is what
keeps your lock file from gaining a second nixpkgs.

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-packages = {
      url = "github:mpriscella/nix-packages";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {nixpkgs, nix-packages, ...}: let
    system = "aarch64-darwin";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [nix-packages.overlays.default];
    };
  in {
    devShells.${system}.default = pkgs.mkShell {
      packages = [pkgs.php85 pkgs.laravel-cloud-cli pkgs.laravel-lsp];
    };
  };
}
```

### As a direct package reference

Less machinery when only one package is wanted:

```nix
packages = [nix-packages.packages.${system}.laravel-cloud-cli];
```

### In a NixOS / nix-darwin / Home Manager config

Add the overlay once and the packages become ordinary attributes:

```nix
nixpkgs.overlays = [nix-packages.overlays.default];
environment.systemPackages = [pkgs.laravel-cloud-cli];
```

## Development

```shell
nix flake check          # Format check plus a build of every package
nix fmt                  # Format all .nix files (alejandra)
nix build .#<package>    # Build one package in isolation
nix develop              # Dev shell, provides nix-update
```

To bump a package to its latest upstream release:

```shell
nix develop
nix-update --flake <package>   # rewrites version and src hash in place
nix build .#<package>          # verify
```

## Caveats

Neither package's bundled self-updater can work — `cloud self-update` rewrites
its own PHAR, and the Nix store is read-only. Bump the pinned `version` here
instead.
