ARG base=lcr.loongnix.cn/library/python:3.13-slim-trixie
FROM ${base}

ENV PYTHONUTF8=1

ARG vtk=9.3.1
ARG vtk_major=9.3
ARG python_bin=python3.13
ARG venv_dir=.build-vtk

ENV VTK=${vtk}
ENV VTK_MAJOR=${vtk_major}
ENV PYTHON_BIN=${python_bin}
ENV VENV_DIR=${venv_dir}

ARG loongarch_pip_url=https://lpypi.loongnix.cn/loongson/pypi/+simple
ENV PIP_INDEX_URL=${loongarch_pip_url}

# Install Deps
RUN  apt-get update &&\
     DEBIAN_FRONTEND=noninteractive apt-get install -y git \
	build-essential \
	cmake \
	mesa-common-dev \
	mesa-utils \
	freeglut3-dev \
#	python3-dev \
#	python3-venv \
	git-core \
	ninja-build \
	wget \
	libglvnd0 \
	libglvnd-dev \
	curl &&\
    rm -rf /var/lib/apt/lists/* 

ENV CI_DOCKER=true
