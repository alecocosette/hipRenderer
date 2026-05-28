//
// Created by yeims on 5/27/2026.
//

#ifndef RAY_H
#define RAY_H

#include "vec3.h"
class ray{
  public:
    ray(){}
    ray(const point3& orig, const vec3& dir): orig_(orig), dir_(dir){}
    const point3& orig() const { return orig_; };
    const vec3& dir() const { return dir_; };
    point3 whereAt(double t) const{
      return orig_ + t * dir_;
    }
    private:
      point3 orig_;
      vec3 dir_;
};


#endif //RAY_H
