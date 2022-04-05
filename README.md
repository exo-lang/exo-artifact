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
- `.split(split_var, split_const, out_vars, tail='guard', perfect=False)`
- `.fuse_loop(loop1, loop2)`
- `.add_loop(stmt, var, hi)`
- `.partition_loop(var_pattern, num)`
- `.reorder(out_var, in_var)`
- `.unroll(unroll_var)`
- `.fission_after_simple(stmt_pattern, n_lifts=1)`
- `.fission_after(stmt_pattern, n_lifts=1)`
- `.remove_loop(loop_pattern)`

**Config related operations**
- `.bind_config(var, config, field)` sets 
- `.configwrite_root(config, field, var_pattern)`
- `.configwrite_after(stmt_pattern, config, field, var_pattern)`
- `.delete_config(stmt_pat)`

**Branch related operations**
- `.add_unsafe_guard(stmt_pat, var_pattern)`
- `.add_assertion(assertion)`
- `.add_guard(stmt_pat, iter_pat, value)`
- `.bound_and_guard(loop)`
```
        Replace
          for i in par(0, e): ...
        with
          for i in par(0, c):
            if i < e: ...
        where c is the tightest constant bound on e
        This currently only works when e is of the form x % n
```
- `.fuse_if(if1, if2)`
- `.merge_guard(stmt1, stmt2)`
- `.lift_if(if_pattern, n_lifts=1)`
- `.assert_if(if_pattern, cond)`

**Other scheduling operations**
- `.specialize(stmt_pat: str, conds: Union[str, List[str]])`
- `.insert_pass(pat: str)`
- `.delete_pass()`
- `.reorder_before(pat)`
- `.reorder_stmts(first_pat, second_pat)`
- `.replace(subproc, pattern, quiet=False)`
- `.replace_all(subproc)`
- `.inline(call_site_pattern)`
- `.is_eq(proc: 'Procedure')`
- `.call_eqv(eqv_proc: 'Procedure', call_site_pattern)`
- `.repeat(directive, *args)`
- `.extract_method(name, stmt_pattern)`
- `.simplify()` Simplify the code in the procedure body. Tries to reduce expressions
        to constants and eliminate dead branches and loops. Uses branch
        conditions to simplify expressions inside the branches.
- `.rename(new_name)` Rename this procedure to `new\_name`
- `.make_instr(instr_string)` makes this procedure to instruction procedure with `instr_string`
- `.partial_eval(*args, **kwargs)` specializes this procedure to the arguments.
- `.set_precision(name, type)` sets the precision type of `name` to `type`
- `.set_window(name, is_window)` if `is_window` is True, it sets the buffer `name` to window type, instead of a tensor type
- `.set_memory(name, mem_type)` sets a buffer `name`'s memory type to `mem_type`


### Documentation for examples

#### Gemmini

We provided a documentation for Gemmini code used
The code is the same as `exo/tests/gemmini/matmul/test_gemmini_matmul_ae.py` and `exo/tests/gemmini/matmul/test_gemmini_matmul_ae.py`

```
$ python examples/test_gemmini_matmul_ae.py -s
$ python examples/test_gemmini_conv_ae.py -s
```

Both tests start from a simple algorithm and schedule the code into a complex one.
Although it is not executed in this artifact evaluation, if you happen to have a GEMMINI
environment set up, the script will generate C code and compile it with GEMMINI's custom
gcc. It then runs a sanity-check on the result against the original algorithm.

The commands above print out the original and the scheduled Exo code to the terminal and
produce C code in `exo/tests/gemmini/gemmini_build/`. You can look at the generated C
code like so:

```
$ pwd
/app/exo/tests/gemmini
$ cat gemmini_build/matmul_ae_lib.c
$ cat gemmini_build/conv_ae_lib.c
```

The `*_lib.c` files are generated C sources and the `*_lib.h` files are generated header
files.

#### x86

Please look at `example/simple_kernel.py` in this repository. We will defer the explanation of this
example to the next section.

## 3. Able to make changes





