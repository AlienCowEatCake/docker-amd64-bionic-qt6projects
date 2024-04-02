FROM ubuntu:18.04

RUN groupadd --gid 1000 user && \
    useradd --shell /bin/bash --home-dir /home/user --uid 1000 --gid 1000 --create-home user

RUN export DEBIAN_FRONTEND=noninteractive && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        wget build-essential fakeroot debhelper curl gawk chrpath git openssh-client p7zip-full libssl-dev \
        "^libxcb.*-dev" libxkbcommon-dev libxkbcommon-x11-dev libx11-xcb-dev libglu1-mesa-dev libxrender-dev libxi-dev \
        libdbus-1-dev libglib2.0-dev libfreetype6-dev libcups2-dev mesa-common-dev libgl1-mesa-dev libegl1-mesa-dev \
        libxcursor-dev libxcomposite-dev libxdamage-dev libxrandr-dev libfontconfig1-dev libxss-dev libxtst-dev \
        libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev libgstreamer-plugins-good1.0-dev libgstreamer-plugins-bad1.0-dev \
        libpulse-dev libasound2-dev libjack-dev libva-dev libopenal-dev libbluetooth-dev libspeechd-dev \
        libgtk-3-dev libgtk2.0-dev gperf bison ruby flex yasm libwayland-dev libwayland-egl-backend-dev \
        flite1-dev libvulkan-dev gcc-8 g++-8 && \
    apt-get clean

WORKDIR /usr/src

ENV PATH="/opt/clang/bin:${PATH}"
ENV LD_LIBRARY_PATH="/opt/clang/lib:/opt/qt6/lib"
ENV LANG="C.UTF-8"

RUN export CMAKE_VERSION="3.29.0" && \
    wget --no-check-certificate https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}.tar.gz && \
    tar -xvpf cmake-${CMAKE_VERSION}.tar.gz && \
    cd cmake-${CMAKE_VERSION} && \
    ./configure --prefix=/opt/cmake --no-qt-gui --parallel=$(getconf _NPROCESSORS_ONLN) && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    ln -s /opt/cmake/bin/cmake /usr/local/bin/ && \
    ln -s /opt/cmake/bin/ctest /usr/local/bin/ && \
    ln -s /opt/cmake/bin/cpack /usr/local/bin/ && \
    cd .. && \
    rm -rf cmake-${CMAKE_VERSION}.tar.gz cmake-${CMAKE_VERSION}

RUN export NINJA_VERSION="1.11.1" && \
    wget --no-check-certificate https://github.com/ninja-build/ninja/archive/refs/tags/v${NINJA_VERSION}.tar.gz && \
    tar -xvpf v${NINJA_VERSION}.tar.gz && \
    cd ninja-${NINJA_VERSION} && \
    cmake -S . -B build \
        -G "Unix Makefiles" \
        -DCMAKE_BUILD_TYPE=Release && \
    cmake --build build --target ninja -- -j$(getconf _NPROCESSORS_ONLN) && \
    strip --strip-all build/ninja && \
    cp -a build/ninja /usr/local/bin/ && \
    cd .. && \
    rm -rf v${NINJA_VERSION}.tar.gz ninja-${NINJA_VERSION}

RUN export CLANG_VERSION="18.1.2" && \
    wget --no-check-certificate https://github.com/llvm/llvm-project/archive/refs/tags/llvmorg-${CLANG_VERSION}.tar.gz && \
    tar -xvpf llvmorg-${CLANG_VERSION}.tar.gz && \
    cd llvm-project-llvmorg-${CLANG_VERSION} && \
    sed -i 's|\(virtual unsigned GetDefaultDwarfVersion() const { return \)5;|\14;|' clang/include/clang/Driver/ToolChain.h && \
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
        -DCMAKE_INSTALL_PREFIX="/opt/clang" && \
    cmake --build build --target all && \
    cmake --install build --prefix "/opt/clang" && \
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
        -DCMAKE_INSTALL_PREFIX="/opt/clang" && \
    cmake --build build_runtimes --target cxx cxxabi unwind && \
    cmake --build build_runtimes --target install-cxx install-cxxabi install-unwind && \
    cd .. && \
    rm -rf llvmorg-${CLANG_VERSION}.tar.gz llvm-project-llvmorg-${CLANG_VERSION}

