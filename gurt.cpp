//
// Created by yeims on 5/20/2026.
//
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <iostream>
int main() {
    int image_width = 256;
    int image_height = 256;
    std::cout << "P3\n" << image_width << " " << image_height << "\n255\n";
    for (int i = 0; i < image_width; i++){
        for (int j = 0; j < image_height; j++) {
            auto r = double(i)/(image_width-1);
            auto g = double(j)/(image_height-1);
            auto b = 0.0;
            int ir = int(255.99*r);
            int ig = int(255.99*g);
            int ib = int(255.99*b);
            std::cout << ir << " " << ig << " " << ib << "\n";
        }
    }

}
