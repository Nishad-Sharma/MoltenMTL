#pragma once

#include "../Foundation/FoundationInternal.hpp"

#include <Metal/Metal.hpp>
#include <Metal/MTL4AccelerationStructure.hpp>

#include <Metal/Metal.h>

inline MTL::Size nativeSize(MTLSize size) { return MTL::Size(size.width, size.height, size.depth); }
inline MTL::Origin nativeOrigin(MTLOrigin origin) { return MTL::Origin(origin.x, origin.y, origin.z); }
inline MTL::Region nativeRegion(MTLRegion region) { return MTL::Region(region.origin.x, region.origin.y, region.origin.z, region.size.width, region.size.height, region.size.depth); }
inline MTL4::BufferRange nativeRange(MTL4BufferRange range) { return MTL4::BufferRange{range.address, range.length}; }
