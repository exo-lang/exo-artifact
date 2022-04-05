# PLDI 2022 Artifact Evaluation for Exo

Here is the instruction for the **reusable** artifact evaluation for Exo.
For the reusable badge, we understood that the artifact should meet the following criteria:
1. Can be run locally
2. Very well documented
3. Able to make changes

Please refer to each section in this document to find the procedure to evaluate each criteria.

Please refer to `functional.md` for the previous functional artifact evaluation procedure.

## 1. Can be run locally

Exo is published on PyPI and can be installed locally via pip with the following command. Throughout this evaluation, reviewers do not need to download Zenodo or run docker.

```
$ pip install exo-lang
```

## 2. Very well documented

### Documentation for Exo folder structure

In [Exo repository](https://github.com/ChezJrk/exo), folders are structured as follows:
1. `src/exo` is where all the core Exo implementation resides.
   - `API.py` defines all the Exo API exposed to the user. Documentation of the API can be found in the section below.
   - `libs/` includes user-defined memory definitions (`memories.py`) and the custom malloc implementations.
   - `platforms/` includes user-defined instruction definitions that are part of the release.
   - Other files are the core implementation of Exo (e.g., `typecheck.py` implements typecheck), but will not explain here as they are not exposed to users.
2. `apps/` includes user-level application code using Exo.
3. `dependencies/` includes submodules that Exo depends on.
4. `examples/` includes Python notebook that we used for Demo.
5. `tests/` includes unit tests.

### Documentation for scheduling API

#### Top-level Python function decorator
1. `@proc`  decorated Python function is parsed and compiled as Exo language. Returns a `Procedure` object.
2. `@instr` is the same as `@proc`,  but takes a hardware instruction as a formatted string.
3. `@config` decorates a Python class which is parsed and compile as Exo configuration object 

#### Procedure object methods
**Introspection operations**
- `.name()` returns the procedure name.
- `.check_effects()` forces Exo to run the effect check on the procedure.
- `.show_effects()` prints the effects of the procedure.
- `.show_effect(stmt)` prints the effect of the `stmt` in the procedure.
- `.is_instr()` returns `true` if the procedure has a hardware instruction string.
- `.get_instr()` returns the hardware instruction string.
- `.get_ast()` returns `QAST`, which is an introspection AST representation.

**Execution / interpretation operations**
- `.compile_c(directory, filename)` compiles the procedure into C and stores in `filename` in the `directory`.
- `.interpret(**args)` runs Exo interpreter on the procedure.

#### Scheduling operations on Procedure objects
**Buffer related operations**
| Operation | Description |
| --- | --- |
|`.data_reuse(buf1, buf2)` | Reuses a buffer `buf1` in the use site of `buf2` and removes the allocation of `buf2`.|
|`.inline_window(win_stmt)` | Removes the window statement `win_stmt`, which is an alias to the window, and inline the windowing in its use site.|
|`.expand_dim(stmt, alloc_dim, indexing)` | Expands the dimension of the allocation statement `stmt` with dimension `alloc_dim` of indexing `indexing`.|
|`.bind_expr(new_name, expr)` | Binds the right hand side expression `expr` with the `new_name`, allocating a new buffer for the `new_name`.|
|`.stage_mem(win_expr, new_name, stmt_start, stmt_end=None)` | Stages the buffer `win_expr` to the new window expression `new_name` in statement block (`stmt_start` to `stmt_end`), and add an initilization loop and a writeback loop.|
|`.stage_assn(new_name, stmt)` | Binds the left hand side expression of `stmt` with the `new_name`, allocating a new buffer for the `new_name`.|
|`.rearrange_dim(alloc, dimensions)` | Takes an allocation statement and a list of integer to map the dimension. It rearranges the dimension of `alloc` in `dimension` order. E.g., if `alloc` was `foo[N,M,K]` and the `dimension` was `[2,0,1]`, it will be `foo[K,N,M]` after this operation.|
|`.lift_alloc(alloc, n_lifts=1, keep_dims=False)` | Lifts the allocation statement `alloc` out of `n_lifts` number of scopes. If and For statements are the only statements in Exo which introduce a scope. When lifting the allocation out of the for loop, it will expand its dimension to the loop bound if `keep_dims` is True. |

**Loop related operations**
| Operation | Description |
| --- | --- |
|`.split(loop, split_const, iter_vars, tail='guard', perfect=False)`| Splits the loop of `loop` into an outer and an inner loop. Inner loop bound is `split_const` and outer and inner loop names are specified by a list of strings `iter_vars`. If `perfect` is True, it will not introduce a tail case. `tail` specifies the tail strategies, where the options are `guard`, `cut`, and `cut_and_guard`. |
|`.fuse_loop(loop1, loop2)`| Fuses two subsequent loops with the same iteration variables. |
|`.partition_loop(loop, num)`| Partitions the loop into two loops, one with `0` to `num` bound and the other with `num` to `iter`'s bound. `iter` loop bound need to be a constant.|
|`.reorder(loop1, loop2)`| Reorder two nested loops. `loop2` should be nested directly inside the `loop1`. `loop1` will be nested inside `loop2` after this operation. |
|`.unroll(loop)`| Unroll the loop. The loop needs to be constant bound.|
|`.fission_after(stmt, n_lifts=1)`| Fission the `n_lifts` number of loops around the `stmt`. The fissioned loops around the `stmt` need to be directly nested with each other and the statements before and after the `stmt` should not have an allocation dependency. |
|`.remove_loop(loop)`| Remove the loop if all the statements in the loop is idempotent.|

**Config related operations**
| Operation | Description |
| --- | --- |
|`.bind_config(expr, config, field)` | Binds the right hand side `expr` with `config`.`field`. It will replace the use site of `expr` with `config`.`field` and introduces a config statement of `config`.`field` = `expr`. |
|`.configwrite_root(config, field, expr)` | Inserts the config statement `config`.`field` = `expr` in the beginning of the procedure. |
|`.configwrite_after(stmt, config, field, expr)` | Inserts the config statement `config`.`field` = `expr` after `stmt`. |
|`.delete_config(stmt)` | Deletes the configuration statement. |

**Other scheduling operations**
| Operation | Description |
| --- | --- |
|`.add_assertion(assertion)` | Adds assertion expression of `assertion` in the procedure. |
|`.lift_if(if, n_lifts=1)` | Lifts the if statement `if` out the `n_lifts` number of scopes. This is similar to `reorder()` operation, but for if statements.|
|`.assert_if(if, bool)` | Asserts that the `if` condition is always True or False. |
|`.delete_pass()` | Deletes the `Pass` statement in the procedure. |
|`.reorder_stmts(stmt1, stmt2)` | Reorder the two subsequent statements `stmt1` and `stmt2`. After this operation, the order will be `stmt2` `stmt1`. |
|`.reorder_before(stmt)` | Reorder the statement `stmt` with a statement above. This is a short hand for `reorder_stmts()`. |
|`.replace(subproc, stmt)` | Replace the statement with the call to `subproc`. This operation is one of our contributions and is explained heavily in the paper. |
|`.replace_all(subproc)` | Replace the statements with the call to `subproc` wherever it can. |
|`.inline(call_site)` | Inline the function call. |
|`.is_eq(another_proc)` | Returns True if `another_proc` is equivalent to the procedure. | 
|`.call_eqv(eqv_proc, call_site)` | Replace the function call statement of `call_site` with a call to equivalent procedure `eqv_proc`. |
|`.repeat(directive, *args)` | Repeat the directive as much as possible. |
|`.simplify()` | Simplify the code in the procedure body. Tries to reduce expressions to constants and eliminate dead branches and loops. Uses branch conditions to simplify expressions inside the branches. |
|`.rename(new_name)` | Rename this procedure to `new_name`. |
|`.make_instr(instr_string)` | Makes this procedure to instruction procedure with `instr_string`. |
|`.partial_eval(*args, **kwargs)` | Specializes this procedure to the arguments. |
|`.set_precision(name, type)` | Sets the precision type of `name` to `type`. |
|`.set_window(name, is_window)` | If `is_window` is True, it sets the buffer `name` to window type, instead of a tensor type. |
|`.set_memory(name, mem_type)` | Sets a buffer `name`'s memory type to `mem_type`. |


## 3. Able to make changes

We provided a sample user code in `examples/x86_matmul.py`. `rank_k_reduce_6x16` is a microkernel for AVX2 SGEMM application.
We chose this application because it is relatively simple but contains all the important scheduling operators.

```
$ python x86_matmul.py
```

### Schedule walk-through

We will try to walk through the scheduling transforms step by step. Without any modification, you will see a simple tri-loop print saying "Original algorithm".
This is the original, simple algorithm that we will start with.
```
Original algorithm:
def rank_k_reduce_6x16(K: size, C: f32[6, 16] @ DRAM, A: f32[6, K] @ DRAM,
                       B: f32[K, 16] @ DRAM):
    for i in seq(0, 6):
        for j in seq(0, 16):
            for k in seq(0, K):
                C[i, j] += A[i, k] * B[k, j]
```

Next, please uncomment the code in the first block. Now, you will see that `C` is staged to a buffer called `C_reg`, which resides in AVX2 register denoted by `@ AVX2`.
```
First block:
def rank_k_reduce_6x16_scheduled(K: size, C: f32[6, 16] @ DRAM,
                                 A: f32[6, K] @ DRAM, B: f32[K, 16] @ DRAM):
    for i in seq(0, 6):
        for j in seq(0, 16):
            for k in seq(0, K):
                C_reg: R @ AVX2
                C_reg = C[i, j]
                C_reg += A[i, k] * B[k, j]
                C[i, j] = C_reg
```

Please uncomment the code in the second block. You will see that the `j` loop is `split` into two loops `jo` and `ji`, and loops are reordered so that the `k` loop becomes outermost.
```
Second block:
def rank_k_reduce_6x16_scheduled(K: size, C: f32[6, 16] @ DRAM,
                                 A: f32[6, K] @ DRAM, B: f32[K, 16] @ DRAM):
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                for ji in par(0, 8):
                    C_reg: R @ AVX2
                    C_reg = C[i, 8 * jo + ji]
                    C_reg += A[i, k] * B[k, 8 * jo + ji]
                    C[i, 8 * jo + ji] = C_reg
```

```
Third block:
def rank_k_reduce_6x16_scheduled(K: size, C: f32[6, 16] @ DRAM,
                                 A: f32[6, K] @ DRAM, B: f32[K, 16] @ DRAM):
    C_reg: R[K + 1, 6, 2, 8] @ AVX2
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                for ji in par(0, 8):
                    C_reg[k, i, jo, ji] = C[i, 8 * jo + ji]
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                for ji in par(0, 8):
                    C_reg[k, i, jo, ji] += A[i, k] * B[k, 8 * jo + ji]
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                for ji in par(0, 8):
                    C[i, 8 * jo + ji] = C_reg[k, i, jo, ji]
```

```
Forth block:
def rank_k_reduce_6x16_scheduled(K: size, C: f32[6, 16] @ DRAM,
                                 A: f32[6, K] @ DRAM, B: f32[K, 16] @ DRAM):
    C_reg: R[K + 1, 6, 2, 8] @ AVX2
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                for ji in par(0, 8):
                    C_reg[k, i, jo, ji] = C[i, 8 * jo + ji]
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                a_vec: R[8] @ AVX2
                for ji in par(0, 8):
                    a_vec[ji] = A[i, k]
                for ji in par(0, 8):
                    C_reg[k, i, jo, ji] += a_vec[ji] * B[k, 8 * jo + ji]
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                for ji in par(0, 8):
                    C[i, 8 * jo + ji] = C_reg[k, i, jo, ji]
```

```
Fifth block:
def rank_k_reduce_6x16_scheduled(K: size, C: f32[6, 16] @ DRAM,
                                 A: f32[6, K] @ DRAM, B: f32[K, 16] @ DRAM):
    C_reg: R[K + 1, 6, 2, 8] @ AVX2
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                for ji in par(0, 8):
                    C_reg[k, i, jo, ji] = C[i, 8 * jo + ji]
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                a_vec: R[8] @ AVX2
                for ji in par(0, 8):
                    a_vec[ji] = A[i, k]
                b_vec: R[8] @ AVX2
                for ji in par(0, 8):
                    b_vec[ji] = B[k, 8 * jo + ji]
                for ji in par(0, 8):
                    C_reg[k, i, jo, ji] += a_vec[ji] * b_vec[ji]
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                for ji in par(0, 8):
                    C[i, 8 * jo + ji] = C_reg[k, i, jo, ji]
```


```
Sixth block:
def rank_k_reduce_6x16_scheduled(K: size, C: f32[6, 16] @ DRAM,
                                 A: f32[6, K] @ DRAM, B: f32[K, 16] @ DRAM):
    C_reg: R[K + 1, 6, 2, 8] @ AVX2
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                mm256_loadu_ps(C_reg[k + 0, i + 0, jo + 0, 0:8],
                               C[i + 0, 8 * jo + 0:8 * jo + 8])
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                a_vec: R[8] @ AVX2
                mm256_broadcast_ss(a_vec, A[i + 0:i + 1, k + 0])
                b_vec: R[8] @ AVX2
                mm256_loadu_ps(b_vec[0:8], B[k + 0, 8 * jo + 0:8 * jo + 8])
                mm256_fmadd_ps(C_reg[k + 0, i + 0, jo + 0, 0:8], a_vec, b_vec)
    for k in par(0, K):
        for i in par(0, 6):
            for jo in par(0, 2):
                mm256_storeu_ps(C[i + 0, 8 * jo + 0:8 * jo + 8],
                                C_reg[k + 0, i + 0, jo + 0, 0:8])
```

Here is the potential modification to this code that you might want to try.
- Modify the original algorithm so that the `k` loop becomes outermost. Adjust the scheduling operations so that the resulting code will be the same as the output of the sixth block.

### Compiling

Finally, your code can be compiled and run on your machine, if you have AVX2 instructions.
Please uncomment the Seventh block and run the script.
It will compile the original procedure `rank_k_reduce_6x16` as `orig_matmul`, and the scheduled procedure `avx` as `avx2_matmul`.

Now, we provided a main function to call those procedure and time them. Please run
```
$ gcc -march=native main.c avx2_matmul.c orig_matmul.c
$ ./a.out
```

It should generate something like:
```
Time taken for original matmul: 0 seconds 490 milliseconds
Time taken for scheduled matmul: 0 seconds 236 milliseconds
```

Even for this small example, we can see the power of AVX instrutions.

