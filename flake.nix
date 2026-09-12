{
  description = "Custom Nix packages maintained by mpriscella.";

  inputs = {
    nixpkgs = {
      url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    };
  };

  outputs = {...} @ inputs: let
    # The systems supported for this flake's outputs.
    supportedSystems = [
      "x86_64-linux" # 64-bit Intel/AMD Linux.
      "aarch64-linux" # 64-bit ARM Linux.
      "x86_64-darwin" # 64-bit Intel macOS.
      "aarch64-darwin" # 64-bit ARM macOS.
    ];

    forEachSupportedSystem = f:
      inputs.nixpkgs.lib.genAttrs supportedSystems (
        system:
          f {
            # Provides a system-specific, configured Nixpkgs.
            pkgs = import inputs.nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
          }
      );
  in {
    # The default formatter for this flake.
    formatter = forEachSupportedSystem (
      {pkgs}: pkgs.alejandra
    );

    # Merges every package here into a consumer's own Nixpkgs, so they resolve
    # as `pkgs.laravel-lsp` and `pkgs.laravel-cloud-cli` alongside the rest of
    # the package set. `default.nix` is applied to `final` rather than `prev` so
    # the packages' own dependencies also resolve against the overlaid set.
    overlays.default = final: _prev: import ./. final;

    packages = forEachSupportedSystem (
      {pkgs}: import ./. pkgs
    );

    devShells = forEachSupportedSystem (
      {pkgs}: {
        default = pkgs.mkShell {
          # The Nix packages provided in the environment.
          packages = [
            # Finds a package's latest GitHub release and rewrites its version
            # and src hash in place: `nix-update --flake laravel-cloud-cli`.
            pkgs.nix-update
          ];
        };
      }
    );

    # Default checks for this flake. Building every package is the substance of
    # the check — these are thin fetch-and-wrap derivations, so a green build
    # means the upstream artifact still exists and still hashes as pinned.
    checks = forEachSupportedSystem (
      {pkgs}:
        (import ./. pkgs)
        // {
          # Format check using alejandra.
          format = pkgs.runCommand "check-format" {} ''
            ${pkgs.alejandra}/bin/alejandra --check ${./.}
            touch $out
          '';
        }
    );
  };
}
