#include "MetalCInternal.hpp"

extern "C" {
MTLAutoreleasePool* MTLAutoreleasePoolCreate(void)
{
    return cobject<MTLAutoreleasePool>(NS::AutoreleasePool::alloc()->init());
}

void* MTLRetain(void* object)
{
    if (object != nullptr) reinterpret_cast<NS::Object*>(object)->retain();
    return object;
}

void MTLRelease(void* object)
{
    if (object != nullptr) reinterpret_cast<NS::Object*>(object)->release();
}
}
