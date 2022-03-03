# PLDI 2022 Artifact Evaluation for Exo

Here follow instructions for running our artifact and validating the claims made in the
paper. Note that we renamed our system from SYSTL in the paper to Exo.

## Artifact layout

In the `/app` directory of the artifact, you will find the following contents:

1. `Dockerfile` - the Dockerfile used to create the present image
2. `README.md` - this README document
3. `evaluate.sh` - the entry point for running our x86
4. `plot.py` - a tool used by `evaluate.sh` to plot benchmark results
5. `exo/` - the source code for the publicly released version of Exo, version 0.0.2
6. `images/` - figures used in this document

## Artifact evaluation

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
2. **(Figure 6)** It will produce a matplotlib version of the SGEMM plot from the paper
   as `sgemm.png`.
3. **(Table 2a)** It will print the CONV results to standard output as the last
   benchmark run.
4. **(Table 2a)** It will print source line counts for the generated C code (column "C
   gen") in the same order.

The evaluation script should not take an especially long time to run. In our primary
test environment, which uses an Intel i9-7900X CPU, it completes in under 3 minutes.
Under emulation and on a slower CPU, it could take up to 15 minutes.

Note that our implementation requires the use of AVX-512 instructions. If your CPU does
not support these instructions, then the script will run under the [Intel SDE] emulator
and print a large warning. In this case, you should not expect accurate timings, but
should at least see that the benchmarks run and that plots are produced correctly. For
reference, here are some possible plots you might see.

| i9-7900X              | i7-1185G7             | i5-8400 (SDE)           |
|-----------------------|-----------------------|-------------------------|
| ![][sgemm-i9]         | ![][sgemm-i7]         | ![][sgemm-i5]           |
| Skylake-X Desktop CPU | Tiger Lake Mobile CPU | Coffee Lake Desktop CPU |

The first plot corresponds to the tests we reported in the paper, taken on an i9-7900X.
The second plot corresponds to a laptop Tiger Lake processor we have since tested and
which supports AVX-512. We were pleased to see Exo lead the pack in this mobile CPU and
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
distribution's package archives for this utility. On Ubuntu systems, it is provided by
the package `linux-tools-common`.

Finally, changes to the compiler since submission have led to small deviations in the
source line counts reported in the paper. The following table details the changes:

| Benchmark | Submission (lines) | Camera-ready (lines) |
|-----------|--------------------|----------------------|
| SGEMM x86 | 831                | 846                  |
| CONV x86  | 91                 | 102                  |
| MATMUL GEMMINI | 505           | 462                  |
| CONV GEMMINI   | 9409          | 8317                  |

The updated counts will be reported in the camera-ready submission. We do not believe
they change any of our fundamental claims. You should expect the evaluation script to
report the numbers that will be used for camera-ready.

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

### Running the GEMMINI tests

Unfortunately, we are not able to provide reproduction scripts for our GEMMINI timings
because they require access to prototype hardware. However, you can look at the
generated C code and check the source code size.

After executing the commands in the previous section, run the following.

```
$ cd tests/gemmini
$ python -m pytest matmul/test_gemmini_matmul_ae.py -s
$ python -m pytest conv/test_gemmini_conv_ae.py -s
```

We encourage reviewers to take a look at the code. It starts from the simple algorithm
and schedules the code into a complex one. Although it will not be able to be executed
in this artifact evaluation, if you have a GEMMINI environment setup, the script will
generate C code and compile them with downstream C compiler (GEMMINI's custom gcc), and
runs a sanity-check on the result against the original algorithm.

The script above prints out the original and the scheduled Exo code to the terminal and
produces C code in `gemmini_build/`. You can take a look at the generated C code like
so:

```
$ cat gemmini_build/matmul_ae_lib.c
$ cat gemmini_build/conv_ae_lib.c
```

`*_lib.c` files are the generated C files and `*_lib.h` files are the generated header
files. `*_main.c` files are generated to compile the C code with downstream C compilers
(e.g., gcc, clang) but are not used for GEMMINI, since it requires access to custom
prototype gcc implementation.

## Installing locally

If instead of using the Docker image, you wish to run the script on your local machine,
then you need only create a virtual environment with `exo-lang==0.0.2`, install Clang
13, and CMake 3.21+. Some commands for doing so can be found in the Dockerfile (though
note these commands are run as root).

As the project is open-source and published on PyPI, the following should work, assuming
dependencies are installed.

```
$ python3.9 -m venv $HOME/.venv/exo
$ source $HOME/.venv/exo/bin/activate
(exo) $ python -m pip install -U setuptools pip wheel
(exo) $ python -m pip install -U exo-lang==0.0.2
```

From here, you can then run our evaluation script:

```
$ ./evaluate.sh
```

## Creating the Docker image

This guide assumes you are running Ubuntu 20.04 LTS.

### Make sure you cloned everything

This repository and Exo both use submodules for dependencies. Make sure those are pulled
and up to date:

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

This will create a Docker _image_ named `exo`. Then you can create and run a _container_
for that image by running:

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

[sgemm-i5]: images/sgemm-i5.png

[sgemm-i7]: images/sgemm-i7.png

[sgemm-i9]: images/sgemm-i9.png

[Intel SDE]: https://www.intel.com/content/www/us/en/developer/articles/tool/software-development-emulator.html
