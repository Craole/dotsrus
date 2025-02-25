{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default";
    rust.url = "github:oxalica/rust-overlay";
  };

  outputs =
    {
      nixpkgs,
      systems,
      rust,
      ...
    }:
    let
      inherit (builtins)
        attrNames
        dirOf
        elem
        filter
        head
        isList
        map
        pathExists
        readDir
        tail
        toPath
        ;

      pathOf =
        {
          base ? ./.,
          direction ? "both",
          items,
        }:
        let
          #| Ensure the base is a valid path
          basePath = toPath base;

          #| Ensure items is a list
          itemList = if isList items then items else [ items ];

          #| Function to find the first existing item in the directory
          findItem =
            dir:
            let
              existingItems = filter (item: pathExists (dir + ("/" + item))) itemList;
            in
            if existingItems == [ ] then null else dir + ("/" + head existingItems);

          #| Function to get parent directory
          dirAbove =
            dir:
            let
              parent = dirOf dir;
            in
            if parent == dir then null else parent;

          #| Function to get subdirectories
          dirBelow =
            dir:
            let
              dirContents = readDir dir;
            in
            map (name: dir + ("/" + name)) (
              filter (name: dirContents.${name} == "directory") (attrNames dirContents)
            );

          #| Generic search function
          search =
            dir: getNext:
            let
              foundItem = findItem dir;
            in
            if foundItem != null then
              foundItem
            else
              let
                next = getNext dir;
              in
              if next == null then
                null
              else if isList next then
                searchList next getNext
              else
                search next getNext;

          #| Helper function to search a list of directories
          searchList =
            dirs: getNext:
            if dirs == [ ] then
              null
            else
              let
                result = search (head dirs) getNext;
              in
              if result != null then result else searchList (tail dirs) getNext;

          #| Function to get next directory based on search direction
          getNext = if direction == "up" then dirAbove else dirBelow;
        in
        assert
          elem direction [
            "up"
            "down"
            "both"
          ]
          || throw "Invalid direction: must be 'up' or 'down'";
        # If direction is not specified, search in both directions
        if direction == "both" then
          let
            downSearch = search basePath dirBelow;
            upSearch = search basePath dirAbove;
          in
          if downSearch != null then downSearch else upSearch
        else
          search basePath getNext;

      configPath = dirOf (pathOf {
        items = "init.sh";
      });

      toolchainPath = pathOf {
        items = [
          "toolchain.toml"
          "toolchain"
          "rust-toolchain"
          "rust-toolchain.toml"
        ];
      };

      perSystem =
        f:
        nixpkgs.lib.genAttrs (import systems) (
          system:
          f {
            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                (import rust)
                (self: super: { toolchain = super.rust-bin.fromRustupToolchainFile toolchainPath; })
              ];
            };
          }
        );
    in
    {
      devShells = perSystem (
        { pkgs }:
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              #| Core
              toolchain
              cargo-watch
              cargo-edit
              cargo-generate

              #| Dependencies
              openssl
              pkg-config

              #| Utilities
              bat
              dust
              eza
              lsd
              fd
              helix
              just
              pls
              ripgrep
              tokei
              trashy
              treefmt

              #| Shell Tools
              fastfetch
              starship
              direnv
              yazi
              thefuck
              zoxide

              #| Formatters
              mdformat
              shellcheck
              shfmt
              taplo
              yamlfmt
            ];

            shellHook = ''
              . ${configPath}/init.sh
            '';
          };
        }
      );
    };
}
