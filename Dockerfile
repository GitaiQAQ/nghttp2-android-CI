FROM gitai/android-standalone-toolchain
MAINTAINER Gitai<i@gitai.me>

ENV PREFIX $ANDROID_HOME/usr/local

ENV OPENSSL_VERSION OpenSSL_1_1_0f
ENV SPDYLAY_VERSION v1.4.0
ENV LIBEV_VERSION 4.19
ENV ZLIB_VERSION 1.2.8
ENV NGHTTP2_VERSION v1.24.0

WORKDIR $ANDROID_HOME
RUN git clone https://github.com/tatsuhiro-t/spdylay -b $SPDYLAY_VERSION --depth 1
RUN git clone https://github.com/openssl/openssl.git -b $OPENSSL_VERSION --depth 1
RUN curl -L -O http://dist.schmorp.de/libev/Attic/libev-$LIBEV_VERSION.tar.gz && \
    curl -L -O https://gist.github.com/tatsuhiro-t/48c45f08950f587180ed/raw/80a8f003b5d1091eae497c5995bbaa68096e739b/libev-4.19-android.patch && \
    tar xf libev-4.19.tar.gz && \
    rm libev-4.19.tar.gz
RUN curl -L -O https://downloads.sourceforge.net/project/libpng/zlib/$ZLIB_VERSION/zlib-$ZLIB_VERSION.tar.gz && \
    tar xf zlib-$ZLIB_VERSION.tar.gz && \
    rm zlib-$ZLIB_VERSION.tar.gz
RUN git clone https://github.com/nghttp2/nghttp2 -b $NGHTTP2_VERSION --depth 1

WORKDIR $ANDROID_HOME/spdylay
RUN autoreconf -i && \
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

WORKDIR $ANDROID_HOME/openssl
RUN export CROSS_COMPILE=$TOOLCHAIN/bin/arm-linux-androideabi- && \
    ./Configure --prefix=$PREFIX android && \
    make && make install_sw

WORKDIR $ANDROID_HOME/libev-$LIBEV_VERSION
RUN patch -p1 < ../libev-4.19-android.patch && \
    ./configure \
    --host=arm-linux-androideabi \
    --build=`dpkg-architecture -qDEB_BUILD_GNU_TYPE` \
    --prefix=$PREFIX \
    --disable-shared \
    --enable-static \
    CPPFLAGS=-I$PREFIX/include \
    LDFLAGS=-L$PREFIX/lib && \
    make install

WORKDIR $ANDROID_HOME/zlib-$ZLIB_VERSION
RUN HOST=arm-linux-androideabi \
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

WORKDIR $ANDROID_HOME/nghttp2
RUN autoreconf -i && \
    ./configure \
    --disable-shared \
    --host=arm-linux-androideabi \
    --build=`dpkg-architecture -qDEB_BUILD_GNU_TYPE` \
    --with-xml-prefix="$PREFIX" \
    --without-libxml2 \
    --disable-python-bindings \
    --disable-examples \
    --disable-threads \
    LIBSPDYLAY_CFLAGS=-I$PREFIX/usr/local/include \
    LIBSPDYLAY_LIBS="-L$PREFIX/usr/local/lib -lspdylay" \
    CPPFLAGS="-fPIE -I$PREFIX/include" \
    CXXFLAGS="-fno-strict-aliasing" \
    PKG_CONFIG_LIBDIR="$PREFIX/lib/pkgconfig" \
    LDFLAGS="-fPIE -pie -L$PREFIX/lib" && \
    make && \
    arm-linux-androideabi-strip src/nghttpx src/nghttpd src/nghttp

