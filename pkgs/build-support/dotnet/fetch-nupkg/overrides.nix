{
  autoPatchelfHook,
  dotnetCorePackages,
  dos2unix,
  fetchpatch,
  fontconfig,
  lib,
  libICE,
  libSM,
  libX11,
  stdenv,
  writeText,
}:
{
  # e.g.
  # "Package.Id" =
  #   package:
  #   package.overrideAttrs (old: {
  #     buildInputs = old.buildInputs or [ ] ++ [ hello ];
  #   });

  "Avalonia" =
    package:
    package.overrideAttrs (
      old:
      let
        inherit (old) version;
      in
      # Versions between 11.1.0 and 11.2.0-beta1 (inclusive) need #16835
      lib.optionalAttrs
        (
          builtins.compareVersions version "11.1.0" >= 0
          && (lib.versionOlder version "11.2.0" || version == "11.2.0-beta1")
        )
        {
          patches = [
            (fetchpatch {
              url = "https://github.com/AvaloniaUI/Avalonia/pull/16835.patch";
              hash = "sha256-gJkCOHbfsydlgjavTgVNhOSUVQ79TEr6h4ETunAZWuw=";
            })
          ];

          patchFlags = [
            "--ignore-whitespace"
            "--strip=3"
          ];

          prePatch = ''
            cd build
            dos2unix AvaloniaBuildTasks.targets
          '';

          postPatch = ''
            unix2dos AvaloniaBuildTasks.targets
            cd ..
          '';

          nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [
            dos2unix
          ];
        }
    );

  "Avalonia.X11" =
    package:
    package.overrideAttrs (
      old:
      lib.optionalAttrs (!stdenv.isDarwin) {
        setupHook = writeText "setupHook.sh" ''
          prependToVar dotnetRuntimeDeps \
            "${lib.getLib libICE}" \
            "${lib.getLib libSM}" \
            "${lib.getLib libX11}"
        '';
      }
    );

  "SkiaSharp.NativeAssets.Linux" =
    package:
    package.overrideAttrs (
      old:
      lib.optionalAttrs stdenv.isLinux {
        nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ autoPatchelfHook ];

        buildInputs = old.buildInputs or [ ] ++ [ fontconfig ];

        preInstall =
          old.preInstall or ""
          + ''
            cd runtimes
            for platform in *; do
              [[ $platform == "${dotnetCorePackages.systemToDotnetRid stdenv.hostPlatform.system}" ]] ||
                rm -r "$platform"
            done
            cd - >/dev/null
          '';
      }
    );
}
