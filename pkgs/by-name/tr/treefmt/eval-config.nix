{
  lib,
  pkgs,
  treefmt,
}:

/**
  Evaluate a treefmt configuration.

  # Type

  ```
  Module -> Configuration
  ```

  # Inputs

  `module`
  : A treefmt module. See [options reference].

  [options reference]: https://nixos.org/manual/nixpkgs/unstable#sec-treefmt-options-reference
*/
module:
lib.evalModules {
  class = "treefmtConfig";
  specialArgs.modulesPath = ./modules;
  modules = [
    {
      _file = "treefmt.evalConfig";
      _module.args.pkgs = lib.mkOptionDefault pkgs;
      package = lib.mkOptionDefault treefmt;
    }
    {
      _file = "<treefmt.evalConfig args>";
      imports = lib.toList module;
    }
    ./modules/default.nix
  ];
}
