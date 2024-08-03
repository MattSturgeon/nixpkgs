{
  callPackage,
  autoPatchelfHook,
  fontconfig,
}:
{

  "SkiaSharp.NativeAssets.Linux" =
    package:
    package.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs or [ ] ++ [ autoPatchelfHook ];

      buildInputs = old.buildInputs or [ ] ++ [ fontconfig ];

      preInstall =
        old.preInstall or ""
        + ''
          rm -r runtimes/linux-{arm,arm64,musl-x64}
        '';
    });
}
