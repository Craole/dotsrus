{
  pkgs,
  toolchain,
  ...
}: {
  default = pkgs.mkShell {
    packages = with pkgs; [
      # Core
      # toolchain
      cargo-watch
      cargo-edit
      cargo-generate

      # Dependencies
      openssl
      pkg-config

      # Tools
      dust
      eza
      pls
      fd
      helix
      helix-gpt
      ripgrep
      just
      direnv
      treefmt
      tokei

      # Formatters
      mdformat
      nodePackages.prettier
      shellcheck
      shfmt
      taplo
      yamlfmt
    ];

    shellHook = ''
      [ -f ./init ] && . ./init
    '';
  };
}
