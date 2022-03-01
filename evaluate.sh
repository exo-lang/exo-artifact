#!/bin/bash

set -e

## Constants

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Exo implementations are not threaded, so force baselines to be single-threaded, too.
num_threads=1
export OPENBLAS_NUM_THREADS=$num_threads
export MKL_NUM_THREADS=$num_threads
export HL_NUM_THREADS=$num_threads
export OMP_NUM_THREADS=$num_threads

# Don't load the Docker virtual environment if one is already loaded.
[ -z "$VIRTUAL_ENV" ] && source /opt/venv/bin/activate

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

./build/x86_demo/sgemm/bench_sgemm --benchmark_filter=exo --benchmark_out=sgemm-exo.json
./build/x86_demo/sgemm/bench_sgemm --benchmark_filter=MKL --benchmark_out=sgemm-mkl.json
./build/x86_demo/sgemm/bench_sgemm_openblas \
  --benchmark_filter=OpenBLAS --benchmark_out=sgemm-openblas.json

./build/x86_demo/conv/bench_conv --benchmark_filter=102 --benchmark_out=conv.json

## Create graphs

python plot.py \
  -m 'sgemm_(?P<series>\w+)/(?P<n>\d+)' \
  -p flops \
  --title "SGEMM results" \
  -o sgemm.png \
  sgemm-*.json
