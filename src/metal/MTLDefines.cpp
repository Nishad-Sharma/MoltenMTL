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

int64_t MTLErrorGetCode(const MTLError* error)
{
    return error == nullptr ? 0 : native<NS::Error>(error)->code();
}

const char* MTLErrorGetLocalizedDescription(const MTLError* error)
{
    if (error == nullptr) return "";
    NS::String* description = native<NS::Error>(error)->localizedDescription();
    return description == nullptr ? "" : description->utf8String();
}
}