RUN export XCB_PROTO_VERSION="1.16.0" && \
    export LIBXCB_VERSION="1.16.1" && \
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
    ./configure --prefix=/opt/xcb PYTHON=python3 && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/libxcb-${LIBXCB_VERSION}.tar.xz && \
    tar -xvpf libxcb-${LIBXCB_VERSION}.tar.xz && \
    cd libxcb-${LIBXCB_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen --enable-ge --enable-xevie --enable-xprint --enable-selinux PKG_CONFIG_PATH=/opt/xcb/share/pkgconfig CFLAGS="-O3 -DNDEBUG" PYTHON=python3 && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-${XCB_UTIL_VERSION}.tar.xz && \
    tar -xvpf xcb-util-${XCB_UTIL_VERSION}.tar.xz && \
    cd xcb-util-${XCB_UTIL_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-image-${XCB_UTIL_IMAGE_VERSION}.tar.xz && \
    tar -xvpf xcb-util-image-${XCB_UTIL_IMAGE_VERSION}.tar.xz && \
    cd xcb-util-image-${XCB_UTIL_IMAGE_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION}.tar.xz && \
    tar -xvpf xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION}.tar.xz && \
    cd xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION}.tar.xz && \
    tar -xvpf xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION}.tar.xz && \
    cd xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-wm-${XCB_UTIL_WM_VERSION}.tar.xz && \
    tar -xvpf xcb-util-wm-${XCB_UTIL_WM_VERSION}.tar.xz && \
    cd xcb-util-wm-${XCB_UTIL_WM_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION}.tar.xz && \
    tar -xvpf xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION}.tar.xz && \
    cd xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/lib/pkgconfig CFLAGS="-O3 -DNDEBUG" && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    wget --no-check-certificate https://xorg.freedesktop.org/archive/individual/lib/xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}.tar.xz && \
    tar -xvpf xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}.tar.xz && \
    cd xcb-util-errors-${XCB_UTIL_ERRORS_VERSION} && \
    ./configure --prefix=/opt/xcb --disable-shared --enable-static --with-pic --without-doxygen PKG_CONFIG_PATH=/opt/xcb/share/pkgconfig CFLAGS="-O3 -DNDEBUG" PYTHON=python3 && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    rm -rf xcb-proto-${XCB_PROTO_VERSION}.tar.xz xcb-proto-${XCB_PROTO_VERSION} libxcb-${LIBXCB_VERSION}.tar.xz libxcb-${LIBXCB_VERSION} xcb-util-${XCB_UTIL_VERSION}.tar.xz xcb-util-${XCB_UTIL_VERSION} xcb-util-image-${XCB_UTIL_IMAGE_VERSION}.tar.xz xcb-util-image-${XCB_UTIL_IMAGE_VERSION} xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION}.tar.xz xcb-util-keysyms-${XCB_UTIL_KEYSYMS_VERSION} xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION}.tar.xz xcb-util-renderutil-${XCB_UTIL_RENDERUTIL_VERSION} xcb-util-wm-${XCB_UTIL_WM_VERSION}.tar.xz xcb-util-wm-${XCB_UTIL_WM_VERSION} xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION}.tar.xz xcb-util-cursor-${XCB_UTIL_CURSOR_VERSION} xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}.tar.xz xcb-util-errors-${XCB_UTIL_ERRORS_VERSION}

