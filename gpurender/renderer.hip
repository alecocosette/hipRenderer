// gpu/renderer.hip
// Naive one-thread-per-pixel HIP port of the CPU path tracer (RTIOW Book 1, Ch.13 scene).
// No virtual dispatch, no dynamic allocation inside the kernel — GPU kernels can't do either.
// Materials are a tagged struct (enum + params) instead of a class hierarchy.

#include <hip/hip_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <cmath>

// ---------- vec3 ----------
struct vec3 {
    double x, y, z;

    __host__ __device__ vec3() : x(0), y(0), z(0) {}
    __host__ __device__ vec3(double x, double y, double z) : x(x), y(y), z(z) {}

    __host__ __device__ vec3 operator+(const vec3& o) const { return vec3(x+o.x, y+o.y, z+o.z); }
    __host__ __device__ vec3 operator-(const vec3& o) const { return vec3(x-o.x, y-o.y, z-o.z); }
    __host__ __device__ vec3 operator*(double t) const { return vec3(x*t, y*t, z*t); }
    __host__ __device__ vec3 operator/(double t) const { return vec3(x/t, y/t, z/t); }
    __host__ __device__ vec3 operator-() const { return vec3(-x, -y, -z); }

    __host__ __device__ double length_squared() const { return x*x + y*y + z*z; }
    __host__ __device__ double length() const { return sqrt(length_squared()); }
};

__host__ __device__ inline vec3 operator*(double t, const vec3& v) { return v * t; }
__host__ __device__ inline double dot(const vec3& a, const vec3& b) { return a.x*b.x + a.y*b.y + a.z*b.z; }
__host__ __device__ inline vec3 unit_vector(const vec3& v) { return v / v.length(); }
__host__ __device__ inline vec3 reflect(const vec3& v, const vec3& n) { return v - 2*dot(v,n)*n; }

using point3 = vec3;
using color  = vec3;

// ---------- ray ----------
struct ray {
    point3 orig;
    vec3   dir;
    __host__ __device__ ray() {}
    __host__ __device__ ray(const point3& o, const vec3& d) : orig(o), dir(d) {}
    __host__ __device__ point3 at(double t) const { return orig + t*dir; }
};

// ---------- material (tagged struct, no vtable) ----------
enum MaterialType { LAMBERTIAN, METAL, DIELECTRIC };

struct Material {
    MaterialType type;
    color albedo;
    double fuzz;        // metal only
    double ref_idx;      // dielectric only
};

// ---------- sphere (flat data, no inheritance) ----------
struct Sphere {
    point3 center;
    double radius;
    Material mat;
};

struct hit_record {
    point3 p;
    vec3 normal;
    double t;
    bool front_face;
    Material mat;
};

__device__ inline void set_face_normal(hit_record& rec, const ray& r, const vec3& outward_normal) {
    rec.front_face = dot(r.dir, outward_normal) < 0;
    rec.normal = rec.front_face ? outward_normal : -outward_normal;
}

__device__ bool hit_sphere(const Sphere& s, const ray& r, double t_min, double t_max, hit_record& rec) {
    vec3 oc = s.center - r.orig;
    auto a = r.dir.length_squared();
    auto h = dot(r.dir, oc);
    auto c = oc.length_squared() - s.radius*s.radius;
    auto discriminant = h*h - a*c;
    if (discriminant < 0) return false;

    auto sqrtd = sqrt(discriminant);
    auto root = (h - sqrtd) / a;
    if (root <= t_min || t_max <= root) {
        root = (h + sqrtd) / a;
        if (root <= t_min || t_max <= root) return false;
    }

    rec.t = root;
    rec.p = r.at(rec.t);
    vec3 outward_normal = (rec.p - s.center) / s.radius;
    set_face_normal(rec, r, outward_normal);
    rec.mat = s.mat;
    return true;
}

// world is just an array of spheres — no hittable_list indirection needed
__device__ bool hit_world(const Sphere* spheres, int n, const ray& r, double t_min, double t_max, hit_record& rec) {
    hit_record temp_rec;
    bool hit_anything = false;
    double closest_so_far = t_max;

    for (int i = 0; i < n; i++) {
        if (hit_sphere(spheres[i], r, t_min, closest_so_far, temp_rec)) {
            hit_anything = true;
            closest_so_far = temp_rec.t;
            rec = temp_rec;
        }
    }
    return hit_anything;
}

// ---------- tiny per-thread RNG (xorshift) ----------
__device__ inline unsigned int xorshift32(unsigned int& state) {
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    return state;
}
__device__ inline double rand_double(unsigned int& state) {
    return (xorshift32(state) & 0xFFFFFF) / (double)0x1000000;
}
__device__ inline vec3 random_unit_vector(unsigned int& state) {
    // rejection sampling, GPU-friendly (bounded loop)
    while (true) {
        vec3 p(2*rand_double(state)-1, 2*rand_double(state)-1, 2*rand_double(state)-1);
        double lensq = p.length_squared();
        if (1e-160 < lensq && lensq <= 1.0) return p / sqrt(lensq);
    }
}

