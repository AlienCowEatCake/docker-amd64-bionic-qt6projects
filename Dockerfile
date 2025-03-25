FROM ubuntu:18.04

RUN groupadd --gid 1000 user && \
    useradd --shell /bin/bash --home-dir /home/user --uid 1000 --gid 1000 --create-home user

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get -o Acquire::Check-Valid-Until=false update && \
    apt-get -o Acquire::Check-Valid-Until=false --yes --allow-unauthenticated dist-upgrade && \
    apt-get -o Acquire::Check-Valid-Until=false install --yes --allow-unauthenticated --no-install-recommends \
        wget build-essential fakeroot debhelper curl gawk chrpath git openssh-client p7zip-full libssl-dev \
        "^libxcb.*-dev" libxkbcommon-dev libxkbcommon-x11-dev libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev \
        libdbus-1-dev libglib2.0-dev libfreetype6-dev libcups2-dev mesa-common-dev libgl1-mesa-dev libegl1-mesa-dev \
        libxcursor-dev libxcomposite-dev libxdamage-dev libxrandr-dev libfontconfig1-dev libxss-dev libxtst-dev \
        libpulse-dev libasound2-dev libva-dev libopenal-dev libbluetooth-dev libspeechd-dev \
        libgtk-3-dev libgtk2.0-dev gperf bison ruby flex yasm libwayland-dev libwayland-egl-backend-dev \
        flite1-dev libvulkan-dev gcc-8 g++-8 && \
    apt-get clean

WORKDIR /usr/src

ENV PATH="/opt/clang/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/clang/lib:/opt/qt6/lib"
ENV LANG="C.UTF-8"

RUN export CMAKE_VERSION="3.31.6" && \
    wget --no-check-certificate https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz && \
    tar -xvpf cmake-${CMAKE_VERSION}.tar.gz && \
    cd cmake-${CMAKE_VERSION} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./configure --prefix=/opt/cmake --no-qt-gui --parallel=$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    ln -s /opt/cmake/bin/cmake /usr/local/bin/ && \
    ln -s /opt/cmake/bin/ctest /usr/local/bin/ && \
    ln -s /opt/cmake/bin/cpack /usr/local/bin/ && \
    cd .. && \
    rm -rf cmake-${CMAKE_VERSION}.tar.gz cmake-${CMAKE_VERSION}

RUN export NINJA_VERSION="1.12.1" && \
    wget --no-check-certificate https://github.com/ninja-build/ninja/archive/refs/tags/v${NINJA_VERSION}.tar.gz && \
    tar -xvpf v${NINJA_VERSION}.tar.gz && \
    cd ninja-${NINJA_VERSION} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake -S . -B build \
            -G "Unix Makefiles" \
            -DCMAKE_BUILD_TYPE=Release && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --build build --target ninja -- -j$(getconf _NPROCESSORS_ONLN) && \
    strip --strip-all build/ninja && \
    cp -a build/ninja /usr/local/bin/ && \
    cd .. && \
    rm -rf v${NINJA_VERSION}.tar.gz ninja-${NINJA_VERSION}

