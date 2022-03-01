#!/bin/bash

set -e

## Constants

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Exo implementations are not threaded, so
num_threads=1
export OPENBLAS_NUM_THREADS=$num_threads
export MKL_NUM_THREADS=$num_threads
export HL_NUM_THREADS=$num_threads
export OMP_NUM_THREADS=$num_threads

source /opt/venv

## Build apps

cmake -G Ninja -S "${ROOT_DIR}/exo/apps" -B build \
  -DCMAKE_C_COMPILER=clang-13 \
  -DCMAKE_CXX_COMPILER=clang++-13 \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="-march=skylake-avx512" \
  -DCMAKE_CXX_FLAGS="-march=skylake-avx512" \
  -DDNNL_CONFIGURATION=cpu_gomp # Ensure that OMP_NUM_THREADS is respected

cmake --build build

## Run benchmarks

./build/x86_demo/sgemm/bench_sgemm --benchmark_filter=exo
./build/x86_demo/sgemm/bench_sgemm --benchmark_filter=MKL
./build/x86_demo/sgemm/bench_sgemm_openblas --benchmark_filter=OpenBLAS

./build/x86_demo/conv/bench_conv --benchmark_filter=102

## Create graphs

# TODO
