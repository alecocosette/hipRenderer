//
// Created by yeims on 7/20/2026.
//

#ifndef HITTABLE_LIST_H
#define HITTABLE_LIST_H

#include "hittable.h"
#include "rtweekend.h"

#include <vector>



class hittable_list : public hittable{
    public:
      std::vector<shared_ptr<hittable>> hittables;
      hittable_list(){}
    hittable_list(shared_ptr<hittable> object) { add(object); }
    void clear() { hittables.clear(); }
    void add(shared_ptr<hittable> obj) {
          hittables.push_back(obj);
      }
      bool hit(const ray& r, double ray_min, double ray_max, hit_record& rec) const override{
            hit_record temp_rec;
            bool hit_anything = false;
            auto closest_sight = ray_max;
            for (auto obj : hittables){
              if (obj->hit(r, ray_min, ray_max, temp_rec)){
                   hit_anything = true;
                   closest_sight = temp_rec.t;
                  rec = temp_rec;
              }
            }
            return hit_anything;
      }

};



#endif //HITTABLE_LIST_H