RUN export CLANG_VERSION="20.1.1" && \
    wget --no-check-certificate https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-${CLANG_VERSION}.tar.gz && \
    tar -xvpf llvmorg-${CLANG_VERSION}.tar.gz && \
    cd llvm-project-llvmorg-${CLANG_VERSION} && \
    sed -i 's|\(virtual unsigned GetDefaultDwarfVersion() const { return \)5;|\14;|' clang/include/clang/Driver/ToolChain.h && \
    sed -i 's|^\(unsigned ToolChain::GetDefaultDwarfVersion() const {\)|\1\n  return 4;|' clang/lib/Driver/ToolChain.cpp && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake -S llvm -B build \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_COMPILER="/usr/bin/gcc-8" \
            -DCMAKE_CXX_COMPILER="/usr/bin/g++-8" \
            -DLLVM_ENABLE_PROJECTS="clang;lld" \
            -DLLVM_INCLUDE_TESTS=OFF \
            -DLLVM_INCLUDE_DOCS=OFF \
            -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF \
            -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
            -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
            -DCMAKE_INSTALL_PREFIX="/opt/clang" && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --build build --target all && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --install build --prefix "/opt/clang" && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake -S runtimes -B build_runtimes \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_C_COMPILER="/opt/clang/bin/clang" \
            -DCMAKE_CXX_COMPILER="/opt/clang/bin/clang++" \
            -DLLVM_USE_LINKER=lld \
            -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;libunwind" \
            -DLLVM_INCLUDE_TESTS=OFF \
            -DLLVM_INCLUDE_DOCS=OFF \
            -DLLVM_ENABLE_PER_TARGET_RUNTIME_DIR=OFF \
            -DLIBCXX_INCLUDE_BENCHMARKS=OFF \
            -DLIBCXXABI_USE_LLVM_UNWINDER=ON \
            -DCMAKE_INSTALL_PREFIX="/opt/clang" && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --build build_runtimes --target cxx cxxabi unwind && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --build build_runtimes --target install-cxx install-cxxabi install-unwind && \
    cd .. && \
    rm -rf llvmorg-${CLANG_VERSION}.tar.gz llvm-project-llvmorg-${CLANG_VERSION}

RUN export XCB_PROTO_VERSION="1.17.0" && \
    export LIBXCB_VERSION="1.17.0" && \
    export XCB_UTIL_VERSION="0.4.1" && \
    export XCB_UTIL_IMAGE_VERSION="0.4.1" && \
    export XCB_UTIL_KEYSYMS_VERSION="0.4.1" && \
    export XCB_UTIL_RENDERUTIL_VERSION="0.3.10" && \
    export XCB_UTIL_WM_VERSION="0.4.2" && \
    export XCB_UTIL_CURSOR_VERSION="0.1.5" && \
    export XCB_UTIL_ERRORS_VERSION="1.0.1" && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/proto/xcb-proto-${XCB_PROTO_VERSION}.tar.xz && \
    tar -xvpf xcb-proto-${XCB_PROTO_VERSION}.tar.xz && \
    cd xcb-proto-${XCB_PROTO_VERSION} && \
    find src -name '*.xml' -exec sed -i 's|\xe2\x80\x98|\&apos;|g ; s|\xe2\x80\x99|\&apos;|g ; s|\xe2\x80\x9c|\&quot;|g ; s|\xe2\x80\x9d|\&quot;|g' \{\} \; && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./configure --prefix=/opt/xcb PYTHON=python3 && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/libxcb-${LIBXCB_VERSION}.tar.xz && \
    tar -xvpf libxcb-${LIBXCB_VERSION}.tar.xz && \
    cd libxcb-${LIBXCB_VERSION} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen --enable-ge --enable-xevie --enable-xprint --enable-selinux PKG_CONFIG_PATH=/opt/xcb/share/pkgconfig CFLAGS="-O3 -DNDEBUG" PYTHON=python3 && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-${XCB_UTIL_VERSION}.tar.xz && \
    tar -xvpf xcb-util-${XCB_UTIL_VERSION}.tar.xz && \
    cd xcb-util-${XCB_UTIL_VERSION} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-image-${XCB_UTIL_IMAGE_VERSION}.tar.xz && \
    tar -xvpf xcb-util-image-${XCB_UTIL_IMAGE_VERSION}.tar.xz && \
    cd xcb-util-image-${XCB_UTIL_IMAGE_VERSION} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION}.tar.xz && \
    tar -xvpf xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION}.tar.xz && \
    cd xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION}.tar.xz && \
    tar -xvpf xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION}.tar.xz && \
    cd xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-wm-${XCB_UTIL_WM_VERSION}.tar.xz && \
    tar -xvpf xcb-util-wm-${XCB_UTIL_WM_VERSION}.tar.xz && \
    cd xcb-util-wm-${XCB_UTIL_WM_VERSION} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION}.tar.xz && \
    tar -xvpf xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION}.tar.xz && \
    cd xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}.tar.xz && \
    tar -xvpf xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}.tar.xz && \
    cd xcb-util-errors-${XCB_UTIL_ERRORS_VERSION} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/share/pkgconfig CFLAGS="-O3 -DNDEBUG" PYTHON=python3 && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd .. && \
    rm -rf xcb-proto-${XCB_PROTO_VERSION}.tar.xz xcb-proto-${XCB_PROTO_VERSION} libxcb-${LIBXCB_VERSION}.tar.xz libxcb-${LIBXCB_VERSION} xcb-util-${XCB_UTIL_VERSION}.tar.xz xcb-util-${XCB_UTIL_VERSION} xcb-util-image-${XCB_UTIL_IMAGE_VERSION}.tar.xz xcb-util-image-${XCB_UTIL_IMAGE_VERSION} xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION}.tar.xz xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION} xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION}.tar.xz xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION} xcb-util-wm-${XCB_UTIL_WM_VERSION}.tar.xz xcb-util-wm-${XCB_UTIL_WM_VERSION} xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION}.tar.xz xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION} xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}.tar.xz xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}

