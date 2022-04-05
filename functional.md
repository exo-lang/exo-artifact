# PLDI 2022 Artifact Evaluation for Exo

Here follow instructions for running our artifact and validating the claims made in the
paper. Note that we renamed our system from SYSTL in the paper to **Exo**.

## Artifact layout

In the `/app` directory of the artifact, you will find the following contents:

1. `Dockerfile` - the Dockerfile used to create the present image
2. `README.md` - this README document
3. `evaluate.sh` - the entry point for running our x86 benchmarks
4. `plot.py` - a tool used by `evaluate.sh` to plot benchmark results
5. `exo/` - the source code for the publicly released version of Exo, version 0.0.2
6. `images/` - figures used in this document

## Artifact evaluation

### Loading the Docker image

You should have gotten a Docker image tarball named `exo-ae.tar`. Start by loading the
image into Docker:

```
$ docker load --input exo-ae.tar
```

The image is named `exo`. Next, you can create and run a _container_ for that image by
running:

```
$ docker run --name exo -it exo
```

This will place you into a terminal for the new container where you can run the above
commands. To reconnect to the container after exiting, run:

```
$ docker start -ia exo
```

Finally, to clean up the container and its images after evaluation, run:

```
$ docker rm exo
$ docker image prune
```

### Running the evaluation script

From inside the Docker container, simply run:

```
$ ./evaluate.sh
```

We encourage reviewers to glance at the script. It will automatically reproduce the
following results:

1. It will build and run our x86 benchmarks and baselines.
    1. For SGEMM, the baselines are OpenBLAS and MKL.
    2. For CONV, the baselines are Halide and Intel DNNL.
    3. As in the paper, all benchmarks are run on a single core.
2. It will run the GEMMINI unit tests and produce the C code we reported in the paper.
   Since we cannot provide access to prototype hardware, this code will not run; see
   below for more details.
3. **(Figure 6)** It will produce a matplotlib version of the x86 SGEMM plot from the
   paper as `sgemm.png`.
4. **(Table 2a)** It will print the x86 CONV results to standard output as the last
   benchmark run.
