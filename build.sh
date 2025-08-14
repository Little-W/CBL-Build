#!/usr/bin/env bash

# 这是一个高度简化的脚本，用于构建和精简 RISC-V LLVM。
# 它没有参数解析，也没有函数，只会直接执行构建命令。

base=$(dirname "$(readlink -f "$0")")
install=$base/install
src=$base/src

# 设置 ccache 缓存目录在当前项目文件夹中
export CCACHE_DIR="$base/ccache"
export CC=clang
export CXX=clang++

set -eu

# 执行构建 LLVM 工具链的命令，并启用 PGO (Profile-Guided Optimization)
"$base"/build-llvm.py \
    --vendor-string "Sakura-🌸-RISCV" \
    --lto thin \
    --build-target distribution \
    --install-folder "$install" \
    --install-target distribution \
    --quiet-cmake \
    --no-update \
    --show-build-commands \
    --pgo kernel-defconfig \
    --targets RISCV

"$base"/build-binutils.py \
    --install-folder "$install" \
    --show-build-commands \
    --targets riscv64-unknown-elf-multilib

# 对安装目录下的所有可执行文件进行 strip，以减小体积
echo "Stripping binaries in '$install/bin'..."
find "$install/bin" -type f -executable -exec strip {} \;
echo "Stripping complete."