RUN export OPENSSL_VERSION="3.4.1" && \
    export OPENSSL_DEBIAN_VERSION="3.4.1-1" && \
    wget --no-check-certificate https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    wget --no-check-certificate https://snapshot.debian.org/archive/debian/20250212T030209Z/pool/main/o/openssl/openssl_${OPENSSL_DEBIAN_VERSION}.debian.tar.xz && \
    tar -xvpf openssl-${OPENSSL_VERSION}.tar.gz && \
    tar -xvpf openssl_${OPENSSL_DEBIAN_VERSION}.debian.tar.xz && \
    cd openssl-${OPENSSL_VERSION} && \
    patch -p1 -i ../debian/patches/pic.patch && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./Configure linux-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^i686$|x86| ; s|^arm$|armv4| ; s|^powerpc64le$|ppc64le|') --prefix=/opt/openssl --openssldir=/etc/ssl zlib no-shared && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make depend && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd .. && \
    rm -rf openssl-${OPENSSL_VERSION}.tar.gz openssl-${OPENSSL_VERSION} openssl_${OPENSSL_DEBIAN_VERSION}.debian.tar.xz debian

RUN export QT_VERSION="6.8.2" && \
    export GHCFS_COMMIT="9fda7b0afbd0640f482f4aea8720a8c0afd18740" && \
    export QT_ARCHIVE_PATH="archive/qt/$(echo ${QT_VERSION} | sed 's|\([0-9]*\.[0-9]*\)\..*|\1|')/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz" && \
    wget --no-check-certificate --tries=1 "https://download.qt.io/${QT_ARCHIVE_PATH}" || \
    wget --no-check-certificate --tries=1 "https://qt-mirror.dannhauer.de/${QT_ARCHIVE_PATH}" || \
    wget --no-check-certificate --tries=1 "https://mirror.accum.se/mirror/qt.io/qtproject/${QT_ARCHIVE_PATH}" || \
    wget --no-check-certificate --tries=1 "https://www.nic.funet.fi/pub/mirrors/download.qt-project.org/${QT_ARCHIVE_PATH}" && \
    tar -xvpf qt-everywhere-src-${QT_VERSION}.tar.xz && \
    cd qt-everywhere-src-${QT_VERSION} && \
    wget --no-check-certificate https://raw.githubusercontent.com/gulrak/filesystem/${GHCFS_COMMIT}/include/ghc/filesystem.hpp -O qtbase/src/tools/syncqt/filesystem.hpp && \
    sed -i 's|std::filesystem|ghc::filesystem|g ; s|<filesystem>|"filesystem.hpp"|' qtbase/src/tools/syncqt/main.cpp && \
    sed -i 's|#if \(defined DISABLE_STD_FILESYSTEM\)|#if 1 //\1|' qtquick3d/src/3rdparty/openxr/src/common/filesystem_utils.cpp && \
    echo 'target_link_libraries(XcbQpaPrivate PRIVATE XCB::UTIL -lXau -lXdmcp)' >> qtbase/src/plugins/platforms/xcb/CMakeLists.txt && \
    echo 'target_link_libraries(Network PRIVATE ${CMAKE_DL_LIBS})' >> qtbase/src/network/CMakeLists.txt && \
    sed -i 's|\(#ifdef Q_OS_VXWORKS\)|#if 1 //\1|' qtbase/src/corelib/global/qxpfunctional.h && \
    sed -i 's|\(#include FT_MULTIPLE_MASTERS_H\)|\1\n#if (FREETYPE_MAJOR*10000 + FREETYPE_MINOR*100 + FREETYPE_PATCH) < 20900\nstatic inline FT_Error FT_Done_MM_Var(FT_Library library, FT_MM_Var* amaster) {\n    if (!library)\n        return FT_Err_Invalid_Library_Handle;\n    FT_Memory memory = *((FT_Memory*)library);\n    memory->free(memory, amaster);\n    return FT_Err_Ok;\n}\n#endif|' qtbase/src/gui/text/freetype/qfontengine_ft_p.h && \
    sed -i 's|VK_COLOR_SPACE_DISPLAY_P3_LINEAR_EXT|VK_COLOR_SPACE_DCI_P3_LINEAR_EXT|g' qtbase/src/gui/rhi/qrhivulkan.cpp && \
    sed -i 's|\(pa_context_errno(\)\(context\)|\1const_cast<pa_context *>(\2)| ; s|\(pa_stream_get_context(\)\(stream\)|\1const_cast<pa_stream *>(\2)|' qtmultimedia/src/multimedia/pulseaudio/qpulsehelpers.cpp && \
    mkdir build && \
    cd build && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ../configure -prefix /opt/qt6 -opensource -confirm-license \
            -no-feature-forkfd_pidfd \
            -cmake-generator Ninja -release -shared -platform linux-clang -linker lld \
            -skip qtactiveqt -skip qtdoc -skip qtwebengine -skip qtwebview \
            -nomake examples -nomake tests -nomake benchmarks -nomake manual-tests -nomake minimal-static-tests \
            -gui -widgets -dbus-linked -accessibility \
            -qt-doubleconversion -glib -no-icu -qt-pcre -system-zlib \
            -ssl -openssl-linked -no-libproxy -system-proxies \
            -cups -fontconfig -system-freetype -qt-harfbuzz -gtk -opengl desktop -no-opengles3 -egl -qpa xcb -xcb-xlib \
            -no-directfb -no-eglfs -no-gbm -no-kms -no-linuxfb -xcb \
            -no-libudev -evdev -no-libinput -no-mtdev -no-tslib -bundled-xcb-xinput -xkbcommon \
            -gif -ico -qt-libpng -qt-libjpeg \
            -no-sql-db2 -no-sql-ibase -no-sql-mysql -no-sql-oci -no-sql-odbc -no-sql-psql -sql-sqlite -qt-sqlite \
            -qt-tiff -qt-webp \
            -pulseaudio -gstreamer no \
            -- -Wno-dev -DOpenGL_GL_PREFERENCE=LEGACY \
            -DQT_FEATURE_optimize_full=ON -DQT_FEATURE_clangcpp=OFF -DQT_FEATURE_clang=OFF -DQT_FEATURE_ffmpeg=OFF \
            -DCMAKE_PREFIX_PATH="/opt/openssl;/opt/xcb" -DQT_FEATURE_openssl_linked=ON -DQT_FEATURE_xkbcommon_x11=ON -DTEST_xcb_syslibs=ON \
            && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --build . --parallel && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --install . && \
    cd ../.. && \
    rm -rf qt-everywhere-src-${QT_VERSION}.tar.xz qt-everywhere-src-${QT_VERSION}

