{
  _7zz,
  buildDotnetModule,
  copyDesktopItems,
  desktop-file-utils,
  dos2unix,
  dotnetCorePackages,
  fetchFromGitHub,
  fontconfig,
  lib,
  runCommand,
  xdg-utils,
  pname ? "nexusmods-app",
}:
let
  # From https://nexus-mods.github.io/NexusMods.App/developers/Contributing/#for-package-maintainers
  constants = [
    # Tell the app it is a distro package; affects wording in update prompts
    "INSTALLATION_METHOD_PACKAGE_MANAGER"

    # Don't include upstream's 7zz binary; we use the nixpkgs version
    "NEXUSMODS_APP_USE_SYSTEM_EXTRACTOR"
  ];
in
buildDotnetModule (finalAttrs: {
  inherit pname;
  version = "0.5.3";

  src = fetchFromGitHub {
    owner = "Nexus-Mods";
    repo = "NexusMods.App";
    rev = "v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-vy7gc/pS29gphkWM/KezZxXDVsD5DV02b/72pPh2Y2c=";
  };

  patches = [
    # Backport fix for NEXUSMODS_APP_USE_SYSTEM_EXTRACTOR
    # From https://github.com/Nexus-Mods/NexusMods.App/pull/1919
    ./0001-Fixed-Alias-USE_SYSTEM_EXTRACTOR-and-NEXUSMODS_APP_U.patch
    ./0002-Fixed-Consider-additional-possible-system-7z-binarie.patch
    ./0003-Removed-Alias-for-USE_SYSTEM_EXTRACTOR.patch
  ];

  enableParallelBuilding = false;

  # If the whole solution is published, there seems to be a race condition where
  # it will sometimes publish the wrong version of a dependent assembly, for
  # example: Microsoft.Extensions.Hosting.dll 6.0.0 instead of 8.0.0.
  # https://learn.microsoft.com/en-us/dotnet/core/compatibility/sdk/7.0/solution-level-output-no-longer-valid
  # TODO: do something about this in buildDotnetModule
  projectFile = "src/NexusMods.App/NexusMods.App.csproj";
  testProjectFile = "NexusMods.App.sln";

  nativeCheckInputs = [ _7zz ];

  nativeBuildInputs = [
    copyDesktopItems
    # FIXME: is this needed?
    finalAttrs.dotnet-sdk.icu
    # TODO: Remove when patch isn't needed
    dos2unix
  ];

  nugetDeps = ./deps.nix;

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;

  prePatch = ''
    # TODO: Remove when patch isn't needed
    dos2unix src/ArchiveManagement/NexusMods.FileExtractor/build/NexusMods.FileExtractor.targets
  '';

  postPatch = ''
    # TODO: Remove when patch isn't needed
    unix2dos src/ArchiveManagement/NexusMods.FileExtractor/build/NexusMods.FileExtractor.targets

    # for some reason these tests fail (intermittently?) with a zero timestamp
    touch tests/NexusMods.UI.Tests/WorkspaceSystem/*.verified.png
  '';

  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath finalAttrs.runtimeInputs}"
    # Make associating with nxm links work on Linux
    # FIXME: this may no longer be needed, testing without it
    # "--set APPIMAGE ${placeholder "out"}/bin/NexusMods.App"
  ];

  runtimeInputs = [
    _7zz
    desktop-file-utils
    xdg-utils
  ];

  executables = [ "NexusMods.App" ];

  # FIXME: should some of these go in dotnetTestFlags and/or dotnetFlags?
  dotnetBuildFlags = [
    # From https://github.com/Nexus-Mods/NexusMods.App/blob/v0.5.3/src/NexusMods.App/app.pupnet.conf#L38
    "--property:Version=${finalAttrs.version}"
    "--property:TieredCompilation=true"
    "--property:PublishReadyToRun=true"
    "--property:DefineConstants=${lib.strings.concatStringsSep "%3B" constants}"
  ];

  doCheck = true;

  dotnetTestFlags = [
    "--environment=USER=nobody"
    "--property:DefineConstants=${lib.strings.concatStringsSep "%3B" constants}"
  ];

  testFilters = [
    "Category!=Disabled"
    "FlakeyTest!=True"
    "RequiresNetworking!=True"
  ];

  disabledTests =
    [
      "NexusMods.UI.Tests.ImageCacheTests.Test_LoadAndCache_RemoteImage"
      "NexusMods.UI.Tests.ImageCacheTests.Test_LoadAndCache_ImageStoredFile"
    ]
    ++ lib.optionals (!_7zz.meta.unfree) [
      "NexusMods.Games.FOMOD.Tests.FomodXmlInstallerTests.InstallsFilesSimple_UsingRar"
    ];

  passthru = {
    tests =
      let
        runTest =
          name: script:
          runCommand "${pname}-test-${name}" { nativeBuildInputs = [ finalAttrs.finalPackage ]; } ''
            ${script}
            touch $out
          '';
      in
      {
        serve = runTest "serve" ''
          NexusMods.App
        '';
        help = runTest "help" ''
          NexusMods.App --help
        '';
        associate-nxm = runTest "associate-nxm" ''
          NexusMods.App associate-nxm
        '';
        list-tools = runTest "list-tools" ''
          NexusMods.App list-tools
        '';
      };
    updateScript = ./update.bash;
  };

  meta = {
    mainProgram = "NexusMods.App";
    homepage = "https://github.com/Nexus-Mods/NexusMods.App";
    changelog = "https://github.com/Nexus-Mods/NexusMods.App/releases/tag/${finalAttrs.src.rev}";
    license = [ lib.licenses.gpl3Plus ];
    maintainers = with lib.maintainers; [
      l0b0
      MattSturgeon
    ];
    platforms = lib.platforms.linux;
    description = "Game mod installer, creator and manager";
    longDescription = ''
      A mod installer, creator and manager for all your popular games.

      Currently experimental and undergoing active development,
      new releases may include breaking changes!

      ${
        if _7zz.meta.unfree then
          ''
            This "unfree" variant includes support for mods packaged as RAR archives.
          ''
        else
          ''
            It is strongly recommended that you use the "unfree" variant of this package,
            which provides support for mods packaged as RAR archives.

            You can also enable unrar support manually, by overriding the `_7zz` used:

            ```nix
            pkgs.nexusmods-app.override {
              _7zz = pkgs._7zz-rar;
            }
            ```
          ''
      }
    '';
  };
})
