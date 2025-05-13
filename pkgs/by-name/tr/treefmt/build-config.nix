{
  lib,
  treefmt,
}:

/**
  Build a treefmt config file from structured settings.

  # Type

  ```
  Module -> Derivation
  ```

  # Inputs

  `settings`
  : A settings module, used to build a treefmt config file
*/
module:
let
  configuration = treefmt.evalConfig {
    _file = "<treefmt.buildConfig args>";
    settings.imports = lib.toList module;
  };
in
configuration.config.configFile.overrideAttrs {
  passthru = {
    inherit (configuration.config) settings;
    options = (opt: opt.type.getSubOptions opt.loc) configuration.options.settings;
  };
}
