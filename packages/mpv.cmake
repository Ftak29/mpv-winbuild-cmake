ExternalProject_Add(mpv
    DEPENDS
        angle-headers
        ffmpeg
        fribidi
        lcms2
        libarchive
        libass
        libdvdnav
        libdvdread
        libiconv
        libjpeg
        libpng
        luajit
        rubberband
        uchardet
        openal-soft
        mujs
        vulkan
        shaderc
        libplacebo
        spirv-cross
        vapoursynth
        libsdl2
        subrandr
    GIT_REPOSITORY https://github.com/mpv-player/mpv.git
    GIT_TAG v0.41.0
    SOURCE_DIR ${SOURCE_LOCATION}
    GIT_CLONE_FLAGS "--filter=tree:0"
    UPDATE_COMMAND ""
    CONFIGURE_COMMAND ${EXEC} CONF=1 meson setup <BINARY_DIR> <SOURCE_DIR>
        --prefix=${MINGW_INSTALL_PREFIX}
        --libdir=${MINGW_INSTALL_PREFIX}/lib
        --cross-file=${MESON_CROSS}
        --default-library=shared
        --prefer-static
        -Ddebug=true
        -Db_ndebug=true
        -Doptimization=3
        -Db_lto=true
        ${mpv_lto_mode}
        -Dlibmpv=true
        -Dpdf-build=enabled
        -Dlua=enabled
        -Djavascript=enabled
        -Dsdl2-gamepad=enabled
        -Dlibarchive=enabled
        -Dlibbluray=enabled
        -Ddvdnav=enabled
        -Duchardet=enabled
        -Drubberband=enabled
        -Dlcms2=enabled
        -Dopenal=enabled
        -Dspirv-cross=enabled
        -Dvulkan=enabled
        -Dvapoursynth=enabled
        -Dsubrandr=enabled
        ${mpv_gl}
        -Dc_args='-Wno-error=int-conversion'
    BUILD_COMMAND ${EXEC} LTO_JOB=1 PDB=1 ninja -C <BINARY_DIR>
    INSTALL_COMMAND ""
    LOG_DOWNLOAD 1 LOG_UPDATE 1 LOG_CONFIGURE 1 LOG_BUILD 1 LOG_INSTALL 1
)

ExternalProject_Add_Step(mpv strip-binary
    DEPENDEES build
    ${mpv_add_debuglink}
    COMMENT "Stripping mpv binaries"
)

ExternalProject_Add_Step(mpv copy-binary
    DEPENDEES strip-binary

    # make sure dirs exist (copy won't create them)
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/doc
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv
    COMMAND ${CMAKE_COMMAND} -E make_directory ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv

    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/mpv.exe                           ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv.exe
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/mpv.com                           ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv.com
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/mpv.pdf                           ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/doc/manual.pdf
    COMMAND ${CMAKE_COMMAND} -E copy ${MINGW_INSTALL_PREFIX}/etc/fonts/fonts.conf   ${CMAKE_CURRENT_BINARY_DIR}/mpv-package/mpv/fonts.conf

    ${mpv_copy_debug}

    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/libmpv-2.dll                      ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/libmpv-2.dll
    COMMAND ${CMAKE_COMMAND} -E copy <BINARY_DIR>/libmpv.dll.a                      ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/libmpv.dll.a
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/client.h              ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/client.h
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/stream_cb.h           ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/stream_cb.h
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/render.h              ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/render.h
    COMMAND ${CMAKE_COMMAND} -E copy <SOURCE_DIR>/include/mpv/render_gl.h           ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev/include/mpv/render_gl.h

    COMMENT "Copying mpv binaries and dev files"
)


set(RENAME ${CMAKE_CURRENT_BINARY_DIR}/mpv-prefix/src/rename.sh)
file(WRITE ${RENAME}
"#!/bin/bash
cd $1
GIT=$(git rev-parse --short=7 HEAD)
mv $2 $2-git-\${GIT}")

ExternalProject_Add_Step(mpv copy-package-dir
    DEPENDEES copy-binary
    COMMAND chmod 755 ${RENAME}

    COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/mpv-package ${CMAKE_BINARY_DIR}/mpv-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}
    COMMAND ${RENAME} <SOURCE_DIR> ${CMAKE_BINARY_DIR}/mpv-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}

    COMMAND mv ${CMAKE_CURRENT_BINARY_DIR}/mpv-dev ${CMAKE_BINARY_DIR}/mpv-dev-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}
    COMMAND ${RENAME} <SOURCE_DIR> ${CMAKE_BINARY_DIR}/mpv-dev-${TARGET_CPU}${x86_64_LEVEL}-${BUILDDATE}

    COMMENT "Moving mpv package folder"
    LOG 1
)

# Keep Meson reconfigure behavior
force_meson_configure(mpv)

# Provide mpv-force-update target (required by your global "update" step),
# but pin mpv to the requested tag instead of resetting to @{u}.
ExternalProject_Add_Step(mpv force-update
    ALWAYS TRUE
    EXCLUDE_FROM_MAIN TRUE
    INDEPENDENT TRUE
    WORKING_DIRECTORY <SOURCE_DIR>
    COMMAND bash -c "git am --abort 2> /dev/null || true"
    COMMAND bash -c "git fetch --tags --force --prune --filter=tree:0 --no-recurse-submodules || true"
    COMMAND bash -c "git checkout -f v0.41.0"
    COMMAND bash -c "git submodule update --init --recursive || true"
    LOG 1
)
ExternalProject_Add_StepTargets(mpv force-update)

# Keep cleanup (but it must not require reset_head.sh anymore)
cleanup(mpv copy-package-dir)

