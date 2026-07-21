cmake_minimum_required(VERSION 3.10)

project(gurt)

set(CMAKE_CXX_STANDARD 17)

add_executable(gurt gurt.cpp
        hittable.cpp
        hittable.h
        sphere.cpp
        sphere.h
        hittable_list.cpp
        hittable_list.h)