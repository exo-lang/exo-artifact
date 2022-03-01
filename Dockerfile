FROM ubuntu:20.04

## Installing dependencies
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
      intel-hpckit \
    && \
    python3.9 -m pip install -U setuptools pip wheel && \
    python3.9 -m pip install -U build

# Set application directory and environment variables for evaluation
WORKDIR /app
ENV CC=clang-13
ENV CXX=clang++-13

## Copy local files into image
COPY . .

## Build and install exo-lang
RUN cd exo && \
    python3.9 -m build --sdist --wheel --outdir dist/ . && \
    python3.9 -m pip install dist/*.whl
