# Create C API

The goal is to create a metal 4 like C API that can be used from zig or other languages. 
Same concept as MoltenMTL but has a public C API instead of a swift API.
Metal 4 cpp is used as a guide but does not need to comfort 100%.
metal-cpp and vulkan are he backend.

## Public C API naming

- Use `MMTL` for public types, `mmtl` for functions, and `MMTL_` for constants.
- Use Vulkan-style action-first function names. The first handle argument already
  identifies the object that owns or receives the operation, so do not translate
  C++ receiver names into the C symbol. For example, use
  `mmtlCreateBuffer(device, ...)`, never `mmtlDeviceNewBuffer(...)`.
- Use established Vulkan-style forms where they make the operation clearer, such
  as `mmtlQueueSubmit(...)`, `mmtlQueueWaitIdle(...)`, and `mmtlCmdDispatchThreads(...)`.
- Keep struct fields and local variables in `camelCase`.

Use Metal 4 as the semantic reference and implement narrow vertical slices in both backends:

Device, queue, allocator and command buffer.
Buffer plus compute dispatch.
Texture, sampler and argument table.
Render pipeline, attachment map and triangle.
Presentation.
BLAS/TLAS and inline ray queries.
