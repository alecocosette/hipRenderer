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
    bool hit(const ray& r, double t_min, double t_max, hit_record& rec) const override {
        vec3 oc = center - r.orig();
        auto a = r.dir().length_squared();
        auto h = dot(r.dir(),oc);
        auto c = dot(oc,oc) - h*h;
        auto discriminant = h*h - a*c;
        if (discriminant < 0) return false;

        auto sqrtd = sqrt(discriminant);
        auto root = (h - sqrtd) / a;
        if (root <= t_min || t_max <= root) {
            root = (h + sqrtd) / a;
            if (root <= t_min) return false;
        }
        rec.t = root;
        rec.p = r.whereAt(rec.t);
        rec.normal = (rec.p - center) / radius;
        return true;

    }

private:
    point3 center;
    double radius;
};



#endif //SPHERE_H
