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
  : A treefmt module. See [options reference].

  [options reference]: https://nixos.org/manual/nixpkgs/unstable#sec-treefmt-options-reference
*/
module:
let
  configuration = treefmt.evalConfig {
    _file = "<treefmt.withConfig args>";
    imports = lib.toList module;
  };
in
configuration.config.result