RUN export OPENSSL_VERSION="3.2.1" && \
    wget --no-check-certificate https://www.openssl.org/source/openssl-${OPENSSL_VERSION}.tar.gz && \
    tar -xvpf openssl-${OPENSSL_VERSION}.tar.gz && \
    cd openssl-${OPENSSL_VERSION} && \
    ./Configure linux-$(gcc -dumpmachine | sed 's|-.*||' | sed 's|^i686$|x86| ; s|^arm$|armv4| ; s|^powerpc64le$|ppc64le|') --prefix=/opt/openssl --openssldir=/etc/ssl zlib no-shared && \
    make depend && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd .. && \
    rm -rf openssl-${OPENSSL_VERSION}.tar.gz openssl-${OPENSSL_VERSION}

RUN export QT_VERSION="6.6.3" && \
    export GHCFS_VERSION="1.5.14" && \
    wget --no-check-certificate --tries=1 https://download.qt.io/archive/qt/$(echo ${QT_VERSION} | sed 's|\([0-9]*\.[0-9]*\)\..*|\1|')/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz || \
    wget --no-check-certificate --tries=1 https://qt-mirror.dannhauer.de/archive/qt/$(echo ${QT_VERSION} | sed 's|\([0-9]*\.[0-9]*\)\..*|\1|')/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz || \
    wget --no-check-certificate --tries=1 https://mirror.accum.se/mirror/qt.io/qtproject/archive/qt/$(echo ${QT_VERSION} | sed 's|\([0-9]*\.[0-9]*\)\..*|\1|')/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz || \
    wget --no-check-certificate --tries=1 https://www.nic.funet.fi/pub/mirrors/download.qt-project.org/archive/qt/$(echo ${QT_VERSION} | sed 's|\([0-9]*\.[0-9]*\)\..*|\1|')/${QT_VERSION}/single/qt-everywhere-src-${QT_VERSION}.tar.xz && \
    tar -xvpf qt-everywhere-src-${QT_VERSION}.tar.xz && \
    cd qt-everywhere-src-${QT_VERSION} && \
    wget --no-check-certificate https://github.com/gulrak/filesystem/releases/download/v${GHCFS_VERSION}/filesystem.hpp -O qtbase/src/tools/syncqt/filesystem.hpp && \
    sed -i 's|std::filesystem|ghc::filesystem|g ; s|<filesystem>|"filesystem.hpp"|' qtbase/src/tools/syncqt/main.cpp && \
    echo 'target_link_libraries(XcbQpaPrivate PRIVATE XCB::UTIL -lXau -lXdmcp)' >> qtbase/src/plugins/platforms/xcb/CMakeLists.txt && \
    echo 'target_link_libraries(Network PRIVATE ${CMAKE_DL_LIBS})' >> qtbase/src/network/CMakeLists.txt && \
    sed -i 's|\(#ifdef Q_OS_VXWORKS\)|#if 1 //\1|' qtbase/src/corelib/global/qxpfunctional.h && \
    mkdir build && \
    cd build && \
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
        -pulseaudio -gstreamer yes \
        -- -Wno-dev -DOpenGL_GL_PREFERENCE=LEGACY \
        -DQT_FEATURE_optimize_full=ON -DQT_FEATURE_clangcpp=OFF -DQT_FEATURE_clang=OFF -DQT_FEATURE_ffmpeg=OFF \
        -DCMAKE_PREFIX_PATH="/opt/openssl;/opt/xcb" -DQT_FEATURE_openssl_linked=ON -DQT_FEATURE_xkbcommon_x11=ON -DTEST_xcb_syslibs=ON \
        && \
    cmake --build . --parallel && \
    cmake --install . && \
    cd ../.. && \
    rm -rf qt-everywhere-src-${QT_VERSION}.tar.xz qt-everywhere-src-${QT_VERSION}

RUN export QT6GTK2_VERSION="0.2" && \
    wget --no-check-certificate https://github.com/trialuser02/qt6gtk2/releases/download/${QT6GTK2_VERSION}/qt6gtk2-${QT6GTK2_VERSION}.tar.xz && \
    tar -xvpf qt6gtk2-${QT6GTK2_VERSION}.tar.xz && \
    cd qt6gtk2-${QT6GTK2_VERSION} && \
    mkdir build && \
    cd build && \
    /opt/qt6/bin/qmake -r CONFIG+=release ../qt6gtk2.pro && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd ../.. && \
    rm -rf qt6gtk2-${QT6GTK2_VERSION}.tar.xz qt6gtk2-${QT6GTK2_VERSION}