// ---------- material scatter (branch on tag — this is exactly the divergence week 4 removes) ----------
__device__ bool scatter(const Material& mat, const ray& r_in, const hit_record& rec,
                         color& attenuation, ray& scattered, unsigned int& rng_state) {
    if (mat.type == LAMBERTIAN) {
        vec3 scatter_direction = rec.normal + random_unit_vector(rng_state);
        if (scatter_direction.length_squared() < 1e-16) scatter_direction = rec.normal;
        scattered = ray(rec.p, scatter_direction);
        attenuation = mat.albedo;
        return true;
    }
    else if (mat.type == METAL) {
        vec3 reflected = reflect(unit_vector(r_in.dir), rec.normal);
        reflected = unit_vector(reflected) + (mat.fuzz * random_unit_vector(rng_state));
        scattered = ray(rec.p, reflected);
        attenuation = mat.albedo;
        return dot(scattered.dir, rec.normal) > 0;
    }
    else { // DIELECTRIC — simplified, no Fresnel/Schlick yet, just refraction-or-reflect stub
        attenuation = color(1.0, 1.0, 1.0);
        double ri = rec.front_face ? (1.0/mat.ref_idx) : mat.ref_idx;
        vec3 unit_direction = unit_vector(r_in.dir);
        vec3 reflected = reflect(unit_direction, rec.normal);
        scattered = ray(rec.p, reflected); // TODO: real refraction, matches CPU version's later chapters
        return true;
    }
}

// ---------- ray_color (iterative, NOT recursive — GPU kernels can't recurse) ----------
__device__ color ray_color(ray r, const Sphere* spheres, int n_spheres, int max_depth, unsigned int& rng_state) {
    color accumulated(1.0, 1.0, 1.0);

    for (int depth = 0; depth < max_depth; depth++) {
        hit_record rec;
        if (hit_world(spheres, n_spheres, r, 0.001, 1e18, rec)) {
            ray scattered;
            color attenuation;
            if (scatter(rec.mat, r, rec, attenuation, scattered, rng_state)) {
                accumulated = vec3(accumulated.x*attenuation.x, accumulated.y*attenuation.y, accumulated.z*attenuation.z);
                r = scattered;
            } else {
                return vec3(0,0,0);
            }
        } else {
            vec3 unit_direction = unit_vector(r.dir);
            auto a = 0.5*(unit_direction.y + 1.0);
            color sky = (1.0-a)*color(1.0,1.0,1.0) + a*color(0.5,0.7,1.0);
            return vec3(accumulated.x*sky.x, accumulated.y*sky.y, accumulated.z*sky.z);
        }
    }
    return vec3(0,0,0); // exceeded bounce depth
}

// ---------- the kernel: one thread per pixel ----------
__global__ void render_kernel(vec3* framebuffer, int width, int height,
                               point3 pixel00_loc, vec3 pixel_delta_u, vec3 pixel_delta_v,
                               point3 cam_center, int samples_per_pixel, int max_depth,
                               const Sphere* spheres, int n_spheres) {
    int i = blockIdx.x * blockDim.x + threadIdx.x; // column
    int j = blockIdx.y * blockDim.y + threadIdx.y; // row
    if (i >= width || j >= height) return;

    unsigned int rng_state = (j * width + i) * 9781u + 1u; // per-thread seed

    color pixel_color(0,0,0);
    for (int s = 0; s < samples_per_pixel; s++) {
        double du = rand_double(rng_state) - 0.5;
        double dv = rand_double(rng_state) - 0.5;
        vec3 pixel_sample = pixel00_loc
                           + ((i + du) * pixel_delta_u)
                           + ((j + dv) * pixel_delta_v);
        vec3 ray_dir = pixel_sample - cam_center;
        ray r(cam_center, ray_dir);
        pixel_color = pixel_color + ray_color(r, spheres, n_spheres, max_depth, rng_state);
    }
    pixel_color = pixel_color / (double)samples_per_pixel;

    framebuffer[j * width + i] = pixel_color;
}

// ---------- host-side gamma + write ----------
inline double linear_to_gamma(double linear) {
    return linear > 0 ? sqrt(linear) : 0;
}

