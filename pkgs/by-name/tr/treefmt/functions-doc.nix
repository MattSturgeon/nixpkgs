{
  nixdoc,
  runCommand,
}:
{
  markdown =
    runCommand "treefmt-functions-doc"
      {
        nativeBuildInputs = [
          nixdoc
        ];
      }
      ''
        nixdoc --file ${./functions.nix} \
          --description "Functions Reference" \
          --prefix "pkgs" \
          --category "treefmt" \
           > $out
      '';
}
