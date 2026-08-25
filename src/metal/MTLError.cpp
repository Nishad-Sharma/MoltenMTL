#include "MetalCInternal.hpp"

extern "C" {
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
