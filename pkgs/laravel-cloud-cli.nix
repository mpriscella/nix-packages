# Registered in ../default.nix, which backs both `overlays.default` and
# `packages.<system>.laravel-cloud-cli`. To update: run
# `nix-update --flake laravel-cloud-cli` (available in the dev shell) — it finds
# the latest GitHub release and refreshes version and src hash. Verify with
# `nix build .#laravel-cloud-cli`.
{
  lib,
  stdenvNoCC,
  fetchurl,
  php,
  makeWrapper,
  installShellFiles,
}:
# Laravel Cloud CLI (https://github.com/laravel/cloud-cli) — `cloud`. Manages
# Laravel Cloud applications, environments, deployments, databases, buckets and
# secrets from the terminal.
#
# Upstream publishes it on Packagist as `laravel/cloud-cli` with a single
# `builds/cloud` bin: a self-contained box PHAR (bundles `vendor`) committed to
# the repo. We fetch that prebuilt PHAR rather than rebuilding from source
# (which would need box + a full composer install). The only runtime
# requirement is a PHP >= 8.3 interpreter with ext-sodium (used to seal
# secrets); nixpkgs' default PHP build has sodium.
#
# Unlike laravel-lsp — the other laravel-zero PHAR packaged here — this one
# needs no read-only-store workarounds: it never writes beside the PHAR. State
# (auth token, current org/app) lives in `~/.config/cloud`, so the PHAR runs
# as-is instead of being extracted.
#
# Caveat: the bundled `cloud self-update` cannot work, since it rewrites the
# PHAR in place and the store is read-only. Bump `version` here instead.
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "laravel-cloud-cli";
  version = "0.6.0";

  src = fetchurl {
    url = "https://raw.githubusercontent.com/laravel/cloud-cli/v${finalAttrs.version}/builds/cloud";
    hash = "sha256-KntcMr4zQwh3P9n72DYKL+Kr/jk8HWFWzZWHpPJoX4U=";
  };

  dontUnpack = true;

  nativeBuildInputs = [makeWrapper installShellFiles];

  installPhase = ''
    runHook preInstall

    # Installed without a .phar suffix on purpose: Symfony derives the
    # completion command name from basename(argv[0]), so a cloud.phar here
    # would emit completions bound to `cloud.phar` rather than `cloud`.
    install -Dm444 $src $out/share/laravel-cloud-cli/cloud

    makeWrapper ${lib.getExe php} $out/bin/cloud \
      --add-flags $out/share/laravel-cloud-cli/cloud

    runHook postInstall
  '';

  # Symfony's completion scripts shell out to `cloud _complete` at runtime, so
  # they only need generating once. HOME is set because the app resolves its
  # config dir from it on boot, before the (auth-exempt) command runs. The sed
  # drops the Laravel Prompts "Shell Completion Setup" banner, which the
  # command prints ahead of the script whenever stdout is not a TTY.
  postInstall = ''
    export HOME=$TMPDIR
    for shell in bash zsh fish; do
      $out/bin/cloud completions $shell --print \
        | sed -n '/^#/,$p' > cloud.$shell
      installShellCompletion --cmd cloud --$shell cloud.$shell
    done
  '';

  meta = {
    description = "CLI to interact with Laravel Cloud (prebuilt PHAR)";
    homepage = "https://github.com/laravel/cloud-cli";
    license = lib.licenses.mit;
    mainProgram = "cloud";
  };
})
