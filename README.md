# PLDI 2022 Artifact Evaluation for Exo

Here is the instruction for the **reusable** artifact evaluation for Exo.
For reusable criteria, we understood that the artifact should meet the following criteria:
1. Can be run locally
2. Very well documented
3. Able to make changes

Please refer to each section in this document to find the procedure to evaluate each criteria.

Please refer to functional.md for the functional artifact evaluation procedure.

## 1. Can be run locally

Exo is published on PyPI and can be installed locally via pip with the following command. Throughout this evaluation, reviewers do not need to download Zenodo or run docker.

```
$ pip install exo-lang
```

## 2. Very well documented

### Documentation for Exo folder structure

In [Exo repository](https://github.com/ChezJrk/exo), folder structure is follows:
1. `src/exo` is where all the core implementation resides.
  - `API.py` defines all the Exo API exposed to the user. Documentation of the API can be found in the section below.
  - `libs/` includes user-defined memory definitions (`memories.py`) and the custom malloc implementation.
  - `platforms/` includes user-defined instruction definitions that are part of the release. This is similar to standard library in C.
  - Other files are the core implementation of Exo (e.g., `typecheck.py` implements typecheck), but will not explain here as it is not exposed to users
2. `apps/` includes user-level application code using Exo
3. `dependencies/` includes submodules that Exo depends on
4. `examples/` includes Python notebook that was used for Demo
5. `tests/` includes unittest

### Documentation for scheduling API

Top-level decorator
- `@proc` 
- `@instr`
- `@config`

compile_procs(proc_list, path, c_file, h_file)

### Documentation for examples



## 3. Able to make changes

