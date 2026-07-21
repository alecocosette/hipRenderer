//
// Created by yeims on 5/20/2026.
//
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fstream>
#include <iostream>
#include "color.h"
#include "vec3.h"
#include "ray.h"




double hit_sphere(const point3& center, double radius, const ray& r) {
    vec3 oc = center - r.orig();
    auto a = r.dir().length_squared();
    auto b = dot(r.dir(), oc);
    auto c = oc.length_squared() - radius*radius;
    auto discriminant = b*b - 4*a*c;

    if (discriminant < 0) {
        return -1.0;
    } else {
        return (b - std::sqrt(discriminant) ) / a;
    }
}

color ray_color(const ray& r) {
    auto t = hit_sphere(point3(0,0,-1), 0.5, r);
    if (t > 0.0) {
        vec3 N = unit_vector(r.whereAt(t) - vec3(0,0,-1));
        return 0.5*color(N.x()+1, N.y()+1, N.z()+1);
    }

    vec3 unit_direction = unit_vector(r.dir());
    auto a = 0.5*(unit_direction.y() + 1.0);
    return (1.0-a)*color(1.0, 1.0, 1.0) + a*color(0.5, 0.7, 1.0);
}
int main() {
    auto aspectRatio = 16.0 / 9.0;
    int image_width = 400;
    int image_height = int(image_width/aspectRatio);
    image_height = (image_height<1) ? 1 : image_height;
    auto viewport_height = 2.0;
    auto viewport_width = viewport_height * ((double)image_width/image_height);
    auto focal_length = 1.0;
    auto center = point3(0, 0, 0);
    auto viewport_u = vec3(viewport_width, 0, 0);
    auto viewport_v = vec3(0, -viewport_height, 0);
    auto pixel_delta_u = viewport_u/image_width;
    auto pixel_delta_v = viewport_v/image_height;
    auto viewport_up_left = center-vec3(0,0,focal_length)-viewport_u/2 -viewport_v/2;
    auto pixel100_loc = viewport_up_left + 0.5 * (pixel_delta_u + pixel_delta_v);



    std::ofstream outfile("image.ppm");
    outfile << "P3\n" << image_width << " " << image_height << "\n255\n";
    for (int i = 0; i < image_height; i++){
        for (int j = 0; j < image_width; j++) {
            auto pixel_center = pixel100_loc+(i*pixel_delta_u) + (j*pixel_delta_v);
            auto rayDir = pixel_center-center;
            ray r(center, rayDir);
            color pixelColor = ray_color(r);

            write_color(outfile, pixelColor);  // pass ofstream instead of cout
        }
    }
    std::clog << "Done\n";
    outfile.close();
    return 0;

}
