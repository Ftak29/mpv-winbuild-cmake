if(NOT DEFINED MPV_VERSION_FILE)
  message(FATAL_ERROR "MPV_VERSION_FILE is not set")
endif()

file(READ "${MPV_VERSION_FILE}" VER_RAW)
string(REGEX REPLACE "[\r\n]+" "" VER "${VER_RAW}")
file(WRITE "${MPV_VERSION_FILE}" "EzTvLibWin-1.0-${VER}\n")

message(STATUS "Patched MPV_VERSION: EzTvLibWin-1.0-${VER}")