void write_ppm(const char* filename, vec3* framebuffer, int width, int height) {
    std::ofstream out(filename);
    out << "P3\n" << width << " " << height << "\n255\n";
    for (int j = 0; j < height; j++) {
        for (int i = 0; i < width; i++) {
            vec3 c = framebuffer[j*width + i];
            double r = linear_to_gamma(c.x);
            double g = linear_to_gamma(c.y);
            double b = linear_to_gamma(c.z);
            int rb = int(256 * fmin(fmax(r, 0.0), 0.999));
            int gb = int(256 * fmin(fmax(g, 0.0), 0.999));
            int bb = int(256 * fmin(fmax(b, 0.0), 0.999));
            out << rb << ' ' << gb << ' ' << bb << '\n';
        }
    }
}

#define HIP_CHECK(x) do { \
    hipError_t err = (x); \
    if (err != hipSuccess) { \
        fprintf(stderr, "HIP error %s at %s:%d\n", hipGetErrorString(err), __FILE__, __LINE__); \
        exit(1); \
    } \
} while(0)

int main() {
    // ---- image ----
    const double aspect_ratio = 16.0 / 9.0;
    const int image_width = 400;
    int image_height = int(image_width / aspect_ratio);
    image_height = (image_height < 1) ? 1 : image_height;

    // ---- camera (matches CPU chapter 11/12 positionable camera, no defocus blur yet) ----
    point3 lookfrom(13,2,3);
    point3 lookat(0,0,0);
    vec3 vup(0,1,0);
    double vfov = 20.0;
    double focal_length = (lookfrom - lookat).length();

    double theta = vfov * M_PI / 180.0;
    double h = tan(theta/2);
    double viewport_height = 2 * h * focal_length;
    double viewport_width = viewport_height * ((double)image_width/image_height);

    vec3 w = unit_vector(lookfrom - lookat);
    vec3 u = unit_vector(vec3(vup.y*w.z - vup.z*w.y, vup.z*w.x - vup.x*w.z, vup.x*w.y - vup.y*w.x));
    vec3 v = vec3(w.y*u.z - w.z*u.y, w.z*u.x - w.x*u.z, w.x*u.y - w.y*u.x);

    vec3 viewport_u = viewport_width * u;
    vec3 viewport_v = viewport_height * (-v);

    vec3 pixel_delta_u = viewport_u / image_width;
    vec3 pixel_delta_v = viewport_v / image_height;

    point3 viewport_upper_left = lookfrom - (focal_length*w) - viewport_u/2 - viewport_v/2;
    point3 pixel00_loc = viewport_upper_left + 0.5 * (pixel_delta_u + pixel_delta_v);

    // ---- scene: ground + 3 spheres, same as CPU chapter 13 core trio ----
    const int n_spheres = 4;
    Sphere h_spheres[n_spheres] = {
        { point3(0,-1000,0), 1000, { LAMBERTIAN, color(0.5,0.5,0.5), 0, 0 } },   // ground
        { point3(0,1,0),     1.0,  { DIELECTRIC, color(1,1,1),       0, 1.5 } }, // glass
        { point3(-4,1,0),    1.0,  { LAMBERTIAN, color(0.4,0.2,0.1), 0, 0 } },   // diffuse
        { point3(4,1,0),     1.0,  { METAL,      color(0.7,0.6,0.5), 0.0, 0 } }  // metal
    };

    Sphere* d_spheres;
    HIP_CHECK(hipMalloc(&d_spheres, n_spheres * sizeof(Sphere)));
    HIP_CHECK(hipMemcpy(d_spheres, h_spheres, n_spheres * sizeof(Sphere), hipMemcpyHostToDevice));

    vec3* d_framebuffer;
    HIP_CHECK(hipMalloc(&d_framebuffer, image_width * image_height * sizeof(vec3)));

    dim3 threads(16, 16);
    dim3 blocks((image_width + threads.x - 1) / threads.x,
                (image_height + threads.y - 1) / threads.y);

    int samples_per_pixel = 50;
    int max_depth = 10;

    hipLaunchKernelGGL(render_kernel, blocks, threads, 0, 0,
                        d_framebuffer, image_width, image_height,
                        pixel00_loc, pixel_delta_u, pixel_delta_v, lookfrom,
                        samples_per_pixel, max_depth, d_spheres, n_spheres);
    HIP_CHECK(hipGetLastError());
    HIP_CHECK(hipDeviceSynchronize());

    vec3* h_framebuffer = (vec3*)malloc(image_width * image_height * sizeof(vec3));
    HIP_CHECK(hipMemcpy(h_framebuffer, d_framebuffer, image_width * image_height * sizeof(vec3), hipMemcpyDeviceToHost));

    write_ppm("gpu_image.ppm", h_framebuffer, image_width, image_height);

    printf("Done. Wrote gpu_image.ppm (%dx%d, %d spp)\n", image_width, image_height, samples_per_pixel);

    free(h_framebuffer);
    hipFree(d_framebuffer);
    hipFree(d_spheres);
    return 0;
}
