#/bin/bash
set -euo pipefail

if [[ -z "${CI_DOCKER:-}" ]]; then
    PYTHONUTF8=1
    VTK=${VTK:-9.3.1}
    VTK_MAJOR=${VTK_MAJOR:-9.3}

    PYTHON_BIN=${PYTHON_BIN:-python3.13}
    VENV_DIR=${VENV_DIR:-.build-vtk}
    echo "Local run: set VTK=$VTK, VTK_MAJOR=$VTK_MAJOR, PYTHON_BIN=$PYTHON_BIN, VENV_DIR=$VENV_DIR"
    apt-get update && apt-get install -y git
else
# Using ghcr.io/loongson-cloud-community/cadquery-vtk-py313-build-base
    echo "CI/Docker run: CI_DOCKER is set ($CI_DOCKER)"
fi

# Dowload ocp-build-system sources
git clone https://github.com/CadQuery/ocp-build-system.git

cd ocp-build-system

cpu_count=$(nproc)

echo "=> Using $cpu_count CPUs"

# Create python3.13 venv
if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
    echo "Error: $PYTHON_BIN not found in PATH" >&2
    exit 1
fi

if [ -d "$VENV_DIR" ]; then
    echo "Removing existing venv at $VENV_DIR"
    rm -rf "$VENV_DIR"
fi

$PYTHON_BIN -m venv $VENV_DIR
source $VENV_DIR/bin/activate

pip install --upgrade --no-cache-dir pip wheel build setuptools

if [[ -z "${CI_DOCKER:-}" ]]; then
# Debian Deps
    apt-get install -y build-essential cmake mesa-common-dev mesa-utils freeglut3-dev git-core ninja-build wget libglvnd0 libglvnd-dev curl
fi

# Download VTK sources
curl -L -O https://vtk.org/files/release/$VTK_MAJOR/VTK-$VTK.tar.gz
tar -zxf VTK-$VTK.tar.gz

cd VTK-$VTK
mkdir build

patch -p1 < ../patches/vtk-$VTK/9987_try_except_python_import.patch
patch -p1 < ../patches/vtk-$VTK/11486.patch
sed -i '/defined(__riscv)/a\    defined(__loongarch64) || \\' ThirdParty/doubleconversion/vtkdoubleconversion/double-conversion/utils.h
sed -i 's/_M_chilren/m_children/' Utilities/octree/octree/octree_node.txx

# Build Linux python libraries from Scratch
export CXXFLAGS="-D_GLIBCXX_USE_CXX11_ABI=0" # Disables the C++11 ABI features for VTK compatibility

cd build
cmake -G Ninja \
      -D VTK_VERSIONED_INSTALL=ON \
      -D VTK_CUSTOM_LIBRARY_SUFFIX="9.3" -DVTK_VERSION_SUFFIX="" \
      -D VTK_WHEEL_BUILD=ON -DVTK_WRAP_PYTHON=ON \
      -D CMAKE_BUILD_TYPE=Release \
      -D CMAKE_POLICY_DEFAULT_CMP0174=NEW -DCMAKE_POLICY_DEFAULT_CMP0177=NEW \
      ..

ninja -j $cpu_count

# Build wheel
sed -i "s/dist_name = 'vtk'/dist_name = 'cadquery_vtk'/" setup.py
sed -i "s/version_suffix = '9.3'/version_suffix = ''/" setup.py
cat setup.py
$PYTHON_BIN -m build -n -w

# repair wheel
pip install auditwheel patchelf
auditwheel repair --wheel-dir wheel dist/*.whl
rm dist/*.whl
mv wheel/*.whl dist/
