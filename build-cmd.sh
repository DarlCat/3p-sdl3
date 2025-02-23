#!/usr/bin/env bash

#Autobuild variables:
# AUTOBUILD - Path to tool
# AUTOBUILD_ADDRSIZE - Address size
# AUTOBUILD_BUILD_ID - Build ID
# AUTOBUILD_CONFIGURE_ARCH - Architecture
# AUTOBUILD_CONFIG_FILE - autobuild.xml
# AUTOBUILD_CPU_COUNT - Core count
# AUTOBUILD_LOGLEVEL - Log level
# AUTOBUILD_PLATFORM - Platform
# AUTOBUILD_PLATFORM_OVERRIDE - Platform override
# AUTOBUILD_VERSION_STRING - Version

cd "$(dirname "$0")"

# turn on verbose debugging output
exec 4>&1; export BASH_XTRACEFD=4; set -x

# make errors fatal
set -e

# bleat on references to undefined shell variables
set -u

if [ -z "$AUTOBUILD" ] ; then
    exit 1
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

top="$(pwd)"
stage="$(pwd)/stage"

source_environment_tempfile="$stage/source_environment.sh"
"$AUTOBUILD" source_environment > "$source_environment_tempfile"
. "$source_environment_tempfile"

# remove_cxxstd
source "$(dirname "$AUTOBUILD_VARIABLES_FILE")/functions"

SOURCE_DIR="SDL3"

build=${AUTOBUILD_BUILD_ID:=0}

pushd "$SOURCE_DIR"
    mkdir -p "$stage/lib/release"
    mkdir -p "$stage/include/SDL3"
    
    case "$AUTOBUILD_PLATFORM" in
        linux*)
            # Default target per --address-size
            opts="${TARGET_OPTS:--m$AUTOBUILD_ADDRSIZE $LL_BUILD_RELEASE}"
            
            plainopts="$(remove_cxxstd $opts)"

            # Handle any deliberate platform targeting
            if [ -z "${TARGET_CPPFLAGS:-}" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi
            
            mkdir -p build
            pushd build
                cmake .. -G"Ninja" -DCMAKE_BUILD_TYPE=None \
                    -DCMAKE_C_FLAGS:STRING="$plainopts" \
                    -DCMAKE_CXX_FLAGS:STRING="$opts" \
                    -DCMAKE_INSTALL_PREFIX=$stage \
                    -D SDL_STATIC=ON \
                    -DCMAKE_POSITION_INDEPENDENT_CODE=ON
                
                cmake --build . -j$AUTOBUILD_CPU_COUNT
                cmake --install .
            popd
            
            cp -a $stage/lib/libSDL3.so* $stage/lib/release
            cp -a $stage/lib/libSDL3*.a $stage/lib/release
        ;;
    esac
    
    mkdir -p $stage/LICENSES
    cp "$stage/share/licenses/SDL3/LICENSE.txt" "$stage/LICENSES/SDL3.txt"
popd