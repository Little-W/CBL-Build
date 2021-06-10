#!/usr/bin/env bash

BASE=$(dirname "$(readlink -f "${0}")")
install=~/install/
PATH=tc/bin:$PATH
LD_LIBRARY_PATH=tc/lib:$LD_LIBRARY_PATH

set -eu


function parse_parameters() {
    while ((${#})); do
        case ${1} in
            all | deps | build | upload  ) ACTION=${1} ;;
            *) exit 33 ;;
        esac
        shift
    done
}

function do_all() {
    do_deps
    do_upload
    do_build
}

function do_deps() {
    # We only run this when running on GitHub Actions
    sudo apt update
    sudo apt install -y --no-install-recommends \
        bc \
        bison \
        ca-certificates \
        cmake \
        curl \
        file \
        flex \
        gcc \
        g++ \
        git \
        libelf-dev \
        libssl-dev \
        make \
        llvm \
        ninja-build \
        python3 \
        texinfo \
        xz-utils \
        zlib1g-dev
    git clone --depth 1 https://github.com/Little-W/proton-clang tc
    git config --global user.email "1405481963@qq.com"
    git config --global user.name "Little-W"
}
function do_build() {
    ./build-llvm.py \
        --no-update \
    	--clang-vendor "Sakura" \
    	--targets "ARM;AArch64;X86" \
	    --shallow-clone \
	    --lto thin \
	    --incremental \
	    --pgo kernel-defconfig
     #	--build-stage1-only \
    #	--install-stage1-only \
     #	--projects "clang;compiler-rt;lld;polly" \
    	#--branch "release/12.x" 
 
    ./build-binutils.py --targets arm aarch64 x86_64 
      # Remove unused products
       rm -fr install/include
          rm -f install/lib/*.a install/lib/*.la install/lib/clang/*/lib/linux/*.a*

    for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
    	strip ${f: : -1}
    done

    # Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
    for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
   	# Remove last character from file output (':')
	bin="${bin: : -1}"

    	echo "$bin"
    	patchelf --set-rpath '$ORIGIN/../lib' "$bin"
    done
}

function do_upload() {

    rel_date="$(date "+%Y%m%d")" # ISO 8601 format
    clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"

    if [ -d "install" ]
    then
    # Generate build info
    git clone --depth 1 git@github.com:Little-W/Sakura-ClangBuiltLinux.git ~/cl/
    mv ~/cl/.git install/.git
    mv ~/cl/README.md install/README.md
    cd  install
    git add -A -f
    git commit -am "Update to $rel_date build (Clang Version: $clang_version)"
    git push 
    else 
         git remote set-url origin git@github.com:Little-W/tc-build.git
         git add build/ 
       	 git commit -m "upload build cache $rel_date"
     	 git push
    fi
        
}

parse_parameters "${@}"
do_"${ACTION:=all}"
