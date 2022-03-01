#!/bin/bash

set -e

## Constants

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

# Terminal colors
RED='\033[0;31m'
NC='\033[0m'

# Exo implementations are not threaded, so force baselines to be single-threaded, too.
num_threads=1
export OPENBLAS_NUM_THREADS=$num_threads
export MKL_NUM_THREADS=$num_threads
export HL_NUM_THREADS=$num_threads
export OMP_NUM_THREADS=$num_threads

# Don't load the Docker virtual environment if one is already loaded.
[ -z "$VIRTUAL_ENV" ] && source /opt/venv/bin/activate

# Detect AVX-512 on host
grep avx512 /proc/cpuinfo >/dev/null && HAS_AVX512=1 || HAS_AVX512=0

# Determine whether to run under SDE
if [ "$HAS_AVX512" -eq 1 ]; then
  SDE=""
else
  echo -ne "${RED}"
  echo "** WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING **"
  echo "*                                                                           *"
  echo "*                      EXO PLDI 2022 Artifact Warning                       *"
  echo "*                                                                           *"
  echo "*               Your CPU does not appear to support AVX512                  *"
  echo "*     Benchmarks will run under SDE. See README.md for more information     *"
  echo "*                                                                           *"
  echo "** WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING **"
  echo -ne "${NC}"
  echo
  sleep 3
  SDE="sde64 -skx -env OPENBLAS_CORETYPE SkylakeX -- "
fi

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

$SDE ./build/x86_demo/sgemm/bench_sgemm \
  --benchmark_filter=exo --benchmark_out=sgemm-exo.json
$SDE ./build/x86_demo/sgemm/bench_sgemm \
  --benchmark_filter=MKL --benchmark_out=sgemm-mkl.json
$SDE ./build/x86_demo/sgemm/bench_sgemm_openblas \
  --benchmark_filter=OpenBLAS --benchmark_out=sgemm-openblas.json

$SDE ./build/x86_demo/conv/bench_conv \
  --benchmark_filter=102 --benchmark_out=conv.json

## Create graphs

python plot.py \
  -m 'sgemm_(?P<series>\w+)/(?P<n>\d+)' \
  -p flops \
  --title "SGEMM results" \
  -o sgemm.png \
  sgemm-*.json

if [ "$HAS_AVX512" -eq 0 ]; then
  echo
  echo -ne "${RED}"
  echo "** WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING **"
  echo "*                                                                           *"
  echo "*                      EXO PLDI 2022 Artifact Warning                       *"
  echo "*                                                                           *"
  echo "*                Your CPU does not appear to support AVX512                 *"
  echo "*        Benchmarks were run under SDE. Plots will not be accurate.         *"
  echo "*                    See README.md for more information                     *"
  echo "*                                                                           *"
  echo "** WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING WARNING **"
  echo -ne "${NC}"
  echo
fi
