{
  description = "swissdd's vote-json transforms, without the http fetching";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-darwin" ];
      # nixpkgs bug: ps and processx install unstripped helper binaries under
      # library/*/bin, whose debug_info keeps a gcc store path and trips the R
      # builder's disallowedReferences check.
      stripBin = pkgs: n: pkgs.rPackages.${n}.overrideAttrs (o: {
        stripDebugList = o.stripDebugList ++ [ "library/${n}/bin" ];
      });
      # staged, so processx is rebuilt against the fixed ps
      mkPkgs = s:
        let
          fixPs = { ps = stripBin nixpkgs.legacyPackages.${s} "ps"; };
          withPs = import nixpkgs { system = s; config.rPackageOverrides = _: fixPs; };
        in import nixpkgs {
          system = s;
          config.rPackageOverrides = _: fixPs // { processx = stripBin withPs "processx"; };
        };
      forAll = f: nixpkgs.lib.genAttrs systems (s: f (mkPkgs s));
    in {
      packages = forAll (pkgs: {
        default = pkgs.rPackages.buildRPackage {
          pname = "swissvotescore";
          version = "0.1.0";
          src = self;
          propagatedBuildInputs = with pkgs.rPackages; [
            dplyr tidyr purrr tibble jsonlite lubridate
          ];
        };
      });

      overlays.default = final: prev: {
        rPackages = prev.rPackages // {
          swissvotescore = self.packages.${final.system}.default;
        };
      };

      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = [ (pkgs.rWrapper.override {
            packages = with pkgs.rPackages; [
              dplyr tidyr purrr tibble jsonlite lubridate roxygen2
            ];
          }) ];
        };
      });
    };
}