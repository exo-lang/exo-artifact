from __future__ import annotations

import itertools

import numpy as np
import pytest

from exo import proc
from exo.platforms.x86 import *

def gen_rank_k_reduce_6x16():
    @proc
    def rank_k_reduce_6x16(
            K: size,
            C: [f32][6, 16] @ DRAM,
            A: [f32][6, K] @ DRAM,
            B: [f32][K, 16] @ DRAM,
    ):
        for i in par(0, 6):
            for j in par(0, 16):
                for k in par(0, K):
                    C[i, j] += A[i, k] * B[k, j]

    avx = rank_k_reduce_6x16.rename("rank_k_reduce_6x16_scheduled")
    avx = avx.stage_assn('C_reg', 'C[_] += _')
    avx = avx.set_memory('C_reg', AVX2)
    avx = avx.split('j', 8, ['jo', 'ji'], perfect=True)
    avx = avx.reorder('ji', 'k')
    avx = avx.reorder('jo', 'k')
    avx = avx.reorder('i', 'k')
    avx = avx.lift_alloc('C_reg:_', n_lifts=3)
    avx = avx.fission_after('C_reg = _ #0', n_lifts=3)
    avx = avx.fission_after('C_reg[_] += _ #0', n_lifts=3)
    avx = avx.par_to_seq('for k in _:_')
    avx = avx.lift_alloc('C_reg:_', n_lifts=1)
    avx = avx.fission_after('for i in _:_#0', n_lifts=1)
    avx = avx.fission_after('for i in _:_#1', n_lifts=1)
    avx = avx.simplify()

    return avx, rank_k_reduce_6x16


def gen_sgemm_6x16_avx():
    avx2_sgemm_6x16, rank_k_reduce_6x16 = gen_rank_k_reduce_6x16()

    avx2_sgemm_6x16 = (
        avx2_sgemm_6x16
            .bind_expr('a_vec', 'A[i, k]')
            .set_memory('a_vec', AVX2)
            .lift_alloc('a_vec:_', keep_dims=True)
            .fission_after('a_vec[_] = _')
            #
            .bind_expr('b_vec', 'B[k, _]')
            .set_memory('b_vec', AVX2)
            .lift_alloc('b_vec:_', keep_dims=True)
            .fission_after('b_vec[_] = _')
            #
            .replace_all(avx2_set0_ps)
            .replace_all(mm256_broadcast_ss)
            .replace_all(mm256_fmadd_ps)
            .replace_all(avx2_fmadd_memu_ps)
            .replace(mm256_loadu_ps, 'for ji in _:_ #0')
            .replace(mm256_loadu_ps, 'for ji in _:_ #0')
            .replace(mm256_storeu_ps, 'for ji in _:_ #0')
            #
            .unroll('jo')
            .unroll('i')
            #
            .simplify()
    )

    return rank_k_reduce_6x16, avx2_sgemm_6x16


print(gen_sgemm_6x16_avx())