5. **(Table 3)** It will print source line counts for the generated C code (column "C
   gen") in the same order.

The evaluation script should not take an especially long time to run. In our primary
test environment, which uses an Intel i9-7900X CPU, it completes in under 5 minutes.

Note that our implementation requires the use of AVX-512 instructions. If your CPU does
not support these instructions, then the script will run under the [Intel SDE] emulator
and print a large warning. In this case, you should not expect accurate timings or
plots, but you should at least see that the benchmarks run and that plots are produced
correctly. For reference, here are some possible plots you might see.

| i9-7900X              | i7-1185G7             | i5-8400 (SDE)           |
|-----------------------|-----------------------|-------------------------|
| ![][sgemm-i9]         | ![][sgemm-i7]         | ![][sgemm-i5]           |
| Skylake-X Desktop CPU | Tiger Lake Mobile CPU | Coffee Lake Desktop CPU |

The first plot corresponds to the tests we reported in the paper, taken on an i9-7900X.
The second plot corresponds to a laptop Tiger Lake processor we have since tested and
which supports AVX-512. We were pleased to see Exo lead the pack on this mobile CPU and
will include this result in the camera-ready revision. The final plot corresponds to a
desktop Coffee Lake processor that does not support AVX-512 and so must run under SDE's
emulation. Do not read too much into these results.

If, while running the evaluation script, you see the message

```
***WARNING*** CPU scaling is enabled, the benchmark real time measurements may be noisy and will incur extra overhead.
```

Then on your _host_ system (rather than in the Docker image) you will need to disable
CPU scaling. On Linux systems, this may be accomplished by changing the CPU frequency
governor to `performance`. If you have the `cpupower` utility installed, the following
command should suffice.

```
$ cpupower frequency-set --governor performance
```

If you do not have `cpupower` installed on your host system, then please consult your
distribution's package archives to install this utility. On Ubuntu, it is provided by
the package `linux-tools-common`.

Finally, changes to the compiler since submission have led to small deviations in the
source line counts reported in the paper. The following table details the changes:

| Benchmark      | Submission (lines) | Camera-ready (lines) | Difference    |
|----------------|--------------------|----------------------|---------------|
| SGEMM x86      | 831                | **846**              | +15 (1.8%)    |
| CONV x86       | 91                 | **102**              | +11 (12.1%)   |
| MATMUL GEMMINI | 505                | **462**              | -43 (8.5%)    |
| CONV GEMMINI   | 9409               | **8317**             | -1092 (11.6%) |

The updated counts will be reported in the camera-ready submission. We believe these
differences do not affect any of our fundamental claims. You should expect the
evaluation script to report the numbers that will be used for camera-ready.

### Running Exo's unit tests

If you would like to run Exo's unit test suite, follow these steps.

```
$ . /opt/venv/bin/activate
$ cd exo
$ python -m pip install -r requirements.txt
$ python -m pytest
```

This will take substantially longer to complete than the evaluation script. Expect this
to run for tens of minutes.

Exo's unit tests consist of many correctness and safety-checking tests such as this one:

```python
def test_reorder_stmts_fail():
    @proc
    def foo(N: size, x: R[N]):
        x[0] = 3.0
        x[0] = 4.0

    with pytest.raises(SchedulingError, match='do not commute'):
        foo.reorder_stmts('x[0] = 3.0', 'x[0] = 4.0')
```

The purpose of this particular test is to check that the commutativity analysis stated
in Section 5.7 and Definition 5.6 in the paper work correctly when two statements do not
commute. `foo.reorder_stmts` tries to reorder the first and the second statement in the
proc `foo`, but the program analysis will catch that it is not safe to do so because the
value of `x[0]` will be `3.0` instead of `4.0` if the reordering happens.

If reviewers wish to go through our program analysis tests, they can be found
in `tests/test_new_eff.py` and `tests/test_schedules.py`.

### Running the GEMMINI tests

Unfortunately, we are not able to provide reproduction scripts for our GEMMINI timings
because they require access to prototype hardware. However, Exo can still generate
GEMMINI C code, and reviewers can take a look at the generated C code and the scheduling
transformation needed to reach the reported number in the paper.

Running `./evaluate.sh` will report the source code size of GEMMINI matmul and conv. If
reviewers wish to look at the C code and the scheduling transformations then, after
executing the commands in the previous section, run the following.

```
$ cd tests/gemmini
$ python -m pytest matmul/test_gemmini_matmul_ae.py -s
$ python -m pytest conv/test_gemmini_conv_ae.py -s
```

We encourage reviewers to look at the code in `matmul/test_gemmini_matmul_ae.py`
and `conv/test_gemmini_conv_ae.py`. You can confirm the algorithm and schedule source
code sizes match Table 3 in the paper.

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

## Installing locally

If instead of using the Docker image, you wish to run the script on your local machine,
then you need only create a virtual environment with `exo-lang==0.0.2`, install Clang
13, and CMake 3.21+. Some commands for doing so can be found in the Dockerfile (though
note these commands are run as root).

As the project is open-source and published on PyPI, the following should work, assuming
dependencies are installed.

```
$ export CC=clang-13
$ export CXX=clang++-13
$ python3.9 -m venv $HOME/.venv/exo
$ source $HOME/.venv/exo/bin/activate
(exo) $ python -m pip install -U setuptools pip wheel
(exo) $ python -m pip install -U exo-lang==0.0.2 pytest
(exo) $ python -m pip install -r requirements.txt
```

From here, you can then run our evaluation script:

```
$ ./evaluate.sh
```

## Creating the Docker image

This guide assumes you are running Ubuntu 20.04 LTS.

### Make sure you cloned everything

This repository and Exo both use submodules for dependencies. Make sure those are pulled
and up to date before attempting to create the Docker image:

```
$ git submodule update --init --recursive
```

### Setting up Docker

First, follow the directions to install the latest version of Docker, posted
here: https://docs.docker.com/engine/install/ubuntu/

These are the steps we ran on our reproduction machine:

```
$ sudo apt remove docker docker.io containerd runc
$ sudo apt update
$ sudo apt install ca-certificates curl gnupg lsb-release
$ sudo apt-mark auto ca-certificates gnupg lsb-release
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
$ echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
$ cat /etc/apt/sources.list.d/docker.list
deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu   focal stable
$ sudo apt update
$ sudo apt install docker-ce docker-ce-cli containerd.io
```

Then, add your user account to the `docker` group and reboot:

```
$ sudo usermod -aG docker $USER
$ sudo reboot
```

### Using the Docker image

Once Docker is installed, the rest is straightforward. To build the container, simply
run:

```
$ docker build -t exo .
```

This will create a Docker _image_ named `exo`. Then, follow the directions at the top of
this document to create a container for the image, start a terminal in it, and run the
evaluation steps.

[sgemm-i5]: images/sgemm-i5.png

[sgemm-i7]: images/sgemm-i7.png

[sgemm-i9]: images/sgemm-i9.png

[Intel SDE]: https://www.intel.com/content/www/us/en/developer/articles/tool/software-development-emulator.html
