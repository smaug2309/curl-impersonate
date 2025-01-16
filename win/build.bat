@echo off

set "PATH=%PATH:LLVM=Dummy%"

IF EXIST "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\%1.bat" (
  call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\%1.bat"
) ELSE (
  call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\%1.bat"
)

:: common dirs
set deps=%cd%\deps
set build=%cd%\build
set packages=%cd%\packages
set patches=%cd%\chrome\patches

:: configuration
set configuration=Release

set cmake_common_args=-GNinja -DCMAKE_BUILD_TYPE=%configuration%^
  -DCMAKE_PREFIX_PATH="%packages%" -DCMAKE_INSTALL_PREFIX="%packages%"^
  -DCMAKE_POLICY_DEFAULT_CMP0091=NEW -DCMAKE_MSVC_RUNTIME_LIBRARY=MultiThreaded^
  -DCMAKE_C_COMPILER=clang-cl.exe -DCMAKE_CXX_COMPILER=clang-cl.exe -DCMAKE_LINKER=link.exe

::: Fetch zlib v1.3
git clone https://github.com/madler/zlib.git "%deps%\zlib" && pushd "%deps%\zlib"
git checkout 09155eaa2f9270dc4ed1fa13e2b4b2613e6e4851

:: Build & Install zlib
cmake %cmake_common_args% -S . -B "%build%\zlib"
cmake --build "%build%\zlib" --config %configuration% --target install
move /y "%packages%\lib\zlibstatic.lib" "%packages%\lib\zlib.lib"
popd

::: Fetch zstd v1.5.6
git clone https://github.com/facebook/zstd.git "%deps%\zstd" && pushd "%deps%\zstd"
git checkout 794ea1b0afca0f020f4e57b6732332231fb23c70

:: Apply patch
patch -p1 < "%~dp0windows-zstd.patch" --verbose

:: Build & Install zstd
cmake %cmake_common_args% -DZSTD_BUILD_SHARED=OFF -S build\cmake -B "%build%\zstd"
cmake --build "%build%\zstd" --config %configuration% --target install
ren "%packages%\lib\zstd_static.lib" zstd.lib
popd

::: Fetch brotli v1.1.0
git clone https://github.com/google/brotli.git "%deps%\brotli" && pushd "%deps%\brotli"
git checkout ed738e842d2fbdf2d6459e39267a633c4a9b2f5d

:: Build & Install brotli
cmake %cmake_common_args% -DBUILD_SHARED_LIBS=OFF -S . -B "%build%\brotli"
cmake --build "%build%\brotli" --config %configuration% --target install
popd

::: Fetch nghttp2 v1.63.0
git clone https://github.com/nghttp2/nghttp2.git "%deps%\nghttp2" && pushd "%deps%\nghttp2"
git checkout 8f44147c385fb1ed93a6f39911eeb30279bfd2dd
git submodule update --init

:: Build & Install nghttp2
cmake %cmake_common_args% -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=ON -S . -B "%build%\nghttp2"
cmake --build "%build%\nghttp2" --config %configuration% --target install
popd

::: Fetch boringssl
git clone https://boringssl.googlesource.com/boringssl.git "%deps%\boringssl" && pushd "%deps%\boringssl"
git checkout cd95210465496ac2337b313cf49f607762abe286

:: Apply patch
patch -p1 < "%patches%\boringssl.patch"
patch -p1 < "%~dp0windows-boringssl.patch" --verbose

:: Build & Install boringssl
cmake %cmake_common_args% -DCMAKE_POSITION_INDEPENDENT_CODE=ON -S . -B "%build%\boringssl"
cmake --build "%build%\boringssl" --config %configuration% --target install
popd

::: Fetch curl v8.7.1
git clone https://github.com/curl/curl.git "%deps%\curl" && pushd "%deps%\curl"
git checkout de7b3e89218467159a7af72d58cea8425946e97d

:: Apply patch
patch -p1 < "%patches%\curl-impersonate.patch"
patch -p1 < "%~dp0windows-curl.patch"

:: Build & Install curl
cmake %cmake_common_args% -DBUILD_SHARED_LIBS=ON^
  -DBUILD_STATIC_LIBS=ON^
  -DBUILD_STATIC_CURL=ON^
  -DCURL_USE_OPENSSL=ON^
  -DCURL_BROTLI=ON^
  -DCURL_ZSTD=ON^
  -DUSE_ZLIB=ON^
  -DUSE_WIN32_IDN=ON^
  -DUSE_NGHTTP2=ON^
  -DHAVE_ECH=1^
  -DUSE_ECH=ON^
  -DENABLE_WEBSOCKETS=ON^
  -DDENABLE_IPV6=ON^
  -DENABLE_UNICODE=ON^
  -DCURL_ENABLE_SSL=ON^
  -DCURL_USE_LIBSSH2=OFF^
  "-DCMAKE_C_FLAGS=/DNGHTTP2_STATICLIB=1 /Dstrtok_r=strtok_s"^
  -S . -B "%build%\curl"
cmake --build "%build%\curl" --config %configuration% --target install
popd
