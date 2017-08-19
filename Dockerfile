# vim: ft=dockerfile:
# Dockerfile to build nghttp2 android binary
#
# $ sudo docker build -t nghttp2-android - < Dockerfile.android
#
# After successful build, android binaries and libraries are located
# under `/root/usr/local`.  You can copy the binary using docker `cp`.
# For example, to copy nghttpx binary to host file system location
# /path/to/dest, do this:
#
# $ sudo docker cp nghttp2-android:/root/usr/local/bin/nghttpx /path/to/dest

# Only use standalone-toolchain for reduce size
FROM gitai/android-standalone-toolchain
MAINTAINER Gitai<i@gitai.me>

ENV PREFIX $ANDROID_HOME/usr/local
ENV CROSS_SYSROOT $TOOLCHAIN/sysroot


# Setup version of libraries
ENV OPENSSL_VERSION OpenSSL_1_1_0f
ENV SPDYLAY_VERSION v1.4.0
ENV LIBEV_VERSION 4.19
ENV ZLIB_VERSION 1.2.8
ENV CARES_VERSION 1.13.0
ENV NGHTTP2_VERSION v1.24.0


# Download all libraries in the same layer as cache.
WORKDIR $ANDROID_HOME
RUN git clone https://github.com/tatsuhiro-t/spdylay -b $SPDYLAY_VERSION --depth 1 && \
    git clone https://github.com/openssl/openssl.git -b $OPENSSL_VERSION --depth 1 && \
    curl -L -O http://dist.schmorp.de/libev/Attic/libev-$LIBEV_VERSION.tar.gz && \
    curl -L -O https://gist.github.com/tatsuhiro-t/48c45f08950f587180ed/raw/80a8f003b5d1091eae497c5995bbaa68096e739b/libev-4.19-android.patch && \
    tar xf libev-$LIBEV_VERSION.tar.gz && \
    rm libev-$LIBEV_VERSION.tar.gz && \
    curl -L -O https://downloads.sourceforge.net/project/libpng/zlib/$ZLIB_VERSION/zlib-$ZLIB_VERSION.tar.gz && \
    tar xf zlib-$ZLIB_VERSION.tar.gz && \
    rm zlib-$ZLIB_VERSION.tar.gz && \
    curl -L -O https://c-ares.haxx.se/download/c-ares-$CARES_VERSION.tar.gz && \
    tar xf c-ares-$CARES_VERSION.tar.gz && \
    rm c-ares-$CARES_VERSION.tar.gz && \
    git clone https://github.com/nghttp2/nghttp2 -b $NGHTTP2_VERSION --depth 1

RUN cd $ANDROID_HOME/spdylay && \
    autoreconf -i && \
    ./configure \
      --disable-shared \
      --host=arm-linux-androideabi \
      --build=`dpkg-architecture -qDEB_BUILD_GNU_TYPE` \
      --prefix=$PREFIX \
      --without-libxml2 \
      --disable-src \
      --disable-examples \
      CPPFLAGS="-I$PREFIX/include" \
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig" \
      LDFLAGS="-L$PREFIX/lib" && \
    make install

RUN cd $ANDROID_HOME/openssl && \
    export CROSS_COMPILE=$TOOLCHAIN/bin/arm-linux-androideabi- && \
    ./Configure --prefix=$PREFIX android && \
    make install_sw

RUN cd $ANDROID_HOME/libev-$LIBEV_VERSION && \
    patch -p1 < ../libev-4.19-android.patch && \
    ./configure \
      --host=arm-linux-androideabi \
      --build=`dpkg-architecture -qDEB_BUILD_GNU_TYPE` \
      --prefix=$PREFIX \
      --disable-shared \
      --enable-static \
      CPPFLAGS=-I$PREFIX/include \
      LDFLAGS=-L$PREFIX/lib && \
    make install

RUN cd $ANDROID_HOME/zlib-$ZLIB_VERSION && \ 
    HOST=arm-linux-androideabi \
    CC=$HOST-gcc \
    AR=$HOST-ar \
    LD=$HOST-ld \
    RANLIB=$HOST-ranlib \
    STRIP=$HOST-strip \
    ./configure \
      --prefix=$PREFIX \
      --libdir=$PREFIX/lib \
      --includedir=$PREFIX/include \
      --static && \
    make install

RUN cd $ANDROID_HOME/c-ares-$CARES_VERSION && \
    ./configure \
      --host=arm-linux-androideabi \
      --build=`dpkg-architecture -qDEB_BUILD_GNU_TYPE` \
      --prefix=$PREFIX \
      --disable-shared && \
    make install

RUN cd $ANDROID_HOME/nghttp2 && \
    autoreconf -i && \
    ./configure \
      --prefix=$PREFIX \
      --enable-app \
      --disable-shared \
      --host=arm-linux-androideabi \
      --build=`dpkg-architecture -qDEB_BUILD_GNU_TYPE` \
      --with-xml-prefix="$PREFIX" \
      --without-libxml2 \
      --disable-python-bindings \
      --disable-examples \
      --disable-threads \
      CC="$TOOLCHAIN"/bin/arm-linux-androideabi-clang \
      CXX="$TOOLCHAIN"/bin/arm-linux-androideabi-clang++ \
      CPPFLAGS="-fPIE -I$PREFIX/include" \
      PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig" \
      LDFLAGS="-fPIE -pie -L$PREFIX/lib" && \
    make install && \
    arm-linux-androideabi-strip $ANDROID_HOME/usr/local/bin/nghttp* $ANDROID_HOME/usr/local/bin/h2load $ANDROID_HOME/usr/local/bin/openssl
