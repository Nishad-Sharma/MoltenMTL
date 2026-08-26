#include "FoundationInternal.hpp"

extern "C" {
int64_t NSErrorGetCode(const NSError* error)
{
    return error == nullptr ? 0 : native<NS::Error>(error)->code();
}

const char* NSErrorGetLocalizedDescription(const NSError* error)
{
    if (error == nullptr) return "";
    NS::String* description = native<NS::Error>(error)->localizedDescription();
    return description == nullptr ? "" : description->utf8String();
}
}
