{
  description = "Build a cargo project without extra checks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

    flake-utils.url = "github:numtide/flake-utils";
    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs";

      # The main branch follows the "canary" channel of the Android SDK
      # repository. Use another android-nixpkgs branch to explicitly
      # track an SDK release channel.
      #
      # url = "github:tadfisher/android-nixpkgs/stable";
      # url = "github:tadfisher/android-nixpkgs/beta";
      # url = "github:tadfisher/android-nixpkgs/preview";
      # url = "github:tadfisher/android-nixpkgs/canary";

      # If you have nixpkgs as an input, this will replace the "nixpkgs" input
      # for the "android" flake.
      #
      # inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    crane,
    flake-utils,
    rust-overlay,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [(import rust-overlay)];
      };

      rust = pkgs.rust-bin.nightly.latest.default.override {
        extensions = ["rust-analyzer" "rust-src"];
        targets = ["aarch64-linux-android"];
      };
      android-sdk = inputs.android-nixpkgs.sdk.${system} (sdkPkgs:
        with sdkPkgs; [
          cmdline-tools-latest
          build-tools-34-0-0
          platform-tools
          # platforms-android-34
          emulator
          # ndk-bundle
          ndk-27-0-11902837
          sources-android-34
          platforms-android-32
        ]);

      craneLib = (crane.mkLib pkgs).overrideToolchain rust;
      TEMPLATE_PROJECT_NAME = craneLib.buildPackage {
        src = craneLib.cleanCargoSource (craneLib.path ./.);
        strictDeps = true;

        buildInputs =
          [
            # Add additional build inputs here
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv
          ];

        # Additional environment variables can be set directly
        # MY_CUSTOM_VAR = "some value";
      };
    in {
      checks = {
        inherit TEMPLATE_PROJECT_NAME;
      };

      packages.default = TEMPLATE_PROJECT_NAME;
      packages.android-sdk = android-sdk;

      apps.default = flake-utils.lib.mkApp {
        drv = TEMPLATE_PROJECT_NAME;
      };

      devShells.default = craneLib.devShell {
        ANDROID_NDK_HOME = "${android-sdk}/share/android-sdk/ndk";
        # ANDROID_SDK_ROOT = "${android-sdk}/share/android-sdk/platforms/android-34";
        # ANDROID_HOME = "${android-sdk}";
        # buildInputs =
        #   android-studio
        #   android-sdk
        # ];
        # Inherit inputs from checks.
        checks = self.checks.${system};

        # Additional dev-shell environment variables can be set directly
        # MY_CUSTOM_DEVELOPMENT_VAR = "something else";

        # Extra inputs can be added here; cargo and rustc are provided by default.
        packages = [
          android-sdk
          pkgs.cargo-apk
          # pkgs.ripgrep
        ];
      };
    });
}
