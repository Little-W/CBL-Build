#!/usr/bin/env bash
set -e
base=$(dirname "$(readlink -f "$0")")
# ==== 配置 ====
CLANG_PREFIX=$base/install               # 你的 clang 安装目录
NEWLIB_SRC=$HOME/newlib             # newlib 源码目录
BUILD_DIR=$HOME/build-newlib                # 临时构建目录

# ==== 克隆官方 newlib 仓库 ====
if [ ! -d "$NEWLIB_SRC" ]; then
    git clone git@github.com:bminor/newlib.git "$NEWLIB_SRC" --depth 1
else
    echo "newlib 仓库已存在，跳过克隆"
fi

# 覆盖的 multilib 列表（指令集+ABI）
MULTILIBS=(
    "rv32i/ilp32"       # 新增 rv32i
    "rv32im/ilp32"
    "rv32imf/ilp32f"
    "rv32imfd/ilp32d"
    "rv64imac/lp64"
    "rv64imafdc/lp64d"
)

# ==== 准备构建目录 ====
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"


# 安装到 Clang sysroot，自动区分32/64位
SYSROOT=$CLANG_PREFIX/sysroot


# ==== 循环编译每个 multilib ====

for entry in "${MULTILIBS[@]}"; do
    IFS="/" read -r march mabi <<< "$entry"

    echo "=== 编译 multilib: march=$march, mabi=$mabi ==="

    # 自动区分32/64位目标
    if [[ $march == rv32* ]]; then
        TARGET_TRIPLE=riscv32-unknown-elf
        CFLAGS_EXTRA=""
    else
        TARGET_TRIPLE=riscv64-unknown-elf
        CFLAGS_EXTRA="-mcmodel=medlow"
    fi
    INSTALL_DIR=$SYSROOT/$TARGET_TRIPLE
    mkdir -p "$INSTALL_DIR"

    BUILD_SUB=$BUILD_DIR/${march}-${mabi}
    mkdir -p "$BUILD_SUB"
    cd "$BUILD_SUB"

    # 用env传递CC避免configure识别问题
    env \
        CC="$CLANG_PREFIX/bin/clang --target=$TARGET_TRIPLE -march=$march -mabi=$mabi" \
        AR="$CLANG_PREFIX/bin/llvm-ar" \
        RANLIB="$CLANG_PREFIX/bin/llvm-ranlib" \
        "$NEWLIB_SRC"/configure \
            --target=$TARGET_TRIPLE \
            --prefix="$INSTALL_DIR" \
            CFLAGS_FOR_TARGET="-O2 $CFLAGS_EXTRA"

    make -j$(nproc)
    make install

    echo "=== 完成: march=$march, mabi=$mabi ==="
done

echo "✅ 所有 multilib newlib 安装完成，位置: $SYSROOT/riscv32-unknown-elf/lib/ 及 $SYSROOT/riscv64-unknown-elf/lib/"

