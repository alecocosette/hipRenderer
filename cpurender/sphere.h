//
// Created by yeims on 7/20/2026.
//

#ifndef SPHERE_H
#define SPHERE_H

#include "hittable.h"
#include "rtweekend.h"


class sphere : public hittable{
    public:
    sphere(const point3& center, double radius) : center(center), radius(std::max(0.0, radius)) {}
    bool hit(const ray& r, interval ray_t, hit_record& rec) const override  {
        vec3 oc = center - r.orig();
        auto a = r.dir().length_squared();
        auto h = dot(r.dir(),oc);
        auto c = dot(oc,oc) - h*h;
        auto discriminant = h*h - a*c;
        if (discriminant < 0) return false;

        auto sqrtd = sqrt(discriminant);
        auto root = (h - sqrtd) / a;
        if (!ray_t.surrounds(root)) {
            root = (h + sqrtd) / a;
            if (!ray_t.surrounds(root)) return false;
        }
        rec.t = root;
        rec.p = r.whereAt(rec.t);
        rec.normal = unit_vector(rec.p - center);
        if (root > ray_t.max) return false;
        return true;

    }

private:
    point3 center;
    double radius;
};



#endif //SPHERE_H
