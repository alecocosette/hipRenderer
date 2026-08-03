cmake_minimum_required(VERSION 3.10)

project(gurt)

set(CMAKE_CXX_STANDARD 17)

add_executable(gurt cpurender/gurt.cpp
        cpurender/hittable.cpp
        cpurender/hittable.h
        cpurender/sphere.cpp
        cpurender/sphere.h
        cpurender/hittable_list.cpp
        cpurender/hittable_list.h
        cpurender/rtweekend.h
        cpurender/interval.h
        cpurender/camera.h
        cpurender/material.h
)