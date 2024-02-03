{
  description = "Nix flake for ArrayFire";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    # nixpkgs.url = "github:twesterhout/nixpkgs/arrayfire-3.9.0";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs:
    let
      overlayBuilder = { cudaArch ? null, cudaVersion ? null, cudaHash ? null }: final: prev: {
        # A package with Nvidia drivers for CUDA and OpenCL. Very similar to
        # nvidia_x11, but we don't skip libraries the graphics library to have
        # a smaller package.
        nvidiaComputeDrivers =
          if cudaVersion == null
          then null
          else
            (prev.linuxPackages.nvidia_x11.override {
              libsOnly = true;
              kernel = null;
              firmware = null;
            }).overrideAttrs
              (oldAttrs: {
                pname = "nvidia-compute-drivers";
                name = "nvidia-compute-drivers-${cudaArch}-${cudaVersion}";
                version = cudaVersion;
                src = prev.fetchurl {
                  url = "https://us.download.nvidia.com/${cudaArch}/${cudaVersion}/NVIDIA-Linux-x86_64-${cudaVersion}.run";
                  hash = cudaHash;
                };
                useGLVND = false;
                useProfiles = false;
                postFixup = ''
                  ls -l $out/lib
                  rm -v -r $out/bin
                  rm -v -r $out/lib/nvidia
                  rm -v -r $out/lib/systemd
                  rm -v -r $out/lib/vdpau
                  rm -v $out/lib/libEGL*
                  rm -v $out/lib/libnvidia-egl*
                  rm -v $out/lib/libnvidia-encode*
                  rm -v $out/lib/libnvidia-fbc*
                  rm -v $out/lib/libnvidia-gl*
                  rm -v $out/lib/libnvidia-pkcs11*
                  rm -v $out/lib/libnvidia-tls*
                  rm -v $out/lib/libGL*
                  rm -v $out/lib/libOpenGL*
                  rm -v $out/lib/libglx*
                  rm -v $out/lib/libnvcuvid*
                '';
              });
      };

      tesla_535_86_10 = overlayBuilder {
        cudaArch = "tesla";
        cudaVersion = "535.86.10";
        cudaHash = "sha256-zsN/2TFwkaAf0DgDCUAKFChHaXkGUf4CHh1aqiMno3A=";
      };

      tesla_535_104_12 = overlayBuilder {
        cudaArch = "tesla";
        cudaVersion = "535.104.12";
        cudaHash = "sha256-/8LYniM9JCftsf9fQ2AoqUs++G54+X4IjhHZBcgugAE=";
      };

      pkgsFor = system: overlays: import inputs.nixpkgs ({ inherit system overlays; }
        // inputs.nixpkgs.lib.optionalAttrs (builtins.length overlays > 0) {
        config.allowUnfree = true;
        config.cudaSupport = true;
        config.nvidia.acceptLicense = true;
      });
    in
    {
      packages = inputs.flake-utils.lib.eachDefaultSystemMap (system:
        let
          pkgsV100 = pkgsFor system [ tesla_535_104_12 ];
          pkgs = pkgsFor system [ ];
        in
        {
          default = inputs.self.packages.${system}.arrayfire;
          arrayfire = pkgs.arrayfire;

          V100 = {
            inherit (pkgsV100) nvidiaComputeDrivers;
            arrayfire = pkgsV100.arrayfire.override { doCheck = true; };
            arrayfire-cpu = pkgsV100.arrayfire.override { openclSupport = false; cudaSupport = false; doCheck = true; };
            arrayfire-opencl = pkgsV100.arrayfire.override { openclSupport = true; cudaSupport = false; doCheck = true; };
            arrayfire-cuda = pkgsV100.arrayfire.override { openclSupport = true; cudaSupport = true; doCheck = true; };
          };
        });

      inherit overlayBuilder;
      overlays = {
        default = overlayBuilder { cudaArch = null; cudaVersion = null; cudaHash = null; };
        inherit tesla_535_86_10 tesla_535_104_12;
      };
    };
}
