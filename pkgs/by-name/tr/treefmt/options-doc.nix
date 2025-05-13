# To build this derivation, run `nix-build -A treefmt.optionsDoc`
{
  lib,
  treefmt,
  nixosOptionsDoc,
}:

let
  configuration = treefmt.evalConfig [ ];

  root = toString configuration._module.specialArgs.modulesPath;

  transformDeclaration =
    decl:
    let
      declStr = toString decl;
      subpath = "pkgs/by-name/tr/treefmt/modules/" + lib.removePrefix "/" (lib.removePrefix root declStr);
    in
    assert lib.hasPrefix root declStr;
    {
      url = "https://github.com/NixOS/nixpkgs/blob/master/${subpath}";
      name = subpath;
    };
in
nixosOptionsDoc {
  documentType = "none";
  options = builtins.removeAttrs configuration.options [ "_module" ];
  transformOptions = opt: opt // { declarations = map transformDeclaration opt.declarations; };
}
