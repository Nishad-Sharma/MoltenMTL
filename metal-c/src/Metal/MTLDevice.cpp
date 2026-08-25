#include "MetalCInternal.hpp"

extern "C" {
MTLDevice* MTLCreateSystemDefaultDevice(void)
{
    return cobject<MTLDevice>(MTL::CreateSystemDefaultDevice());
}

const char* MTLDeviceGetName(const MTLDevice* device)
{
    if (device == nullptr) return "";
    NS::String* name = native<MTL::Device>(device)->name();
    return name == nullptr ? "" : name->utf8String();
}

bool MTLDeviceSupportsMetal4(const MTLDevice* device)
{
    return device != nullptr && const_cast<MTL::Device*>(native<MTL::Device>(device))->supportsFamily(MTL::GPUFamilyMetal4);
}

MTLBuffer* MTLDeviceNewBuffer(MTLDevice* device, size_t length, MTLResourceOptions options)
{
    if (device == nullptr) return nullptr;
    return cobject<MTLBuffer>(native<MTL::Device>(device)->newBuffer(length, static_cast<MTL::ResourceOptions>(options)));
}

MTLBuffer* MTLDeviceNewBufferWithBytes(MTLDevice* device, const void* bytes, size_t length, MTLResourceOptions options)
{
    if (device == nullptr || (bytes == nullptr && length != 0)) return nullptr;
    return cobject<MTLBuffer>(native<MTL::Device>(device)->newBuffer(bytes, length, static_cast<MTL::ResourceOptions>(options)));
}

MTLTexture* MTLDeviceNewTexture(MTLDevice* device, const MTLTextureDescriptor* descriptor)
{
    if (device == nullptr || descriptor == nullptr) return nullptr;
    return cobject<MTLTexture>(native<MTL::Device>(device)->newTexture(native<MTL::TextureDescriptor>(descriptor)));
}

MTL4CommandAllocator* MTLDeviceNewCommandAllocator(MTLDevice* device)
{
    return device == nullptr ? nullptr : cobject<MTL4CommandAllocator>(native<MTL::Device>(device)->newCommandAllocator());
}

MTL4CommandBuffer* MTLDeviceNewCommandBuffer(MTLDevice* device)
{
    return device == nullptr ? nullptr : cobject<MTL4CommandBuffer>(native<MTL::Device>(device)->newCommandBuffer());
}

MTL4CommandQueue* MTLDeviceNewMTL4CommandQueue(MTLDevice* device)
{
    return device == nullptr ? nullptr : cobject<MTL4CommandQueue>(native<MTL::Device>(device)->newMTL4CommandQueue());
}

MTL4Compiler* MTLDeviceNewCompiler(MTLDevice* device, const MTL4CompilerDescriptor* descriptor, MTLError** error)
{
    if (error != nullptr) *error = nullptr;
    if (device == nullptr || descriptor == nullptr) return nullptr;
    NS::Error* nativeError = nullptr;
    auto* compiler = native<MTL::Device>(device)->newCompiler(native<MTL4::CompilerDescriptor>(descriptor), &nativeError);
    if (compiler == nullptr) returnError(nativeError, error);
    return cobject<MTL4Compiler>(compiler);
}

MTL4ArgumentTable* MTLDeviceNewArgumentTable(MTLDevice* device, const MTL4ArgumentTableDescriptor* descriptor, MTLError** error)
{
    if (error != nullptr) *error = nullptr;
    if (device == nullptr || descriptor == nullptr) return nullptr;
    NS::Error* nativeError = nullptr;
    auto* table = native<MTL::Device>(device)->newArgumentTable(native<MTL4::ArgumentTableDescriptor>(descriptor), &nativeError);
    if (table == nullptr) returnError(nativeError, error);
    return cobject<MTL4ArgumentTable>(table);
}

MTLAccelerationStructureSizes MTLDeviceGetAccelerationStructureSizes(MTLDevice* device, const MTL4AccelerationStructureDescriptor* descriptor)
{
    if (device == nullptr || descriptor == nullptr) return MTLAccelerationStructureSizes{0, 0, 0};
    const auto sizes = native<MTL::Device>(device)->accelerationStructureSizes(native<MTL4::AccelerationStructureDescriptor>(descriptor));
    return MTLAccelerationStructureSizes{sizes.accelerationStructureSize, sizes.buildScratchBufferSize, sizes.refitScratchBufferSize};
}

MTLAccelerationStructure* MTLDeviceNewAccelerationStructure(MTLDevice* device, size_t size)
{
    return device == nullptr ? nullptr : cobject<MTLAccelerationStructure>(native<MTL::Device>(device)->newAccelerationStructure(size));
}

MTLResidencySet* MTLDeviceNewResidencySet(MTLDevice* device, const MTLResidencySetDescriptor* descriptor, MTLError** error)
{
    if (error != nullptr) *error = nullptr;
    if (device == nullptr || descriptor == nullptr) return nullptr;
    NS::Error* nativeError = nullptr;
    auto* set = native<MTL::Device>(device)->newResidencySet(native<MTL::ResidencySetDescriptor>(descriptor), &nativeError);
    if (set == nullptr) returnError(nativeError, error);
    return cobject<MTLResidencySet>(set);
}

MTLSharedEvent* MTLDeviceNewSharedEvent(MTLDevice* device)
{
    return device == nullptr ? nullptr : cobject<MTLSharedEvent>(native<MTL::Device>(device)->newSharedEvent());
}
}
