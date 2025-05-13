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
  : A treefmt module, configuring options that include:
    - `name`: `String` (default `"treefmt-with-config"`)
    - `settings`: `Module` (default `{ }`)
    - `runtimeInputs`: `[Derivation]` (default `[ ]`)
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
