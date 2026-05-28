//
// Created by yeims on 5/20/2026.
//
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iostream>
#include "color.h"
#include "vec3.h"

int main() {
    int image_width = 256;
    int image_height = 256;
    std::cout << "P3\n" << image_width << " " << image_height << "\n255\n";
    for (int i = 0; i < image_width; i++){
        for (int j = 0; j < image_height; j++) {
            auto pixel_color = color(double(j)/(image_width-1), double(i)/(image_height-1), 0);
            write_color(std::cout, pixel_color);
        }
    }
    std::clog << "Done\n";

}
