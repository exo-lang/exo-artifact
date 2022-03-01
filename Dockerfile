FROM ubuntu:20.04

## Set up environment for evaluation
WORKDIR /app
ENV CC=clang-13
ENV CXX=clang++-13

## Install APT dependencies
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles
RUN apt-get update &&  \
    apt-get install -y wget gnupg && \
    echo "deb https://apt.llvm.org/focal/ llvm-toolchain-focal-13 main" >> /etc/apt/sources.list.d/llvm.list && \
    wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | apt-key add - && \
    wget -O - https://apt.kitware.com/keys/kitware-archive-latest.asc 2>/dev/null | gpg --dearmor - | tee /usr/share/keyrings/kitware-archive-keyring.gpg >/dev/null && \
    echo 'deb [signed-by=/usr/share/keyrings/kitware-archive-keyring.gpg] https://apt.kitware.com/ubuntu/ focal main' | tee /etc/apt/sources.list.d/kitware.list >/dev/null && \
    wget -O - https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null && \
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | tee /etc/apt/sources.list.d/oneAPI.list && \
    apt-get update && \
    apt-get install -y \
      python3.9 \
      python3.9-venv \
      clang-13 \
      clang++-13 \
      cmake \
      ninja-build \
      intel-oneapi-dnnl-devel \
      intel-oneapi-mkl-devel \
      libopenblas-dev \
      libpng-dev \
      libjpeg-dev \
      pkg-config \
    && \
    rm -rf /var/lib/apt/lists/*

## Download and install Halide 13.0.4
RUN wget -q https://github.com/halide/Halide/releases/download/v13.0.4/Halide-13.0.4-x86-64-linux-3a92a3f95b86b7babeed7403a330334758e1d644.tar.gz && \
    tar xvf Halide*.tar.gz -C /usr/local --exclude="Halide-13.0.4-x86-64-linux/share/doc" --strip-components=1 && \
    rm Halide*.tar.gz

## Build virtual environment for Exo
RUN python3.9 -m venv /opt/venv && \
    . /opt/venv/bin/activate && \
    python -m pip install -U setuptools pip wheel && \
    python -m pip install -U build && \
    rm -rf /root/.cache

## Copy local files into image
COPY . .

## Build and install Exo
RUN . /opt/venv/bin/activate && \
    python -m pip install -r requirements.txt && \
    cd exo && \
    python -m build --sdist --wheel --outdir dist/ . && \
    python -m pip install dist/*.whl && \
    rm -rf build dist /root/.cache

## Build and install exo's bundled dependencies
RUN cmake -G Ninja -S exo/dependencies/benchmark -B build \
      -DCMAKE_BUILD_TYPE=Release \
      -DBENCHMARK_ENABLE_TESTING=NO \
      -DCMAKE_INSTALL_PREFIX="/usr/local" \
    && \
    cmake --build build --target install && \
    rm -rf build
