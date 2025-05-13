{
  lib,
  pkgs,
  config,
  options,
  modulesPath,
  ...
}:
let
  settingsFormat = pkgs.formats.toml { };
in
{
  _class = "treefmtConfig";

  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = lib.getName config.package + "-with-config";
      defaultText = lib.literalExpression "\"\${getName package}-with-config\"";
      description = ''
        Name to use for the wrapped treefmt package.
      '';
    };

    runtimeInputs = lib.mkOption {
      type = with lib.types; listOf package;
      default = [ ];
      description = ''
        Packages to include on treefmt's PATH.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submoduleWith {
        specialArgs = { inherit modulesPath; };
        modules = [
          { freeformType = settingsFormat.type; }
        ];
      };
      default = { };
      description = ''
        Settings used to build a treefmt config file.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      # Ensure file is copied to the store
      apply = file: if lib.isDerivation file then file else "${file}";
      default = settingsFormat.generate "treefmt.toml" config.settings;
      defaultText = lib.literalMD "generated from [](#opt-treefmt-settings)";
      description = ''
        The treefmt config file.
      '';
    };

    package = lib.mkOption {
      type = lib.types.package;
      defaultText = lib.literalExpression "pkgs.treefmt";
      description = ''
        The treefmt package to wrap.
      '';
      internal = true;
    };

    result = lib.mkOption {
      type = lib.types.package;
      description = ''
        The wrapped treefmt package.
      '';
      readOnly = true;
      internal = true;
    };
  };

  config = {
    result =
      pkgs.runCommand config.name
        {
          nativeBuildInputs = [ pkgs.makeBinaryWrapper ];
          env = {
            inherit (config) configFile;
            binPath = lib.makeBinPath config.runtimeInputs;
          };
          passthru = {
            inherit (config) runtimeInputs;
            inherit config options;
          };
          inherit (config.package) meta version;
        }
        ''
          mkdir -p $out/bin
          makeWrapper \
            ${lib.getExe config.package} \
            $out/bin/treefmt \
            --prefix PATH : "$binPath" \
            --add-flags "--config-file $configFile"
        '';
  };
}
