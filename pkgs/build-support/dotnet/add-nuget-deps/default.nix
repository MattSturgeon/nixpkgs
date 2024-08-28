{ writeShellScript
, runtimeShell
, nix
, lib
, substituteAll
, nuget-to-nix
, cacert
, mkNugetDeps
}:

{ depsFile
, overrideFetchAttrs ? x: {}
}: fnOrAttrs: finalAttrs:
let
  attrs =
    if builtins.isFunction fnOrAttrs
    then fnOrAttrs finalAttrs
    else fnOrAttrs;

  deps = mkNugetDeps {
    name = "${finalPackage.name}-nuget-deps";
    sourceFile = depsFile;
  };

  finalPackage = finalAttrs.finalPackage;

in attrs // {
  buildInputs = attrs.buildInputs or [] ++ [
    deps
  ];

  passthru = attrs.passthru or {} // {
    fetch-deps = let
      pkg' = finalPackage.overrideAttrs (old: {
        buildInputs = lib.remove deps old.buildInputs;
        keepNugetConfig = true;
        dontBuild = true;
        dontInstall = true;
      });

      pkg'' = pkg'.overrideAttrs overrideFetchAttrs;

      drv = builtins.unsafeDiscardOutputDependency pkg''.drvPath;

      innerScript = substituteAll {
        src = ./fetch-deps.sh;
        isExecutable = true;
        inherit cacert;
        defaultDepsFile =
          # Wire in the depsFile such that running the script with no args
          # runs it agains the correct deps file by default.
          # Note that toString is necessary here as it results in the path at
          # eval time (i.e. to the file in your local Nixpkgs checkout) rather
          # than the Nix store path of the path after it's been imported.
          if lib.isPath depsFile
          && !lib.hasPrefix "${builtins.storeDir}/" (toString depsFile) then
            toString depsFile
          else
            ''$(mktemp -t "${finalPackage.name}-deps-XXXXXX.nix")'';
        nugetToNix = nuget-to-nix;
      };

      in writeShellScript "${finalPackage.name}-fetch-deps" ''
        NIX_BUILD_SHELL="${runtimeShell}" exec ${nix}/bin/nix-shell \
          --pure --run 'source "${innerScript}"' "${drv}"
      '';
  };
}
