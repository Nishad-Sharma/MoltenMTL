# metal-c

A focused C wrapper over Apple's metal-cpp headers. The public headers mirror
metal-cpp's `Metal/` layout and expose the Metal 4 path needed for compute-based
inline ray tracing:

- Metal 4 command allocators, command buffers, queues, compute encoders, barriers,
  argument tables, shader compilation, and compute pipelines
- buffers, textures, shared events, and residency sets
- triangle BLAS and instance TLAS construction/refit for inline ray queries
- `CAMetalLayer` drawables for presentation

Standard Metal APIs are wrapped only where Metal 4 continues to use them, such as
resources, pipeline state objects, acceleration-structure storage, events, and
drawables. Include `<Metal/Metal.h>` and `<QuartzCore/CAMetalLayer.h>`.

The library targets macOS 26 and newer and builds as `metal-c` with Zig:

```sh
zig build
```

Every returned object follows Metal retain/release ownership. Release it with
`MTLRelease`; use `MTLAutoreleasePoolCreate` on threads that call Metal APIs.
