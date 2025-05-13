{
  lib,
  buildGoModule,
  callPackage,
  callPackages,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "treefmt";
  version = "2.2.1";

  src = fetchFromGitHub {
    owner = "numtide";
    repo = "treefmt";
    rev = "v${version}";
    hash = "sha256-gNGDqCRPvXjbfDQkEP8UsEStL9fsvUVYWPv3d8o1Bq0=";
  };

  vendorHash = "sha256-47yOjk3eO5K0T01GUDvheJxoAJz0ZmiV2RdqTv01pYQ=";

  subPackages = [ "." ];

  env.CGO_ENABLED = 1;

  ldflags = [
    "-s"
    "-w"
    "-X github.com/numtide/treefmt/v2/build.Name=treefmt"
    "-X github.com/numtide/treefmt/v2/build.Version=v${version}"
  ];

  passthru = {
    # Utility functions and wrappers
    withConfig = callPackage ./with-config.nix { };
    evalConfig = callPackage ./eval-config.nix { };
    buildConfig = callPackage ./build-config.nix { };

    tests = callPackages ./tests.nix { };

    # Documentation for options declared in `treefmt.evalConfig` configurations
    optionsDoc = callPackages ./options-doc.nix { };
  };

  meta = {
    description = "one CLI to format the code tree";
    homepage = "https://github.com/numtide/treefmt";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      brianmcgee
      MattSturgeon
      zimbatm
    ];
    mainProgram = "treefmt";
  };
}
