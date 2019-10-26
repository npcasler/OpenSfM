ARG ALPINE_VERSION=3.10
FROM osgeo/gdal:alpine-normal-latest AS build

MAINTAINER Nathan Casler <ncasler@solspec.io>

WORKDIR /tmp

ENV CERES_VERSION=1.14.0 \
    OPENCV_VERSION=4.0.1

RUN echo "@edgetesting http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories  && \
    echo "@edgecommunity http://dl-cdn.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && apk add --upgrade --no-cache \
        build-base \
        cmake \
        curl \
        eigen-dev \
        git \
        openblas-dev \
        gflags-dev@edgecommunity \
        glog-dev@edgetesting \
        jpeg-dev \
        linux-headers \
        python3-dev \
        py3-pip \
        zlib-dev


RUN pip3 install -U pip && \
    pip3 install numpy==1.16.5 \
    exifread \
    joblib \
    setuptools \
    six \
    pillow \
    networkx \
    repoze.lru \
    wheel \
    pyproj \
    pyyaml \
    scipy \
    xmltodict


RUN mkdir /tmp/opencv \
    && curl -sfL https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.tar.gz | tar zxf - -C /tmp/opencv --strip-components=1 \
    && cd /tmp/opencv && mkdir build && cd build \
    && cmake -DWITH_TIFF=ON \
             -DWITH_CUDA=OFF \
             -DWITH_OPENGL=OFF \
             -DWITH_OPENCL=ON \
             -DWITH_IPP=OFF \
             -DWITH_TBB=OFF \
             -DWITH_EIGEN=ON \
             -DWITH_V4L=OFF \
             -DWITH_FFMPEG=OFF \
             -DWITH_OPENNI=OFF \
             -DWITH_VTK=OFF \
             -DBUILD_opencv_java=OFF \
             -DBUILD_TESTS=OFF \
             -DBUILD_PERF_TESTS=OFF \
             -DCMAKE_BUILD_TYPE=Release \
             -DOPENCV_ENABLE_NONFREE=ON \
             -DPYTHON3_EXECUTABLE=$(which python3) \
             -DPYTHON3_INCLUDE_DIR=$(python3 -c "from distutils.sysconfig import get_python_inc; print(get_python_inc())") \
             -DPYTHON3_PACKAGES_PATH=$(python3 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
        .. \
    && make -j $(nproc) install \
    && rm -rf /tmp/opencv

RUN mkdir /tmp/ceres \
    && curl -sfL http://ceres-solver.org/ceres-solver-${CERES_VERSION}.tar.gz | tar zxf - -C /tmp/ceres --strip-components=1 \
    && cd /tmp/ceres && mkdir build && cd build \
    && cmake .. \
        -DCMAKE_C_FLAGS=-fPIC \
        -DCMAKE_CXX_FLAGS=-fPIC \
        -DBUILD_EXAMPLES=OFF \
        -DBUILD_TESTING=OFF \
    && make -j $(nproc) install \
    && rm -rf /tmp/ceres

RUN cd /tmp \
    && git clone https://github.com/paulinus/opengv.git \
    && cd opengv \
    && git submodule update --init --recursive \
    && mkdir -p build && cd build \
    && cmake \
        -DBUILD_TESTS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_PYTHON=ON \
        -DPYBIND11_PYTHON_VERSION=3.6 \
        -DHAS_FLTO=OFF \
        -DPYTHON_INSTALL_DIR=$(python3 -c "from distutils.sysconfig import get_python_lib; print(get_python_lib())") \
        .. \
    && make -j $(nproc) install \
    && rm -rf /tmp/opengv

COPY . /tmp/OpenSFM
RUN cd /tmp/OpenSFM \
    && ls -a . \
    && git submodule update --init --recursive \
    && python3 setup.py build \
    && python3 setup.py install \
    && cp bin/* /usr/bin/ \
    && ln -sf python3 /usr/bin/python
