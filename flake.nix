# This file is maintained by @IvanMalison and @LSLeary (github)
# See NIX.md for an overview of module usage.
{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    git-ignore-nix.url = "github:hercules-ci/gitignore.nix/master";
    xmonad.url = "github:xmonad/xmonad";
    devenv = {
      url = "github:cachix/devenv";
    };
  };
  outputs = inputs @ {
    self,
    flake-utils,
    nixpkgs,
    git-ignore-nix,
    xmonad,
    devenv,
  }:
    with xmonad.lib; let
      hoverlay = final: prev: hself: hsuper: {
        xmonad-contrib =
          hself.callCabal2nix "xmonad-contrib"
          (git-ignore-nix.lib.gitignoreSource ./.) {};
      };
      defComp =
        if builtins.pathExists ./comp.nix
        then import ./comp.nix
        else {};
      overlay = fromHOL hoverlay defComp;
      overlays = [overlay (fromHOL xmonad.hoverlay defComp)];
      nixosModule = {
        config,
        lib,
        ...
      }:
        with lib; let
          cfg = config.services.xserver.windowManager.xmonad;
          comp = {inherit (cfg.flake) prefix compiler;};
        in {
          config = mkIf (cfg.flake.enable && cfg.enableContribAndExtras) {
            nixpkgs.overlays = [(fromHOL hoverlay comp)];
          };
        };
      nixosModules = [nixosModule] ++ xmonad.nixosModules;
    in
      flake-utils.lib.eachDefaultSystem (system: let
        pkgs = import nixpkgs {inherit system overlays;};
        hpkg = pkgs.lib.attrsets.getAttrFromPath (hpath defComp) pkgs;
      in rec {
        devShell = devenv.lib.mkShell {
          inherit inputs pkgs;
          modules = [
            ({
              pkgs,
              lib,
              ...
            }: let
              libs = with pkgs; [
                xorg.libxcb
                xorg.libXrender
                xorg.libXrandr
                xorg.libX11
                xorg.libXScrnSaver
                xorg.libXext
              ];
            in {
              # This is your devenv configuration
              packages = let
                cabal = lib.getExe pkgs.haskellPackages.cabal-install;
              in
                [
                  (pkgs.writers.writeDashBin "clean" "${cabal} clean")
                  (pkgs.writers.writeDashBin "clean-build" "${cabal} clean && ${cabal} build")
                ]
                ++ libs;

              env.LD_LIBRARY_PATH = lib.makeLibraryPath libs;

              languages.haskell = {
                enable = true;
              };
            })
          ];
        };
        defaultPackage = hpkg.xmonad-contrib;
        modernise = xmonad.modernise.${system};
      })
      // {inherit hoverlay overlay overlays nixosModule nixosModules;};
}
