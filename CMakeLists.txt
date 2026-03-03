cmake_minimum_required(VERSION 3.16)
project(hotpants C)

set(CMAKE_C_STANDARD 99)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF)

option(BUILD_EXTRACTKERNONES "Build extractkernOnes helper binary" ON)

find_package(CFITSIO QUIET)
if(CFITSIO_FOUND)
    set(HP_CFITSIO_INCLUDE_DIRS "${CFITSIO_INCLUDE_DIRS}")
    set(HP_CFITSIO_LIBRARIES "${CFITSIO_LIBRARIES}")
else()
    find_path(HP_CFITSIO_INCLUDE_DIR fitsio.h)
    find_library(HP_CFITSIO_LIBRARY cfitsio)
    if(NOT HP_CFITSIO_INCLUDE_DIR OR NOT HP_CFITSIO_LIBRARY)
        message(FATAL_ERROR "CFITSIO not found. Set CFITSIO_DIR or CMAKE_PREFIX_PATH to your CFITSIO install.")
    endif()
    set(HP_CFITSIO_INCLUDE_DIRS "${HP_CFITSIO_INCLUDE_DIR}")
    set(HP_CFITSIO_LIBRARIES "${HP_CFITSIO_LIBRARY}")
endif()

function(hp_add_target target_name)
    add_executable(${target_name} ${ARGN})
    target_include_directories(${target_name} PRIVATE
        "${CMAKE_CURRENT_SOURCE_DIR}"
        ${HP_CFITSIO_INCLUDE_DIRS}
    )
    target_link_libraries(${target_name} PRIVATE ${HP_CFITSIO_LIBRARIES})

    if(NOT MSVC)
        target_link_libraries(${target_name} PRIVATE m)
    endif()

    if(MSVC)
        target_compile_definitions(${target_name} PRIVATE
            _CRT_SECURE_NO_WARNINGS
            _USE_MATH_DEFINES
        )
    endif()
endfunction()

hp_add_target(hotpants
    main.c
    vargs.c
    alard.c
    functions.c
)

hp_add_target(extractkern
    extractkern.c
)

hp_add_target(maskim
    maskim.c
)

if(BUILD_EXTRACTKERNONES)
    hp_add_target(extractkernOnes
        extractkernOnes.c
    )
endif()
