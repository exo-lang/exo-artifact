#include <stdio.h>
#include "avx2_matmul.h"
#include "orig_matmul.h"
#include <time.h>

#define K 2048
static float A[6 * K];
static float B[K * 16];
static float C[6 * 16];

void initialize() {
  for (int i=0; i<6; i++) {
    for (int j=0; j<K; j++) {
      A[i*K+j] = 3.2;
    }
  }
  for (int i=0; i<K; i++) {
    for (int j=0; j<16; j++) {
      B[i*16+j] = 0.2;
    }
  }
  for (int i=0; i<6; i++) {
    for (int j=0; j<16; j++) {
      C[i*16+j] = 0.0;
    }
  }
  return;
}

int main() {
  orig_matmul_Context *c1;
  avx2_matmul_Context *c2;
  clock_t start, end;
  int msec;

  // Calling original matmul
  start = clock();
  for (int i=0; i<1000; i++)
    rank_k_reduce_6x16(c1, K, C, A, B);
  end = clock();

  msec = (end-start) * 1000 / CLOCKS_PER_SEC;
  printf("Time taken for original matmul: %d seconds %d milliseconds\n", msec/1000, msec%1000);

  // Calling scheduled matmul
  start = clock();
  for (int i=0; i<1000; i++)
    rank_k_reduce_6x16_scheduled(c2, K, C, A, B);
  end = clock();

  msec = (end-start) * 1000 / CLOCKS_PER_SEC;
  printf("Time taken for scheduled matmul: %d seconds %d milliseconds\n", msec/1000, msec%1000);

  return(0);
}
