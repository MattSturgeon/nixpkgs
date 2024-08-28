{
  stdenvNoCC,
  lib,
  fetchFromGitHub,
  dotnetCorePackages,
  libX11,
  libICE,
  libSM,
  libXcursor,
  libXrandr,
  libXext,
  libXi,
  nodejs,
  addNugetDeps,
  fetchNpmDeps,
  npmHooks,
  prefetch-npm-deps,
  unicode-character-database,
  fetchzip,
  makeFontsConf,
  liberation_ttf,
  fontconfig,
  runCommand,
}:

stdenvNoCC.mkDerivation (
  addNugetDeps
    {
      depsFile = ./deps.nix;
      overrideFetchAttrs = a: {
        dontBuild = false;
        buildTarget = "Compile";
      };
    }
    rec {
      pname = "Avalonia";
      version = "11.0.10";

      src = fetchFromGitHub {
        owner = "AvaloniaUI";
        repo = "Avalonia";
        rev = version;
        fetchSubmodules = true;
        hash = "sha256-OVV15Be/wzgglXgCG0IraDV4MfMtOgWUnEg206/Wsxc=";
      };

      patches = [
        # Fix failing tests that use unicode.org
        ./0001-use-files-for-unicode-character-database.patch
        # [ERR] Compile: [...]/Microsoft.NET.Sdk.targets(148,5): error MSB4018: The "GenerateDepsFile" task failed unexpectedly. [/build/source/src/tools/DevAnalyzers/DevAnalyzers.csproj]
        # [ERR] Compile: [...]/Microsoft.NET.Sdk.targets(148,5): error MSB4018: System.IO.IOException: The process cannot access the file '/build/source/src/tools/DevAnalyzers/bin/Release/netstandard2.0/DevAnalyzers.deps.json' because it is being used by another process. [/build/source/src/tools/DevAnalyzers/DevAnalyzers.csproj]
        ./0002-disable-parallel-compile.patch
      ];

      # this needs to be match the version being patched above
      UNICODE_CHARACTER_DATABASE = fetchzip {
        url = "https://www.unicode.org/Public/15.0.0/ucd/UCD.zip";
        hash = "sha256-jj6bX46VcnH7vpc9GwM9gArG+hSPbOGL6E4SaVd0s60=";
        stripRoot = false;
      };

      postPatch =
        ''
          patchShebangs build.sh

          substituteInPlace src/Avalonia.X11/ICELib.cs \
            --replace-fail '"libICE.so.6"' '"${lib.getLib libICE}/lib/libICE.so.6"'
          substituteInPlace src/Avalonia.X11/SMLib.cs \
            --replace-fail '"libSM.so.6"' '"${lib.getLib libSM}/lib/libSM.so.6"'
          substituteInPlace src/Avalonia.X11/XLib.cs \
            --replace-fail '"libX11.so.6"' '"${lib.getLib libX11}/lib/libX11.so.6"' \
            --replace-fail '"libXrandr.so.2"' '"${lib.getLib libXrandr}/lib/libXrandr.so.2"' \
            --replace-fail '"libXext.so.6"' '"${lib.getLib libXext}/lib/libXext.so.6"' \
            --replace-fail '"libXi.so.6"' '"${lib.getLib libXi}/lib/libXi.so.6"' \
            --replace-fail '"libXcursor.so.1"' '"${lib.getLib libXcursor}/lib/libXcursor.so.1"'

          # from RestoreAdditionalProjectSources, which isn't supported by nuget-to-nix
          dotnet nuget add source https://pkgs.dev.azure.com/dnceng/public/_packaging/dotnet8-transport/nuget/v3/index.json

          # Tricky way to run npmConfigHook multiple times (borrowed from pagefind)
          (
            local postPatchHooks=() # written to by npmConfigHook
            source ${npmHooks.npmConfigHook}/nix-support/setup-hook
        ''
        +
          lib.concatMapStrings
            (
              { path, hash }:
              let
                deps = fetchNpmDeps {
                  src = "${src}/${path}";
                  inherit hash;
                };
              in
              ''
                npmRoot=${path} npmDeps="${deps}" npmConfigHook
                rm -rf "$TMPDIR/cache"
              ''
            )
            [
              {
                path = "src/Avalonia.DesignerSupport/Remote/HtmlTransport/webapp";
                hash = "sha256-gncHW5SMtAUMtvHGZ2nUc0KEjxX24DZkAnmeHgo1Roc=";
              }
              {
                path = "tests/Avalonia.DesignerSupport.Tests/Remote/HtmlTransport/webapp";
                hash = "sha256-MiznlOJ+hIO1cUswy9oGNHP6MWfx+FDLKVT8qcmg8vo=";
              }
              {
                path = "src/Browser/Avalonia.Browser/webapp";
                hash = "sha256-LTQzT4ycLyGQs9T0sa2k/0wfG1GWCdeH9Wx2KeecOyU=";
              }
            ]
        + ''
          )
        '';

      makeCacheWritable = true;

      # CSC : error CS1566: Error reading resource 'pdbstr.exe' -- 'Could not find a part of the path '/build/.nuget-temp/packages/sourcelink/1.1.0/tools/pdbstr.exe'.' [/build/source/nukebuild/_build.csproj]
      linkNugetPackages = true;

      # [WRN] Could not inject value for Build.ApiCompatTool
      # System.Exception: Missing package reference/download.
      # Run one of the following commands:
      #  ---> System.ArgumentException: Could not find package 'Microsoft.DotNet.ApiCompat.Tool' using:
      #  - Project assets file '/build/source/nukebuild/obj/project.assets.json'
      #  - NuGet packages config '/build/source/nukebuild/_build.csproj'
      makeEmptyNupkgInPackages = true;

      buildInputs = [
        (
          with dotnetCorePackages;
          combinePackages [
            sdk_6_0
            sdk_7_0_1xx
          ]
        )
      ];

      FONTCONFIG_FILE =
        let
          fc = makeFontsConf { fontDirectories = [ liberation_ttf ]; };
        in
        runCommand "fonts.conf" { } ''
          substitute ${fc} $out \
            --replace-fail "/etc/" "${fontconfig.out}/etc/"
        '';

      nativeBuildInputs = [ nodejs ];

      buildTarget = "Package";

      buildPhase = ''
        runHook preBuild
        # ValidateApiDiff requires a network connection
        ./build.sh --target $buildTarget --verbosity Verbose --skip ValidateApiDiff
        runHook postBuild
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p "$out/share/nuget/source"
        cp artifacts/nuget/* "$out/share/nuget/source"
        runHook postInstall
      '';
    }
)
