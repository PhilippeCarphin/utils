cmake_minimum_required(VERSION 3.10)

project(TEMPLATE C)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/cmake/modules)

# Find BASH
set(BASH_DEV_DIR "$ENV{BASH_DEV_DIR}" CACHE PATH "Path to root of bash install")
if(NOT BASH_DEV_DIR)
    message(WARNING "Specify -DBASH_DEV_DIR=<path to bash root> or set BASH_DEV_DIR environment variable")
else()
    find_file(BASH_MAKEFILE_INC Makefile.inc HINTS ${BASH_DEV_DIR}/lib/bash)
    add_custom_command(
        OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/my-builtins.so
        BYPRODUCTS ${CMAKE_CURRENT_BINARY_DIR}/shell-split.o
        COMMAND make "BASH_DEV_DIR=${BASH_DEV_DIR}" my_build_dir=${CMAKE_CURRENT_BINARY_DIR}
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/src/shell-split.c
        WORKING_DIRECTORY ${CMAKE_SOURCE_DIR}/src
    )
    add_custom_target(my-builtins ALL DEPENDS my-builtins.so)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/my-builtins.so DESTINATION libexec/philutils)
    install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/etc/profile.d/my-builtins.sh DESTINATION etc/profile.d)
    add_library(_mb EXCLUDE_FROM_ALL SHARED src/shell-split.c)
    target_include_directories(_mb PRIVATE ${BASH_DEV_DIR}/include ${BASH_DEV_DIR}/include/include ${BASH_DEV_DIR}/include/bash/builtins ${BASH_DEV_DIR}/lib/bash ${BASH_DEV_DIR}/include/bash ${BASH_DEV_DIR}/include/bash/include)
endif()


if("${CMAKE_INSTALL_PREFIX}" STREQUAL "/usr/local")
    set(CMAKE_INSTALL_PREFIX ${CMAKE_BINARY_DIR}/install CACHE FILEPATH "CMake Installation prefix for ${PROJECT_NAME}" FORCE)
    message(STATUS "Setting CMAKE_INSTALL_PREFIX to ${CMAKE_INSTALL_PREFIX}")
endif()

include(CTest)
add_custom_target(check COMMAND CTEST_OUTPUT_ON_FAILURE=true ${CMAKE_CTEST_COMMAND})

include(orgmanpages)
orgmanpages_add_man_target()
install(DIRECTORY bin/ DESTINATION bin USE_SOURCE_PERMISSIONS PATTERN *.swp EXCLUDE)
install(DIRECTORY libexec/philutils DESTINATION libexec USE_SOURCE_PERMISSIONS PATTERN *.swp EXCLUDE)
install(DIRECTORY etc/ DESTINATION etc USE_SOURCE_PERMISSIONS PATTERN *.swp EXCLUDE)
