# PLDI 2022 Artifact Evaluation for Exo

Here is the instruction for the reusable artifact evaluation for Exo. For the reusable
badge, we understand that the artifact should meet the following criteria:

1. Can be run locally
2. Very well documented
3. Able to make changes

Please refer to each section in this document to find the procedure to evaluate each
criterion.

Please refer to `functional.md` for the previous README for the functional evaluation.

## 1. Can be run locally

Exo is published on PyPI and can be installed locally via pip by the following command.
Throughout this evaluation, reviewers do not need to download Zenodo or run docker.

```
$ pip install exo-lang
```

## 2. Very well documented

### Documentation for Exo folder structure

In the [Exo repository](https://github.com/ChezJrk/exo), folders are structured as
follows:

1. `src/exo` is where the core Exo implementation resides.
    - `API.py` defines the stable API. Documentation for this API can be found in the
      section below.
    - `libs/` contains some common memory definitions (`memories.py`) and custom malloc
      implementations. These could be user-defined, but we provide them for convenience.
    - `platforms/` contains instruction definitions that are part of the release. These
      could be user-defined, but we provide them for convenience.
    - Other files are implementation details of Exo (e.g., `typecheck.py` implements
      typecheck), but we will not dwell on these as they are not exposed to users.
2. `apps/` contains some sample applications written in Exo.
3. `dependencies/` contains submodules that Exo's apps and testing depends on.
4. `examples/` contains a Python notebook that we used for live demos. This should be
   ignored.
5. `tests/` contains the Exo test suite.

### Documentation for scheduling API

#### Top-level Python function decorator

1. `@proc` - decorates a Python function which is parsed and compiled as Exo. Replaces
   the function with a `Procedure` object.
2. `@instr` - same as `@proc`, but accepts a hardware instruction as a format string.
3. `@config` - decorates a Python class which is parsed and compiled as an Exo
   configuration object

#### Procedure object methods

**Introspection operations**

- `.name()` returns the procedure name.
- `.check_effects()` forces Exo to run effect checking on the procedure.
- `.show_effects()` prints the effects of the procedure.
- `.show_effect(stmt)` prints the effect of the `stmt` in the procedure.
- `.is_instr()` returns `true` if the procedure has a hardware instruction string.
- `.get_instr()` returns the hardware instruction string.
- `.get_ast()` returns a `QAST`, which is an AST representation suitable for
  introspection.

**Execution / interpretation operations**

- `.compile_c(directory, filename)` compiles the procedure into C and stores
  in `filename` in the `directory`.
- `.interpret(**args)` runs Exo interpreter on the procedure.

#### Scheduling operations on Procedure objects

**Buffer related operations**

| Operation                                                   | Description                                                                                                                                                                                                                                                                   |
|-------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `.data_reuse(buf1, buf2)`                                   | Reuses a buffer `buf1` in the use site of `buf2` and removes the allocation of `buf2`.                                                                                                                                                                                        |
| `.inline_window(win_stmt)`                                  | Removes the window statement `win_stmt`, which is an alias to the window, and inlines the windowing in its use site.                                                                                                                                                          |
| `.expand_dim(stmt, alloc_dim, indexing)`                    | Expands the dimension of the allocation statement `stmt` with dimension `alloc_dim` of indexing `indexing`.                                                                                                                                                                   |
| `.bind_expr(new_name, expr)`                                | Binds the right hand side expression `expr` to a newly allocated buffer named `new_name`                                                                                                                                                                                      |
| `.stage_mem(win_expr, new_name, stmt_start, stmt_end=None)` | Stages the buffer `win_expr` to the new window expression `new_name` in statement block (`stmt_start` to `stmt_end`), and adds an initialization loop and a write-back loop.                                                                                                  |
| `.stage_assn(new_name, stmt)`                               | Binds the left hand side expression of `stmt` to a newly allocated buffer named `new_name`.                                                                                                                                                                                   |
| `.rearrange_dim(alloc, dimensions)`                         | Takes an allocation statement and a list of integers to map the dimension. It rearranges the dimensions of `alloc` in `dimension` order. E.g., if `alloc` were `foo[N,M,K]` and the `dimension` were `[2,0,1]`, it would become `foo[K,N,M]` after this operation.            |
| `.lift_alloc(alloc, n_lifts=1, keep_dims=False)`            | Lifts the allocation statement `alloc` out of `n_lifts` number of scopes. If and For statements are the only statements in Exo which introduce a scope. When lifting the allocation out of a for loop, it will expand its dimension to the loop bound if `keep_dims` is True. |

**Loop related operations**

| Operation                                                           | Description                                                                                                                                                                                                                                                                                                                       |
|---------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `.split(loop, split_const, iter_vars, tail='guard', perfect=False)` | Splits `loop` into an outer and an inner loop. The inner loop bound is `split_const` and the outer and inner loop names are specified by a list of strings `iter_vars`. If `perfect` is True, it will not introduce a tail case. `tail` specifies the tail strategies, where the options are `guard`, `cut`, and `cut_and_guard`. |
| `.fuse_loop(loop1, loop2)`                                          | Fuses two adjacent loops with a common iteration variable.                                                                                                                                                                                                                                                                        |
| `.partition_loop(loop, num)`                                        | Partitions `loop` into two loops, the first running between `0` and `num` and the second between `num+1` and `loop`'s original bound.                                                                                                                                                                                             |
| `.reorder(loop1, loop2)`                                            | Reorders two nested loops. `loop2` should be nested directly inside `loop1`. `loop1` will be nested inside `loop2` after this operation.                                                                                                                                                                                          |
| `.unroll(loop)`                                                     | Unrolls the loop. The loop needs to have a constant bound.                                                                                                                                                                                                                                                                        |
| `.fission_after(stmt, n_lifts=1)`                                   | Fissions the `n_lifts` number of loops around the `stmt`. The fissioned loops around the `stmt` need to be directly nested with each other and the statements before and after the `stmt` should not have any allocation dependencies.                                                                                            |
| `.remove_loop(loop)`                                                | Replaces the loop with its body if the body is idempotent. The system must be able to prove that the loop runs at least once.                                                                                                                                                                                                     |

**Config related operations**

| Operation                                       | Description                                                                                                                                                                |
|-------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `.bind_config(expr, config, field)`             | Binds the right hand side `expr` to `config.field`. It will replace the use site of `expr` with `config.field` and introduces a config statement of `config.field = expr`. |
| `.configwrite_root(config, field, expr)`        | Inserts the config statement `config.field = expr` in the beginning of the procedure.                                                                                      |
| `.configwrite_after(stmt, config, field, expr)` | Inserts the config statement `config.field = expr` after `stmt`.                                                                                                           |
| `.delete_config(stmt)`                          | Deletes the configuration statement.                                                                                                                                       |

**Other scheduling operations**

| Operation                        | Description                                                                                                                                                                                  |
|----------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `.add_assertion(assertion)`      | Asserts the truth of the expression `assertion` at the beginning of the procedure.                                                                                                           |
| `.lift_if(if, n_lifts=1)`        | Lifts the if statement `if` out of `n_lifts` number of scopes. This is similar to `reorder()`, but for if statements.                                                                        |
| `.assert_if(if, bool)`           | Unsafely asserts that the `if` condition is always True or False. This can be used to remove branches.                                                                                       |
| `.delete_pass()`                 | Deletes a `Pass` statement in the procedure.                                                                                                                                                 |
| `.reorder_stmts(stmt1, stmt2)`   | Reorder two adjacent statements `stmt1` and `stmt2`. After this operation, the order will be `stmt2` `stmt1`.                                                                                |
| `.reorder_before(stmt)`          | Move the statement `stmt` before the previous statement. This is a shorthand for `reorder_stmts()`.                                                                                          |
| `.replace(subproc, stmt)`        | Replace the statement with a call to `subproc`. This operation is one of our contributions and is explained in detail in the paper.                                                          |
| `.replace_all(subproc)`          | Eagerly replace every matching statement with a call to `subproc`.                                                                                                                           |
| `.inline(call_site)`             | Inline the function call.                                                                                                                                                                    |
| `.is_eq(another_proc)`           | Returns True if `another_proc` is equivalent to the procedure.                                                                                                                               | 
| `.call_eqv(eqv_proc, call_site)` | Replace the function call statement of `call_site` with a call to an equivalent procedure `eqv_proc`.                                                                                        |
| `.repeat(directive, *args)`      | Continue to run the directive until it fails. The directive and its arguments are given separately, e.g. `proc.repeat(Procedure.inline, "proc_to_inline(_)")`                                |
| `.simplify()`                    | Simplify the code in the procedure body. Tries to reduce expressions to constants and eliminate dead branches and loops. Uses branch conditions to simplify expressions inside the branches. |
| `.rename(new_name)`              | Rename this procedure to `new_name`.                                                                                                                                                         |
| `.make_instr(instr_string)`      | Converts this procedure to an instruction procedure with instruction `instr_string`.                                                                                                         |
| `.partial_eval(*args, **kwargs)` | Specializes this procedure to the given argument values.                                                                                                                                     |
| `.set_precision(name, type)`     | Sets the precision type of `name` to `type`.                                                                                                                                                 |
| `.set_window(name, is_window)`   | If `is_window` is True, it sets the buffer `name` to window type, instead of a tensor type.                                                                                                  |
| `.set_memory(name, mem_type)`    | Sets a buffer `name`'s memory type to `mem_type`.                                                                                                                                            |

## 3. Able to make changes

We provided a sample user code in `exo-artifact/examples/x86_matmul.py`.
`rank_k_reduce_6x16` is a microkernel for AVX2 SGEMM application. We chose to use AVX2
so that reviewers who do not have AVX512 machines can run this example. We chose the
SGEMM microkernel application because it is relatively simple but contains all the
important scheduling operators. Please run the code as follows.

```
$ cd examples
$ python x86_matmul.py
```

### Scheduling walk-through

We will try to walk through the scheduling transforms step by step. Without any
modification, `python x86_matmul.py` will print the original, simple algorithm that we
will start with.

```python
# Original algorithm:
def rank_k_reduce_6x16(K: size, C: f32[6, 16] @ DRAM, A: f32[6, K] @ DRAM,
                       B: f32[K, 16] @ DRAM):
    for i in seq(0, 6):
        for j in seq(0, 16):
            for k in seq(0, K):
                C[i, j] += A[i, k] * B[k, j]
```

Next, please uncomment the code in the first block by deleting the multi-line string
markers (`"""`). Now, you will see that `stage_assn()` stages `C` to a buffer
called `C_reg`. `set_memory()` sets `C_reg`'s memory to AVX2 to use it as an AVX vector,
which is denoted by `@ AVX2`.

```python
# First block:
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

Please uncomment the code in the second block. You will see that the `j` loop
is `split()` into two loops `jo` and `ji`, and loops are `reorder()`ed so that the `k`
loop becomes outermost.

```python
# Second block:
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

Please uncomment the code in the third block. Please notice that

- The allocation of `C_reg` is lifted by `lift_alloc()`
- `C_reg` initialization, reduction, and write back are `fission()`ed into three
  separate blocks.

```python
# Third block:
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

Please uncomment the code in the fourth block. `A` is bound to 8 wide AVX2 vector
register `a_vec` by `bind_expr()` and `set_memory()`.

```python
# Fourth block:
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

Please uncomment the code in the fifth block. The same schedule for `A` is applied
to `B`.

```python
# Fifth block:
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

Finally, please uncomment the sixth block. The sixth block replaces the statements with
equivalent calls to AVX2 instructions. These AVX2 hardware instructions could be defined
by users, but are part of Exo's standard library; the sources may be
found [here](https://github.com/ChezJrk/exo/blob/master/src/exo/platforms/x86.py#L8).
Please look at the definition of `mm256_loadu_ps` (for example), and notice that it has
a similar structure to the first `ji` loop in the fifth block. We will replace the
statement with the call to AVX2 instruction procedures to get the final schedule.

```python
# Sixth block:
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

We suggest reviewers attempt the following exercise:

- Modify the original algorithm so that the `k` loop becomes outermost. Adjust the
  scheduling operations so that the resulting code matches the output of the sixth
  block.

### Compiling

Finally, the code can be compiled and run on your machine if you have AVX2 instructions.
We provided a main function in `main.c` to call these procedures and to time them.
Please run `make` or compile manually:

```
$ exocc -o . --stem avx2_matmul x86_matmul.py
$ gcc -o avx2_matmul -march=native main.c avx2_matmul.c
```

It should generate something like:

```
$ ./avx2_matmul
Time taken for original matmul: 0 seconds 490 milliseconds
Time taken for scheduled matmul: 0 seconds 236 milliseconds
```

Even on this small example, we can see the benefit of AVX2 instructions.
