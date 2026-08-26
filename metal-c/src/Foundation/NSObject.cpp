#include "FoundationInternal.hpp"

extern "C" {
NSAutoreleasePool* NSAutoreleasePoolCreate(void)
{
    return cobject<NSAutoreleasePool>(NS::AutoreleasePool::alloc()->init());
}

void* NSRetain(void* object)
{
    if (object != nullptr) reinterpret_cast<NS::Object*>(object)->retain();
    return object;
}

void NSRelease(void* object)
{
    if (object != nullptr) reinterpret_cast<NS::Object*>(object)->release();
}
}
