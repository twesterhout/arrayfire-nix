{
  description = "Nix flake for ArrayFire";

  nixConfig = {
    extra-substituters = "https://halide-haskell.cachix.org";
    extra-trusted-public-keys = "halide-haskell.cachix.org-1:cFPqtShCsH4aNjn2q4PHb39Omtd/FWRhrkTBcSrtNKQ=";
  };

  inputs = {
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.url = "github:twesterhout/nixpkgs/arrayfire-3.9.0";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = inputs:
    let
      overlayBuilder = { cudaArch ? null, cudaVersion ? null, cudaHash ? null }: final: prev: {
        # We need a newer OpenBLAS for this to be fixed:
        # https://github.com/xianyi/OpenBLAS/issues/4013
        # openblas = prev.openblas.overrideAttrs (attrs: rec {
        #   version = "0.3.24";
        #   name = "${attrs.pname}-${version}";
        #   src = prev.fetchFromGitHub {
        #     owner = "xianyi";
        #     repo = "OpenBLAS";
        #     rev = "88c205c9582b98c7d5a89ac9952bf36a019e5966";
        #     sha256 = "sha256-+OuMV7+RBwghJrWsGCk5cu3Yzawkrmu0yvPE0uPP7rU=";
        #   };
        #   # When gcc and gfortran are upgraded to v13, we can remove it
        #   makeFlags = (attrs.makeFlags or [ ]) ++ [ "CFLAGS=-fno-tree-vectorize" ];
        # });

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

      pkgsFor = system: overlays: import inputs.nixpkgs {
        inherit system;
        overlays = [ tesla_535_86_10 ];
        config.allowUnfree = true;
        config.cudaSupport = true;
        config.nvidia.acceptLicense = true;
      };
    in
    {
      packages = inputs.flake-utils.lib.eachDefaultSystemMap (system:
        let
          pkgsV100 = pkgsFor system [ tesla_535_86_10 ];
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
        inherit tesla_535_86_10;
      };

      devShells = inputs.flake-utils.lib.eachDefaultSystemMap (system:
        let
          pkgsV100 = pkgsFor system [ tesla_535_86_10 ];
        in
        {
          V100 = pkgsV100.mkShell {
            nativeBuildInputs = [ pkgsV100.clinfo ];
            shellHook = ''
              export OCL_ICD_VENDORS=${pkgsV100.nvidiaComputeDrivers}/etc/OpenCL/vendors
              export LD_LIBRARY_PATH=${pkgsV100.cudaPackages.cudatoolkit}/lib64:$LD_LIBRARY_PATH}
            '';
          };
        });

      # devShells = inputs.flake-utils.lib.eachDefaultSystemMap (system:
      #   let
      #     pkgs = pkgsFor system;
      #     inherit (pkgs) fetchFromGitHub;
      #     assets = fetchFromGitHub {
      #       owner = "arrayfire";
      #       repo = "assets";
      #       rev = "cd08d749611b324012555ad6f23fd76c5465bd6c";
      #       sha256 = "sha256-v4uhqPz1P1g1430FTmMp22xJS50bb5hZTeEX49GgMWg=";
      #     };
      #     clblast = fetchFromGitHub {
      #       owner = "cnugteren";
      #       repo = "CLBlast";
      #       rev = "4500a03440e2cc54998c0edab366babf5e504d67";
      #       sha256 = "sha256-I25ylQp6kHZx6Q7Ph5r3abWlQ6yeIHIDdS1eGCyArZ0=";
      #     };
      #     clfft = fetchFromGitHub {
      #       owner = "arrayfire";
      #       repo = "clfft";
      #       rev = "760096b37dcc4f18ccd1aac53f3501a83b83449c";
      #       sha256 = "sha256-vJo1YfC2AJIbbRj/zTfcOUmi0Oj9v64NfA9MfK8ecoY=";
      #     };
      #     glad = fetchFromGitHub {
      #       owner = "arrayfire";
      #       repo = "glad";
      #       rev = "ef8c5508e72456b714820c98e034d9a55b970650";
      #       sha256 = "sha256-u9Vec7XLhE3xW9vzM7uuf+b18wZsh/VMtGbB6nMVlno=";
      #     };
      #     threads = fetchFromGitHub {
      #       owner = "arrayfire";
      #       repo = "threads";
      #       rev = "4d4a4f0384d1ac2f25b2c4fc1d57b9e25f4d6818";
      #       sha256 = "sha256-qqsT9woJDtQvzuV323OYXm68pExygYs/+zZNmg2sN34=";
      #     };
      #     test-data = fetchFromGitHub {
      #       owner = "arrayfire";
      #       repo = "arrayfire-data";
      #       rev = "a5f533d7b864a4d8f0dd7c9aaad5ff06018c4867";
      #       sha256 = "sha256-AWzhsrDXyZrQN2bd0Ng/XlE8v02x7QWTiFTyaAuRXSw=";
      #     };
      #     cub = fetchFromGitHub {
      #       owner = "NVIDIA";
      #       repo = "cub";
      #       rev = "1.10.0";
      #       sha256 = "sha256-JyyNaTrtoSGiMP7tVUu9lFL07lyfJzRTVtx8yGy6/BI=";
      #     };
      #     spdlog = fetchFromGitHub {
      #       owner = "gabime";
      #       repo = "spdlog";
      #       rev = "v1.9.2";
      #       hash = "sha256-GSUdHtvV/97RyDKy8i+ticnSlQCubGGWHg4Oo+YAr8Y=";
      #     };
      #   in
      #   {
      #     default = pkgs.mkShell {
      #       buildInputs = with pkgs; [
      #         blas
      #         lapack
      #         boost.out
      #         boost.dev
      #         fftw
      #         fftwFloat
      #         forge
      #         freeimage
      #         freetype
      #         gtest
      #         glfw3
      #         glm
      #         libGL
      #         mesa
      #         ocl-icd
      #         opencl-clhpp
      #         span-lite
      #         fmt_9
      #         # cudaPackages_12.cudatoolkit
      #         # cudaPackages_12.cudnn
      #       ];
      #       nativeBuildInputs = with pkgs; [
      #         cmake
      #         pkg-config
      #         python3
      #         git
      #         clinfo
      #         nixpkgs-fmt
      #       ];
      #       shellHook = ''
      #         prepare_sources() {
      #           mkdir -p ./extern/af_glad-src
      #           mkdir -p ./extern/af_threads-src
      #           mkdir -p ./extern/af_assets-src
      #           mkdir -p ./extern/af_test_data-src
      #           mkdir -p ./extern/ocl_clfft-src
      #           mkdir -p ./extern/ocl_clblast-src
      #           mkdir -p ./extern/nv_cub-src
      #           mkdir -p ./extern/spdlog-src
      #           cp -R --no-preserve=mode,ownership ${glad}/* ./extern/af_glad-src/
      #           cp -R --no-preserve=mode,ownership ${threads}/* ./extern/af_threads-src/
      #           cp -R --no-preserve=mode,ownership ${assets}/* ./extern/af_assets-src/
      #           cp -R --no-preserve=mode,ownership ${test-data}/* ./extern/af_test_data-src/
      #           cp -R --no-preserve=mode,ownership ${clfft}/* ./extern/ocl_clfft-src/
      #           cp -R --no-preserve=mode,ownership ${clblast}/* ./extern/ocl_clblast-src/
      #           cp -R --no-preserve=mode,ownership ${cub}/* ./extern/nv_cub-src/
      #           cp -R --no-preserve=mode,ownership ${spdlog}/* ./extern/spdlog-src/

      #           substituteInPlace CMakeLists.txt \
      #             --replace 'find_package(BLAS)' 'set(BLA_VENDOR Generic)
      #             find_package(BLAS)'
      #         }

      #         # export OCL_ICD_VENDORS=${pkgs.nvidiaComputeDrivers}/etc/OpenCL/vendors
      #         # export LD_LIBRARY_PATH=${pkgs.nvidiaComputeDrivers}/lib:${pkgs.freeimage}/lib:${pkgs.forge}/lib:$LD_LIBRARY_PATH
      #       '';
      #     };
      #   });

    };
}
