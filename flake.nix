{
  description = "Reproducer for failing ArrayFire tests";

  nixConfig = {
    extra-experimental-features = "nix-command flakes";
    extra-substituters = "https://halide-haskell.cachix.org";
    extra-trusted-public-keys = "halide-haskell.cachix.org-1:cFPqtShCsH4aNjn2q4PHb39Omtd/FWRhrkTBcSrtNKQ=";
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nixgl = {
      url = "github:guibou/nixGL";
      inputs.flake-utils.follows = "flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (self: super: {
            openblas = super.openblas.overrideAttrs (attrs: rec {
              version = "0.3.23";
              name = "${attrs.pname}-${version}";
              src = super.fetchFromGitHub {
                owner = "xianyi";
                repo = "OpenBLAS";
                rev = "30a0ccbd141cc147eeb78bec33637796bb39a6a1";
                sha256 = "sha256-/DCeBxXOKscAfnqrsRtqvkIPvr7g1az3Q1efjF+yJbY=";
              };
              makeFlags = (attrs.makeFlags or []) ++ [
                "CFLAGS=-fno-tree-vectorize"
              ];
            });
            forge = self.callPackage ./forge.nix { };
            arrayfire = self.callPackage ./arrayfire.nix { };
          })
          inputs.nixgl.overlay
        ];
        config.allowUnfree = true;
      };
      inherit (pkgs) fetchFromGitHub;

      assets = fetchFromGitHub {
        owner = "arrayfire";
        repo = "assets";
        rev = "cd08d749611b324012555ad6f23fd76c5465bd6c";
        sha256 = "sha256-v4uhqPz1P1g1430FTmMp22xJS50bb5hZTeEX49GgMWg=";
      };
      clblast = fetchFromGitHub {
        owner = "cnugteren";
        repo = "CLBlast";
        rev = "4500a03440e2cc54998c0edab366babf5e504d67";
        sha256 = "sha256-I25ylQp6kHZx6Q7Ph5r3abWlQ6yeIHIDdS1eGCyArZ0=";
      };
      clfft = fetchFromGitHub {
        owner = "arrayfire";
        repo = "clfft";
        rev = "760096b37dcc4f18ccd1aac53f3501a83b83449c";
        sha256 = "sha256-vJo1YfC2AJIbbRj/zTfcOUmi0Oj9v64NfA9MfK8ecoY=";
      };
      glad = fetchFromGitHub {
        owner = "arrayfire";
        repo = "glad";
        rev = "ef8c5508e72456b714820c98e034d9a55b970650";
        sha256 = "sha256-u9Vec7XLhE3xW9vzM7uuf+b18wZsh/VMtGbB6nMVlno=";
      };
      threads = fetchFromGitHub {
        owner = "arrayfire";
        repo = "threads";
        rev = "4d4a4f0384d1ac2f25b2c4fc1d57b9e25f4d6818";
        sha256 = "sha256-qqsT9woJDtQvzuV323OYXm68pExygYs/+zZNmg2sN34=";
      };
      test-data = fetchFromGitHub {
        owner = "arrayfire";
        repo = "arrayfire-data";
        rev = "a5f533d7b864a4d8f0dd7c9aaad5ff06018c4867";
        sha256 = "sha256-AWzhsrDXyZrQN2bd0Ng/XlE8v02x7QWTiFTyaAuRXSw=";
      };
      cub = fetchFromGitHub {
        owner = "NVIDIA";
        repo = "cub";
        rev = "1.10.0";
        sha256 = "sha256-JyyNaTrtoSGiMP7tVUu9lFL07lyfJzRTVtx8yGy6/BI=";
      };

    in
    {
      packages = {
        default = pkgs.arrayfire;
        arrayfire = pkgs.arrayfire.override {
          cudaPackages = pkgs.cudaPackages_11_4;
        };
        forge = pkgs.forge;
        blas = pkgs.blas;
        lapack = pkgs.lapack;
      };
      devShells.default = pkgs.mkShell {
        packages = [ pkgs.pkg-config ];
        buildInputs = with pkgs; [
          blas
          lapack
          boost.out
          boost.dev
          fftw
          fftwFloat
          forge
          freeimage
          freetype
          gtest
          glfw3
          glm
          libGL
          mesa
          ocl-icd
          opencl-clhpp
          span-lite
          fmt
          spdlog.out
          spdlog.dev
          cudaPackages_11_4.cudatoolkit
          cudaPackages_11_4.cudnn
        ];
        nativeBuildInputs = with pkgs; [
          cmake
          pkg-config
          python3
          gdb
          valgrind
          git
          nixgl.auto.nixGLDefault
          nixgl.auto.nixGLNvidia
        ];
        shellHook = ''
          prepare_sources() {
            mkdir -p ./extern/af_glad-src
            mkdir -p ./extern/af_threads-src
            mkdir -p ./extern/af_assets-src
            mkdir -p ./extern/af_test_data-src
            mkdir -p ./extern/ocl_clfft-src
            mkdir -p ./extern/ocl_clblast-src
            mkdir -p ./extern/nv_cub-src
            cp -R --no-preserve=mode,ownership ${glad}/* ./extern/af_glad-src/
            cp -R --no-preserve=mode,ownership ${threads}/* ./extern/af_threads-src/
            cp -R --no-preserve=mode,ownership ${assets}/* ./extern/af_assets-src/
            cp -R --no-preserve=mode,ownership ${test-data}/* ./extern/af_test_data-src/
            cp -R --no-preserve=mode,ownership ${clfft}/* ./extern/ocl_clfft-src/
            cp -R --no-preserve=mode,ownership ${clblast}/* ./extern/ocl_clblast-src/
            cp -R --no-preserve=mode,ownership ${cub}/* ./extern/nv_cub-src/

            substituteInPlace src/api/unified/symbol_manager.cpp \
              --replace '"/opt/arrayfire-3/lib/",' \
                        "\"$out/lib/\", \"/opt/arrayfire-3/lib/\","

            substituteInPlace CMakeLists.txt \
              --replace ' QUIET ' ' ' \
              --replace ' QUIET)' ')' \
              --replace 'find_package(MKL)' '# find_package(MKL)'
            substituteInPlace src/backend/cuda/CMakeLists.txt \
              --replace 'CUDA_LIBRARIES_PATH ''${CUDA_cudart_static_LIBRARY}' \
                        'CUDA_LIBRARIES_PATH ''${CUDA_cusolver_LIBRARY}'
            substituteInPlace CMakeModules/AFconfigure_deps_vars.cmake \
              --replace 'set(BUILD_OFFLINE OFF)' 'set(BUILD_OFFLINE ON)'
          }

          export AF_CMAKE_FLAGS="-DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=ON -DAF_TEST_WITH_MTX_FILES=OFF -DAF_BUILD_EXAMPLES=OFF -DAF_BUILD_FORGE=OFF -DAF_BUILD_OPENCL=OFF -DAF_BUILD_CUDA=ON -DAF_COMPUTE_LIBRARY='FFTW/LAPACK/BLAS' -DAF_USE_RELATIVE_TEST_DIR=OFF -DCMAKE_CXX_FLAGS=-DSPDLOG_FMT_EXTERNAL=1"
          export LD_LIBRARY_PATH=${pkgs.freeimage}/lib:${pkgs.cudaPackages_11_4.cudatoolkit}/lib64:$LD_LIBRARY_PATH

          export MESA_PATH=${pkgs.mesa}
          export MESA_DRIVERS_PATH=${pkgs.mesa.drivers}
          export GLVD_PATH=${pkgs.libglvnd}
          export CUDATOOLKIT=${pkgs.cudaPackages_11_4.cudatoolkit}
          export NVRTC_PATH=${pkgs.cudaPackages_11_4.cuda_nvrtc}
        '';
      };
      formatter = pkgs.nixpkgs-fmt;
    }
  );
}