RUN export QT6CT_VERSION="0.9" && \
    wget --no-check-certificate https://github.com/trialuser02/qt6ct/releases/download/${QT6CT_VERSION}/qt6ct-${QT6CT_VERSION}.tar.xz && \
    tar -xvpf qt6ct-${QT6CT_VERSION}.tar.xz && \
    cd qt6ct-${QT6CT_VERSION} && \
    mkdir build && \
    cd build && \
    /opt/qt6/bin/qmake -r CONFIG+=release ../qt6ct.pro && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    make install && \
    cd ../.. && \
    rm -rf qt6ct-${QT6CT_VERSION}.tar.xz qt6ct-${QT6CT_VERSION}

RUN export ADWAITA_QT_COMMIT="0a774368916def5c9889de50f3323dec11de781e" && \
    wget --no-check-certificate https://github.com/FedoraQt/adwaita-qt/archive/${ADWAITA_QT_COMMIT}.tar.gz && \
    tar -xvpf ${ADWAITA_QT_COMMIT}.tar.gz && \
    cd adwaita-qt-${ADWAITA_QT_COMMIT} && \
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
    cmake --build build --target all && \
    cmake --install build && \
    cd .. && \
    rm -rf ${ADWAITA_QT_COMMIT}.tar.gz adwaita-qt-${ADWAITA_QT_COMMIT}

RUN export QGNOMEPLATFORM_VERSION="0.9.2" && \
    wget --no-check-certificate https://github.com/FedoraQt/QGnomePlatform/archive/refs/tags/${QGNOMEPLATFORM_VERSION}.tar.gz && \
    tar -xvpf ${QGNOMEPLATFORM_VERSION}.tar.gz && \
    cd QGnomePlatform-${QGNOMEPLATFORM_VERSION} && \
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
    cmake --build build --target all && \
    cmake --install build && \
    cd .. && \
    rm -rf ${QGNOMEPLATFORM_VERSION}.tar.gz QGnomePlatform-${QGNOMEPLATFORM_VERSION}

RUN export QADWAITA_DECORATIONS_COMMIT="8f7357cf57b46216160cd3dc1f09f02a05fed172" && \
    wget --no-check-certificate https://github.com/FedoraQt/QAdwaitaDecorations/archive/${QADWAITA_DECORATIONS_COMMIT}.tar.gz && \
    tar -xvpf ${QADWAITA_DECORATIONS_COMMIT}.tar.gz && \
    cd QAdwaitaDecorations-${QADWAITA_DECORATIONS_COMMIT} && \
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
    cmake --build build --target all && \
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

RUN export LINUXDEPLOYQT_COMMIT="2b38449ca9e9c68ad53e28531c017910ead6ebc4" && \
    git -c http.sslVerify=false clone https://github.com/probonopd/linuxdeployqt.git linuxdeployqt && \
    cd linuxdeployqt && \
    git checkout -f ${LINUXDEPLOYQT_COMMIT} && \
    git clean -dfx && \
    sed -i 's|^\(find_package(QT NAMES.*\)$|\1\nfind_package(Qt${QT_VERSION_MAJOR} REQUIRED COMPONENTS Core)|' tools/linuxdeployqt/CMakeLists.txt && \
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
    LDFLAGS="-static -fuse-ld=lld" \
    ./configure --prefix=/usr/local && \
    make -j$(getconf _NPROCESSORS_ONLN) && \
    strip --strip-all src/patchelf && \
    cp -a src/patchelf /usr/local/bin/ && \
    cd .. && \
    rm -rf patchelf-${PATCHELF_VERSION}.tar.bz2 patchelf-${PATCHELF_VERSION}
