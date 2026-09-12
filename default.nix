# The package set, expressed as a plain function of a Nixpkgs instance rather
# than as flake outputs. `overlays.default` and `packages.<system>` in flake.nix
# are both built from this one attribute set, so the two can never drift, and
# non-flake consumers can `import` this file directly.
pkgs: {
  laravel-cloud-cli = pkgs.callPackage ./pkgs/laravel-cloud-cli.nix {};
  laravel-lsp = pkgs.callPackage ./pkgs/laravel-lsp.nix {};
}
