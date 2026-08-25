#ifndef METAL_C_INTERNAL_HPP
#define METAL_C_INTERNAL_HPP

#define METALCPP_SYMBOL_VISIBILITY_HIDDEN
#include <Metal/Metal.hpp>
#include <Metal/MTL4AccelerationStructure.hpp>
#include <QuartzCore/QuartzCore.hpp>

#include <Metal/Metal.h>
#include <QuartzCore/CAMetalLayer.h>

template <typename Native, typename C>
static Native* native(C* object) { return reinterpret_cast<Native*>(object); }

template <typename Native, typename C>
static const Native* native(const C* object) { return reinterpret_cast<const Native*>(object); }

template <typename C, typename Native>
static C* cobject(Native* object) { return reinterpret_cast<C*>(object); }

inline NS::String* nsString(const char* string)
{
    return string == nullptr ? nullptr : NS::String::string(string, NS::UTF8StringEncoding);
}

inline void returnError(NS::Error* error, MTLError** output)
{
    if (output == nullptr) return;
    *output = nullptr;
    if (error != nullptr) {
        error->retain();
        *output = cobject<MTLError>(error);
    }
}

inline MTL::Size nativeSize(MTLSize size) { return MTL::Size(size.width, size.height, size.depth); }
inline MTL::Origin nativeOrigin(MTLOrigin origin) { return MTL::Origin(origin.x, origin.y, origin.z); }
inline MTL::Region nativeRegion(MTLRegion region) { return MTL::Region(region.origin.x, region.origin.y, region.origin.z, region.size.width, region.size.height, region.size.depth); }
inline MTL4::BufferRange nativeRange(MTL4BufferRange range) { return MTL4::BufferRange{range.address, range.length}; }

#endif