RUN export QT6GTK2_COMMIT="b574ba5b59edf5ce220ca304e1d07d75c94d03a2" && \
    wget --no-check-certificate https://github.com/trialuser02/qt6gtk2/archive/${QT6GTK2_COMMIT}.tar.gz && \
    tar -xvpf ${QT6GTK2_COMMIT}.tar.gz && \
    cd qt6gtk2-${QT6GTK2_COMMIT} && \
    mkdir build && \
    cd build && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        /opt/qt6/bin/qmake -r CONFIG+=release ../qt6gtk2.pro && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd ../.. && \
    rm -rf ${QT6GTK2_COMMIT}.tar.gz qt6gtk2-${QT6GTK2_COMMIT}

RUN export QT6CT_COMMIT="55dba8704c0a748b0ce9f2d3cc2cf200ca3db464" && \
    wget --no-check-certificate https://github.com/trialuser02/qt6ct/archive/${QT6CT_COMMIT}.tar.gz && \
    tar -xvpf ${QT6CT_COMMIT}.tar.gz && \
    cd qt6ct-${QT6CT_COMMIT} && \
    mkdir build && \
    cd build && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        /opt/qt6/bin/qmake -r CONFIG+=release ../qt6ct.pro && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make install && \
    cd ../.. && \
    rm -rf ${QT6CT_COMMIT}.tar.gz qt6ct-${QT6CT_COMMIT}

