#!/usr/bin/env bash

BASE=$(dirname "$(readlink -f "${0}")")

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
        clang \
        cmake \
        curl \
        file \
        flex \
        gcc \
        g++ \
        git \
        libelf-dev \
        libssl-dev \
        lld \
        make \
        ninja-build \
        python3 \
        texinfo \
        xz-utils \
        zlib1g-dev
    git config --global user.email "1405481963@qq.com"
    git config --global user.name "Little-W"
	sudo dd if=/dev/zero of=/swapfile bs=1M count=22960
	sudo mkswap /swapfile
	sudo swapon /swapfile
}
function do_build() {
    ./build-llvm.py \
		--clang-vendor "Sakura-🌸" \
		--targets "ARM;AArch64;X86" \
		--lto thin \
		--incremental \
		--pgo kernel-defconfig
     #	--build-stage1-only \
    #	--install-stage1-only \
     #	--projects "clang;compiler-rt;lld;polly" \
    	#--branch "release/12.x" 
    ./build-binutils.py --targets arm aarch64 x86_64 
# Remove unused products

rm -f install/lib/*.a install/lib/*.la install/lib/clang/*/lib/linux/*.a*

for f in $(find install -type f -exec file {} \;); do
	if [ -n "$(echo $f | grep 'ELF .* interpreter')" ]; then
		i=$(echo $f | awk '{print $1}'); i=${i: : -1}
		# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
		if [ -d $(dirname $i)/../lib/ldscripts ]; then
			patchelf --set-rpath '$ORIGIN/../../lib:$ORIGIN/../lib' "$i"
		else
			if [ "$(patchelf --print-rpath $i)" != "\$ORIGIN/../../lib:\$ORIGIN/../lib" ]; then
				patchelf --set-rpath '$ORIGIN/../lib' "$i"
			fi
		fi
		# Strip remaining products
		if [ -n "$(echo $f | grep 'not stripped')" ]; then
			${stripBin} --strip-unneeded "$i"
		fi
	elif [ -n "$(echo $f | grep 'ELF .* relocatable')" ]; then
		if [ -n "$(echo $f | grep 'not stripped')" ]; then
			i=$(echo $f | awk '{print $1}');
			${stripBin} --strip-unneeded "${i: : -1}"
		fi
	else
		if [ -n "$(echo $f | grep 'not stripped')" ]; then
			i=$(echo $f | awk '{print $1}');
			${stripBin} --strip-all "${i: : -1}"
		fi
	fi
done

}

function do_upload() {
    rel_date="$(date "+%Y%m%d")" # ISO 8601 format
    clang_version="$(install/bin/clang --version | head -n1 | cut -d' ' -f4)"
    # Generate build info
    git clone --depth 1 git@github.com:Little-W/Sakura-CBL.git ~/cl/
    mv ~/cl/.git install/.git
    mv ~/cl/README.md install/README.md
    cd  install
    git add -A -f
    git commit -am "Update to $rel_date build (Clang Version: $clang_version)"
    git push
}

parse_parameters "${@}"
do_"${ACTION:=all}"
