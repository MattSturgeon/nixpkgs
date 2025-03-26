{ lib }:
let
  inherit (builtins)
    addErrorContext
    isAttrs
    isList
    typeOf
    ;

  inherit (lib.lists)
    foldl
    ;

  inherit (lib.tables)
    isTable
    mergeTables
    mkTable
    toTable
    ;
in

{
  /**
    Produce a table consisting of `list` and `attrs` components.


    # Inputs

    Takes an attribute set with the following attributes

    `list` (List; optional, default `[ ]`)
    :   List items to include in the table.

    `attrs` (AttrSet; optional, default `{ }`)
    :   Attributes to include in the table.

    # Type

    ```
    mkTable :: {
      list :: List ? [ ],
      attrs :: AttrSet ? { },
    } -> Table
    ```

    # Examples
    :::{.example}

    ```nix
    mkTable { }
    => {
      _type = "table";
      list = [ ];
      attrs = { };
    }
    ```

    ```nix
    mkTable {
      list = [ "a" "b" "c" ];
    }
    => {
      _type = "table";
      list = [ "a" "b" "c" ];
      attrs = { };
    }
    ```

    ```nix
    mkTable {
      attrs = { a = "b"; c = "d"; };
    }
    => {
      _type = "table";
      list = [ ];
      attrs = { a = "b"; c = "d"; };
    }
    ```

    ```nix
    mkTable {
      list = [ 1 2 3 ];
      attrs = { a = b; c = d; };
    }
    => {
      _type = table;
      list = [ 1 2 3 ];
      attrs = { a = b; c = d; };
    }
    ```

    :::
  */
  mkTable =
    {
      list ? [ ],
      attrs ? { },
    }:
    {
      _type = "table";
      inherit list attrs;
    };

  /**
    Check whether the argument is a table.
    Any set with `{ _type = "table"; }` counts as a table.


    # Inputs

    `value`

    : Value to check.

    # Type

    ```
    isTable :: Any -> Bool
    ```

    # Examples
    :::{.example}

    ```nix
    isTable (mkTable { })
    => true
    ```

    ```nix
    isTable "foobar"
    => false
    ```

    :::
  */
  isTable = value: value._type or null == "table";

  /**
    If argument is a table, return it; else, wrap it using `mkTable`.


    # Inputs

    `x` (Table, AttrSet, or List)
    :   value to normalise as a table.

    # Outputs

    A table representing the input value `x`.

    # Type

    ```
    toTable :: (Table | AttrSet | List) -> Table
    ```

    # Examples
    :::{.example}

    ```nix
    toTable [ 1 2 ]
    => {
      _type = "table";
      list = [ 1 2 ];
      attrs = { };
    }
    ```

    ```nix
    toTable { a = "b"; c = "d"; }
    => {
      _type = "table";
      list = [ ];
      attrs = { a = "b"; c = "d"; };
    }
    ```

    ```nix
    toTable {
      _type = "table";
      list = [ 1 2 3 ];
      attrs = { a = "b"; c = "d"; };
    }
    => {
      _type = "table";
      list = [ 1 2 3 ];
      attrs = { a = "b"; c = "d"; };
    }
    ```

    :::
  */
  toTable =
    x:
    if isTable x then
      x
    else if isAttrs x then
      mkTable { attrs = x; }
    else if isList x then
      mkTable { list = x; }
    else
      throw "Unexpected ${typeOf x} used with `toTable`";

  /**
    Merge two tables, or values convertible with `toTable`.
    Lists will be concatenated using `++` and AttrSets will be updated using `//`.


    # Inputs

    `left` (Table, AttrSet, or List)
    :   left hand side of the operation.

    `right` (Table, AttrSet, or List)
    :   right hand side of the operation.

    # Type

    ```
    mergeTables :: (Table | AttrSet | List) -> (Table | AttrSet | List) -> Table
    ```

    # Examples
    :::{.example}

    ```nix
    mergeTables [ 1 2 ] { a = "b"; }
    => {
      _type = "table";
      list = [ 1 2 ];
      attrs = { a = "b"; };
    }
    ```

    ```nix
    mergeTables [ 1 2 ] [ 3 4 ]
    => {
      _type = "table";
      list = [ 1 2 3 4 ];
      attrs = { };
    }
    ```

    ```nix
    mergeTables
      {
        _type = "table";
        list = [ 1 2 ];
        attrs = { a = "b"; };
      }
      {
        _type = "table";
        list = [ 3 4 ];
        attrs = { c = "d"; };
      }
    => {
      _type = "table";
      list = [ 1 2 3 4 ];
      attrs = { a = "b"; c = "d"; };
    }
    ```

    :::
  */
  mergeTables =
    left: right:
    let
      leftTable = addErrorContext "while normalising left table" (toTable left);
      rightTable = addErrorContext "while normalising right table" (toTable right);
    in
    mkTable {
      list = leftTable.list ++ rightTable.list;
      attrs = leftTable.attrs // rightTable.attrs;
    };

  mergeTableList = foldl mergeTables (mkTable { });
}
