{ boost
, cmake
, cudaPackages
, doxygen
, fetchFromGitHub
, fmt
, forge
, freeimage
, fftw
, fftwFloat
, git
, gtest
, lib
, libGLU
, libGL
, libglvnd
, mesa
, nixgl
, ocl-icd
, openblas
, blas
, lapack
, opencl-clhpp
, pkg-config
, python3
, span-lite
, spdlog
, stdenv
, withOpenCL ? false
, withCuda ? true
}:

assert blas.isILP64 == false;

stdenv.mkDerivation rec {
  pname = "arrayfire";
  version = "3.8.3";

  src = fetchFromGitHub {
    owner = pname;
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-Chk7koBv66JsfKV6+y6wg21snXYZswo6hjYm8rYEbbs=";
  };

  assets = fetchFromGitHub {
    owner = pname;
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
    owner = pname;
    repo = "clfft";
    rev = "760096b37dcc4f18ccd1aac53f3501a83b83449c";
    sha256 = "sha256-vJo1YfC2AJIbbRj/zTfcOUmi0Oj9v64NfA9MfK8ecoY=";
  };
  glad = fetchFromGitHub {
    owner = pname;
    repo = "glad";
    rev = "ef8c5508e72456b714820c98e034d9a55b970650";
    sha256 = "sha256-u9Vec7XLhE3xW9vzM7uuf+b18wZsh/VMtGbB6nMVlno=";
  };
  threads = fetchFromGitHub {
    owner = pname;
    repo = "threads";
    rev = "4d4a4f0384d1ac2f25b2c4fc1d57b9e25f4d6818";
    sha256 = "sha256-qqsT9woJDtQvzuV323OYXm68pExygYs/+zZNmg2sN34=";
  };
  test-data = fetchFromGitHub {
    owner = pname;
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

  cmakeFlags = [
    "-DBUILD_TESTING=ON"
    "-DAF_TEST_WITH_MTX_FILES=OFF"
    "-DAF_BUILD_EXAMPLES=ON"
    "-DAF_BUILD_FORGE=OFF"
    "-DAF_USE_RELATIVE_TEST_DIR=OFF"
    "-DAF_COMPUTE_LIBRARY='FFTW/LAPACK/BLAS'"
    "-DCMAKE_CXX_FLAGS=-DSPDLOG_FMT_EXTERNAL=1"
    (if withOpenCL then "-DAF_BUILD_OPENCL=ON" else "-DAF_BUILD_OPENCL=OFF")
    (if withCuda then "-DAF_BUILD_CUDA=ON" else "-DAF_BUILD_CUDA=OFF")
  ];

  postPatch = ''
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
  '';

  doCheck = true;
  checkPhase = ''
    export LD_LIBRARY_PATH="${forge}/lib:${freeimage}/lib:$LD_LIBRARY_PATH"
  '' + (if withCuda then ''
    export LD_LIBRARY_PATH="${cudaPackages.cudatoolkit}/lib64:$LD_LIBRARY_PATH"
    AF_TRACE=all AF_PRINT_ERRORS=1 nixGL ctest -v -j1
  '' else ''
    AF_TRACE=all AF_PRINT_ERRORS=1 ctest -v -j1
  '');

  buildInputs = [
    blas
    boost.out
    boost.dev
    fmt
    freeimage
    fftw
    fftwFloat
    forge
    gtest
    lapack
    libGL
    span-lite
    spdlog
  ]
  ++ (lib.optionals withCuda [
        cudaPackages.cudatoolkit
        cudaPackages.cudnn
      ])
  ++ (lib.optionals withOpenCL [ mesa ocl-icd opencl-clhpp ]);

  nativeBuildInputs = [
    cmake
    doxygen
    git
    pkg-config
    python3
  ]
  ++ lib.optional withCuda nixgl.auto.nixGLDefault;

  meta = with lib; {
    description = "A general-purpose library for parallel and massively-parallel computations";
    longDescription = ''
      A general-purpose library that simplifies the process of developing software that targets parallel and massively-parallel architectures including CPUs, GPUs, and other hardware acceleration devices.";
    '';
    license = licenses.bsd3;
    homepage = "https://arrayfire.com/";
    platforms = platforms.linux ++ platforms.darwin;
    maintainers = with maintainers; [ chessai ];
  };
}
