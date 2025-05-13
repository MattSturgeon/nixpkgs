{
  lib,
  treefmt,
}:

/**
  Wrap treefmt, configured using structured settings.

  # Type

  ```
  Module -> Derivation
  ```

  # Inputs

  `module`
  : A treefmt module, configuring options that include:
    - `name`: `String` (default `"treefmt-with-config"`)
    - `settings`: `Module` (default `{ }`)
    - `runtimeInputs`: `[Derivation]` (default `[ ]`)
*/
module:
let
  configuration = treefmt.evalConfig {
    _file = "<treefmt.withConfig args>";
    imports = lib.toList module;
  };
in
configuration.config.result
