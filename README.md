# PLDI 2022 Artifact Evaluation for Exo

Here follow instructions for running our artifact and validating the claims made in the
paper.

## Artifact layout

In the `/app` directory of the artifact, you will find the following contents:

1. `Dockerfile` - the Dockerfile used to create the present image
2. `README.md` - this README document
3. `evaluate.sh` - the entry point for running our x86

## Artifact evaluation

### Running the evaluation script

From inside the Docker container, simply run:

```
$ ./evaluate.sh
```

We encourage reviewers to glance at the script. It will simply compile and run our x86
benchmarks and baselines. For SGEMM, the baselines are OpenBLAS and MKL. For CONV, the
baselines are Halide and Intel DNNL. As in the paper, both benchmarks are run on a
single core.

It will also produce matplotlib versions of the plots found in the paper and leave them
in sgemm.png and conv.png, respectively.

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

### Running exo's unit tests

If you would like to run exo's unit tests, follow these steps...

### Running the GEMMINI tests

Unfortunately, we are not able to provide reproduction scripts for our GEMMINI timings
because they require access to prototype hardware. However, you can do this instead...

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
$ ./evaluation.sh
```

## Creating the Docker image

This guide assumes you are running Ubuntu 20.04 LTS.

### Make sure you cloned everything

This repository and exo both use submodules for dependencies. Make sure those are pulled
and up to date:

```
$ git submodule update --init --recursive
```

### Setting up Docker

First, follow the directions to install the latest version of Docker, posted
here: https://docs.docker.com/engine/install/ubuntu/

These are the steps I had to run on my local machine:

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

Then you need to add yourself to the `docker` group and reboot:

```
$ sudo usermod -aG docker $USER
$ sudo reboot
```

### Building the Docker image