RUN export ADWAITA_QT_COMMIT="0a774368916def5c9889de50f3323dec11de781e" && \
    wget --no-check-certificate https://github.com/FedoraQt/adwaita-qt/archive/${ADWAITA_QT_COMMIT}.tar.gz && \
    tar -xvpf ${ADWAITA_QT_COMMIT}.tar.gz && \
    cd adwaita-qt-${ADWAITA_QT_COMMIT} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake -S . -B build \
        -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH=/opt/qt6 \
            -DCMAKE_INSTALL_PREFIX=/opt/qt6 \
            -DCMAKE_C_COMPILER="/opt/clang/bin/clang" \
            -DCMAKE_CXX_COMPILER="/opt/clang/bin/clang++" \
            -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
            -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld \
            -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
            -DUSE_QT6=true && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --build build --target all && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --install build && \
    cd .. && \
    rm -rf ${ADWAITA_QT_COMMIT}.tar.gz adwaita-qt-${ADWAITA_QT_COMMIT}

RUN export QGNOMEPLATFORM_COMMIT="d86d6baab74c3e69094083715ffef4aef2e516dd" && \
    wget --no-check-certificate https://github.com/FedoraQt/QGnomePlatform/archive/${QGNOMEPLATFORM_COMMIT}.tar.gz && \
    tar -xvpf ${QGNOMEPLATFORM_COMMIT}.tar.gz && \
    cd QGnomePlatform-${QGNOMEPLATFORM_COMMIT} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake -S . -B build \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH=/opt/qt6 \
            -DCMAKE_INSTALL_PREFIX=/opt/qt6 \
            -DCMAKE_C_COMPILER="/opt/clang/bin/clang" \
            -DCMAKE_CXX_COMPILER="/opt/clang/bin/clang++" \
            -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
            -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld \
            -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
            -DUSE_QT6=true && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --build build --target all && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --install build && \
    cd .. && \
    rm -rf ${QGNOMEPLATFORM_COMMIT}.tar.gz QGnomePlatform-${QGNOMEPLATFORM_COMMIT}

RUN export QADWAITA_DECORATIONS_COMMIT="d70c24a745e2f2195222400f901cb3a9296f28b5" && \
    wget --no-check-certificate https://github.com/FedoraQt/QAdwaitaDecorations/archive/${QADWAITA_DECORATIONS_COMMIT}.tar.gz && \
    tar -xvpf ${QADWAITA_DECORATIONS_COMMIT}.tar.gz && \
    cd QAdwaitaDecorations-${QADWAITA_DECORATIONS_COMMIT} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake -S . -B build \
        -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH=/opt/qt6 \
            -DCMAKE_INSTALL_PREFIX=/opt/qt6 \
            -DCMAKE_C_COMPILER="/opt/clang/bin/clang" \
            -DCMAKE_CXX_COMPILER="/opt/clang/bin/clang++" \
            -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
            -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld \
            -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
            -DUSE_QT6=true && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --build build --target all && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --install build && \
    cd .. && \
    rm -rf ${QADWAITA_DECORATIONS_COMMIT}.tar.gz QAdwaitaDecorations-${QADWAITA_DECORATIONS_COMMIT}

