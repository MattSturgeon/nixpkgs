{
  _7zz,
  buildDotnetModule,
  copyDesktopItems,
  desktop-file-utils,
  dotnetCorePackages,
  fetchFromGitHub,
  fontconfig,
  lib,
  libICE,
  libSM,
  libX11,
  nexusmods-app,
  runCommand,
  enableUnfree ? false, # Set to true to support RAR format mods
}:
buildDotnetModule rec {
  pname = "nexusmods-app" + lib.optionalString enableUnfree "-unfree";

  version = "0.5.1";

  src = fetchFromGitHub {
    owner = "Nexus-Mods";
    repo = "NexusMods.App";
    rev = "v${version}";
    fetchSubmodules = true;
    hash = "sha256-hHK6cQ0X+slMDtN+UY4HhAJt+WrepKHAECTkkV7gUtk=";
  };

  projectFile = "NexusMods.App.sln";

  nativeBuildInputs = [ copyDesktopItems ];

  nugetDeps = ./deps.nix;

  dotnet-sdk = dotnetCorePackages.sdk_8_0;
  dotnet-runtime = dotnetCorePackages.runtime_8_0;

  preConfigure = ''
    substituteInPlace Directory.Build.props \
      --replace-fail '</PropertyGroup>' '<ErrorOnDuplicatePublishOutputFiles>false</ErrorOnDuplicatePublishOutputFiles></PropertyGroup>'
  '';

  dotnetBuildFlags = [
    # Tell the app it is a distro package; affects wording in update prompts
    "--property:INSTALLATION_METHOD_FLATPAK=1"

    # Don't include upstream's 7zz binary; we use the nixpkgs version
    "--property:NEXUSMODS_APP_USE_SYSTEM_EXTRACTOR=1"
  ];

  makeWrapperArgs = [
    "--prefix PATH : ${lib.makeBinPath [ desktop-file-utils ]}"
    "--set APPIMAGE $out/bin/${meta.mainProgram}" # Make associating with nxm links work on Linux
  ];

  propagatedBuildInputs = [ (_7zz.override { inherit enableUnfree; }) ];

  runtimeDeps = [
    fontconfig
    libICE
    libSM
    libX11
  ];

  executables = [ meta.mainProgram ];

  doCheck = true;

  dotnetTestFlags = [
    "--environment=USER=nobody"
    (lib.strings.concatStrings [
      "--filter="
      (lib.strings.concatStringsSep "&" (
        [
          "Category!=Disabled"
          "FlakeyTest!=True" # Flaky
          "RequiresNetworking!=True" # aka. RequiresNexusModsAPIKey https://github.com/Nexus-Mods/NexusMods.App/issues/1223#issuecomment-2060706341
          "FullyQualifiedName!=NexusMods.UI.Tests.ImageCacheTests.Test_LoadAndCache_ImageStoredFile" # Requires networking
          "FullyQualifiedName!=NexusMods.UI.Tests.ImageCacheTests.Test_LoadAndCache_RemoteImage" # Requires networking
        ]
        ++ lib.optionals (!enableUnfree) [
          "FullyQualifiedName!=NexusMods.Games.FOMOD.Tests.FomodXmlInstallerTests.InstallsFilesSimple_UsingRar"
        ]
      ))
    ])
  ];

  passthru = {
    tests = {
      serve = runCommand "${pname}-test-serve" { } ''
        ${nexusmods-app}/bin/${nexusmods-app.meta.mainProgram}
        touch $out
      '';
      help = runCommand "${pname}-test-help" { } ''
        ${nexusmods-app}/bin/${nexusmods-app.meta.mainProgram} --help
        touch $out
      '';
      associate-nxm = runCommand "${pname}-test-associate-nxm" { } ''
        ${nexusmods-app}/bin/${nexusmods-app.meta.mainProgram} associate-nxm
        touch $out
      '';
      list-tools = runCommand "${pname}-test-list-tools" { } ''
        ${nexusmods-app}/bin/${nexusmods-app.meta.mainProgram} list-tools
        touch $out
      '';
    };
    updateScript = ./update.bash;
  };

  meta = {
    description = "Game mod installer, creator and manager";
    mainProgram = "NexusMods.App";
    homepage = "https://github.com/Nexus-Mods/NexusMods.App";
    changelog = "https://github.com/Nexus-Mods/NexusMods.App/releases/tag/${src.rev}";
    license = [ lib.licenses.gpl3Plus ];
    maintainers = with lib.maintainers; [
      l0b0
      MattSturgeon
    ];
    platforms = lib.platforms.linux;
  };
}