# @todo Build AppImageKit from source?
RUN export APPIMAGEKIT_VERSION="13" && \
    export P7ZIP_VERSION="16.02" && \
    echo "|i686|x86_64|arm|aarch64|" | grep -v "|$(gcc -dumpmachine | sed 's|-.*||')|" >/dev/null || ( \
    wget --no-check-certificate https://sourceforge.net/projects/p7zip/files/p7zip/${P7ZIP_VERSION}/p7zip_${P7ZIP_VERSION}_src_all.tar.bz2/download -O p7zip_${P7ZIP_VERSION}_src_all.tar.bz2 && \
    tar -xvpf p7zip_${P7ZIP_VERSION}_src_all.tar.bz2 && \
    cd p7zip_${P7ZIP_VERSION} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) 7z && \
    cd .. && \
    wget --no-check-certificate https://github.com/AppImage/AppImageKit/releases/download/${APPIMAGEKIT_VERSION}/appimagetool-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|').AppImage -O appimagetool-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|').AppImage && \
    mkdir squashfs-root && \
    cd squashfs-root && \
    ../p7zip_${P7ZIP_VERSION}/bin/7z x ../appimagetool-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|').AppImage && \
    cd .. && \
    rm -rf appimagetool-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^arm$|armhf|').AppImage p7zip_${P7ZIP_VERSION}_src_all.tar.bz2 p7zip_${P7ZIP_VERSION} && \
    mv squashfs-root /opt/appimagetool && \
    chmod -R 755 /opt/appimagetool && \
    ln -s /opt/appimagetool/AppRun /usr/local/bin/appimagetool )

RUN export LINUXDEPLOYQT_COMMIT="04480557d24c9d0d45f1f27f9ac1b8f1387d1d26" && \
    git -c http.sslVerify=false clone https://github.com/probonopd/linuxdeployqt.git linuxdeployqt && \
    cd linuxdeployqt && \
    git checkout -f ${LINUXDEPLOYQT_COMMIT} && \
    git clean -dfx && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake -S . -B build \
            -G "Ninja" \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_PREFIX_PATH=/opt/qt6 \
            -DCMAKE_C_COMPILER="/opt/clang/bin/clang" \
            -DCMAKE_CXX_COMPILER="/opt/clang/bin/clang++" \
            -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld \
            -DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld \
            -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld \
            -DGIT_COMMIT=${LINUXDEPLOYQT_COMMIT} \
            -DGIT_TAG_NAME=${LINUXDEPLOYQT_COMMIT} && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        cmake --build build --target all && \
    strip --strip-all build/tools/linuxdeployqt/linuxdeployqt && \
    cp -a build/tools/linuxdeployqt/linuxdeployqt /usr/local/bin/ && \
    cd .. && \
    rm -rf linuxdeployqt

RUN export PATCHELF_VERSION="0.18.0" && \
    wget --no-check-certificate https://github.com/NixOS/patchelf/releases/download/${PATCHELF_VERSION}/patchelf-${PATCHELF_VERSION}.tar.bz2 && \
    tar -xvpf patchelf-${PATCHELF_VERSION}.tar.bz2 && \
    cd patchelf-${PATCHELF_VERSION} && \
    CC="/opt/clang/bin/clang" \
    CXX="/opt/clang/bin/clang++" \
    CPP="/opt/clang/bin/clang++ -E" \
    LDFLAGS="-fuse-ld=lld" \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        ./configure --prefix=/usr/local && \
    setarch "$(gcc -dumpmachine | sed 's|-.*||')" \
        make -j$(getconf _NPROCESSORS_ONLN) && \
    strip --strip-all src/patchelf && \
    cp -a src/patchelf /usr/local/bin/ && \
    cd .. && \
    rm -rf patchelf-${PATCHELF_VERSION}.tar.bz2 patchelf-${PATCHELF_VERSION}
