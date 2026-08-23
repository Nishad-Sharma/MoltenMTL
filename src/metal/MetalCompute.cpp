#include "MetalBackendInternal.hpp"

#include <limits>
#include <new>

static void setSlangDiagnostics(MMTLDevice device, slang::IBlob* diagnostics)
{
    device->lastShaderError.clear();
    if (diagnostics == nullptr || diagnostics->getBufferPointer() == nullptr) {
        return;
    }

    const char* message = static_cast<const char*>(diagnostics->getBufferPointer());
    size_t messageLength = diagnostics->getBufferSize();
    if (messageLength > 0 && message[messageLength - 1] == '\0') {
        --messageLength;
    }
    device->lastShaderError.assign(message, messageLength);
}

static void setMetalError(
    MMTLDevice device,
    NS::Error* error,
    const char* fallbackMessage)
{
    device->lastShaderError = fallbackMessage;
    if (error == nullptr) {
        return;
    }

    NS::String* description = error->localizedDescription();
    const char* message = description == nullptr ? nullptr : description->utf8String();
    if (message != nullptr && message[0] != '\0') {
        device->lastShaderError = message;
    }
}

static bool isValidSize(MMTLSize size)
{
    return size.width > 0 && size.height > 0 && size.depth > 0;
}

static MTL::Size nativeSize(MMTLSize size)
{
    return MTL::Size(size.width, size.height, size.depth);
}

extern "C" {

MMTLResult mmtlCreateLibrary(
    MMTLDevice device,
    const MMTLLibraryDescriptor* descriptor,
    MMTLLibrary* outLibrary)
{
    if (device == nullptr || descriptor == nullptr || descriptor->source == nullptr ||
        descriptor->source[0] == '\0' || outLibrary == nullptr ||
        (descriptor->searchPathCount > 0 && descriptor->searchPaths == nullptr)) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outLibrary = nullptr;

    std::lock_guard<std::mutex> lock(device->shaderCompilerMutex);
    device->lastShaderError.clear();

    slang::TargetDesc targetDescriptor = {};
    targetDescriptor.format = SLANG_METAL;

    slang::SessionDesc sessionDescriptor = {};
    sessionDescriptor.targets = &targetDescriptor;
    sessionDescriptor.targetCount = 1;
    sessionDescriptor.searchPaths = descriptor->searchPaths;
    sessionDescriptor.searchPathCount = descriptor->searchPathCount;

    Slang::ComPtr<slang::ISession> session;
    if (SLANG_FAILED(device->slangGlobalSession->createSession(
            sessionDescriptor,
            session.writeRef()))) {
        device->lastShaderError = "Slang failed to create a compiler session";
        return MMTL_ERROR_COMPILATION_FAILED;
    }

    const char* moduleName = descriptor->moduleName == nullptr || descriptor->moduleName[0] == '\0'
        ? "mmtlShader"
        : descriptor->moduleName;
    const char* sourcePath = descriptor->sourcePath == nullptr || descriptor->sourcePath[0] == '\0'
        ? "mmtlShader.hlsl"
        : descriptor->sourcePath;

    Slang::ComPtr<slang::IBlob> diagnostics;
    Slang::ComPtr<slang::IModule> module(session->loadModuleFromSourceString(
        moduleName,
        sourcePath,
        descriptor->source,
        diagnostics.writeRef()));
    setSlangDiagnostics(device, diagnostics);
    if (module == nullptr) {
        return MMTL_ERROR_COMPILATION_FAILED;
    }

    auto* library = new (std::nothrow) MMTLLibrary_T{};
    if (library == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    library->device = device;
    library->session = session;
    library->module = module;

    *outLibrary = library;
    return MMTL_SUCCESS;
}

void mmtlDestroyLibrary(MMTLLibrary library)
{
    if (library == nullptr) {
        return;
    }
    delete library;
}

MMTLResult mmtlCreateComputePipelineState(
    MMTLDevice device,
    MMTLLibrary library,
    const char* functionName,
    MMTLComputePipelineState* outPipelineState)
{
    if (device == nullptr || library == nullptr || library->device != device ||
        functionName == nullptr ||
        functionName[0] == '\0' || outPipelineState == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outPipelineState = nullptr;

    std::lock_guard<std::mutex> lock(device->shaderCompilerMutex);
    device->lastShaderError.clear();

    Slang::ComPtr<slang::IBlob> diagnostics;
    Slang::ComPtr<slang::IEntryPoint> entryPoint;
    SlangResult slangResult = library->module->findAndCheckEntryPoint(
        functionName,
        SLANG_STAGE_COMPUTE,
        entryPoint.writeRef(),
        diagnostics.writeRef());
    setSlangDiagnostics(device, diagnostics);
    if (SLANG_FAILED(slangResult) || entryPoint == nullptr) {
        if (device->lastShaderError.empty()) {
            device->lastShaderError = "Slang could not find the requested compute entry point";
        }
        return MMTL_ERROR_COMPILATION_FAILED;
    }

    slang::IComponentType* components[] = {library->module, entryPoint};
    Slang::ComPtr<slang::IComponentType> program;
    diagnostics.setNull();
    slangResult = library->session->createCompositeComponentType(
        components,
        2,
        program.writeRef(),
        diagnostics.writeRef());
    setSlangDiagnostics(device, diagnostics);
    if (SLANG_FAILED(slangResult) || program == nullptr) {
        return MMTL_ERROR_COMPILATION_FAILED;
    }

    Slang::ComPtr<slang::IComponentType> linkedProgram;
    diagnostics.setNull();
    slangResult = program->link(linkedProgram.writeRef(), diagnostics.writeRef());
    setSlangDiagnostics(device, diagnostics);
    if (SLANG_FAILED(slangResult) || linkedProgram == nullptr) {
        return MMTL_ERROR_COMPILATION_FAILED;
    }

    Slang::ComPtr<slang::IBlob> metalSource;
    diagnostics.setNull();
    slangResult = linkedProgram->getEntryPointCode(
        0,
        0,
        metalSource.writeRef(),
        diagnostics.writeRef());
    setSlangDiagnostics(device, diagnostics);
    if (SLANG_FAILED(slangResult) || metalSource == nullptr ||
        metalSource->getBufferPointer() == nullptr) {
        return MMTL_ERROR_COMPILATION_FAILED;
    }

    ScopedAutoreleasePool pool;
    auto* sourceString = NS::String::string(
        static_cast<const char*>(metalSource->getBufferPointer()),
        NS::UTF8StringEncoding);
    auto* libraryDescriptor = MTL4::LibraryDescriptor::alloc()->init();
    if (sourceString == nullptr || libraryDescriptor == nullptr) {
        if (libraryDescriptor != nullptr) {
            libraryDescriptor->release();
        }
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    libraryDescriptor->setSource(sourceString);

    NS::Error* error = nullptr;
    MTL::Library* nativeLibrary = device->compiler->newLibrary(libraryDescriptor, &error);
    libraryDescriptor->release();
    if (nativeLibrary == nullptr) {
        setMetalError(device, error, "Metal failed to compile Slang-generated MSL");
        return MMTL_ERROR_COMPILATION_FAILED;
    }

    auto* name = NS::String::string(functionName, NS::UTF8StringEncoding);
    auto* functionDescriptor = MTL4::LibraryFunctionDescriptor::alloc()->init();
    auto* pipelineDescriptor = MTL4::ComputePipelineDescriptor::alloc()->init();
    if (name == nullptr || functionDescriptor == nullptr || pipelineDescriptor == nullptr) {
        if (functionDescriptor != nullptr) {
            functionDescriptor->release();
        }
        if (pipelineDescriptor != nullptr) {
            pipelineDescriptor->release();
        }
        nativeLibrary->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    functionDescriptor->setLibrary(nativeLibrary);
    functionDescriptor->setName(name);
    pipelineDescriptor->setComputeFunctionDescriptor(functionDescriptor);
    functionDescriptor->release();

    MTL::ComputePipelineState* native =
        device->compiler->newComputePipelineState(pipelineDescriptor, nullptr, &error);
    pipelineDescriptor->release();
    nativeLibrary->release();
    if (native == nullptr) {
        setMetalError(device, error, "Metal failed to create the compute pipeline");
        return MMTL_ERROR_COMPILATION_FAILED;
    }

    auto* pipelineState = new (std::nothrow) MMTLComputePipelineState_T{native};
    if (pipelineState == nullptr) {
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outPipelineState = pipelineState;
    return MMTL_SUCCESS;
}

const char* mmtlGetLastShaderError(MMTLDevice device)
{
    if (device == nullptr) {
        return "";
    }
    return device->lastShaderError.c_str();
}

void mmtlDestroyComputePipelineState(MMTLComputePipelineState pipelineState)
{
    if (pipelineState == nullptr) {
        return;
    }
    pipelineState->native->release();
    delete pipelineState;
}

MMTLResult mmtlCreateArgumentTable(
    MMTLDevice device,
    const MMTLArgumentTableDescriptor* descriptor,
    MMTLArgumentTable* outArgumentTable)
{
    if (device == nullptr || descriptor == nullptr || outArgumentTable == nullptr ||
        (descriptor->maxBufferBindCount == 0 && descriptor->maxTextureBindCount == 0)) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    *outArgumentTable = nullptr;

    ScopedAutoreleasePool pool;
    auto* nativeDescriptor = MTL4::ArgumentTableDescriptor::alloc()->init();
    if (nativeDescriptor == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }
    nativeDescriptor->setMaxBufferBindCount(descriptor->maxBufferBindCount);
    nativeDescriptor->setMaxTextureBindCount(descriptor->maxTextureBindCount);
    nativeDescriptor->setInitializeBindings(true);

    NS::Error* error = nullptr;
    MTL4::ArgumentTable* native = device->native->newArgumentTable(nativeDescriptor, &error);
    nativeDescriptor->release();
    if (native == nullptr) {
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    MTL::Allocation** bufferBindings = nullptr;
    if (descriptor->maxBufferBindCount > 0) {
        bufferBindings =
            new (std::nothrow) MTL::Allocation*[descriptor->maxBufferBindCount]();
    }
    MTL::Allocation** textureBindings = nullptr;
    if (descriptor->maxTextureBindCount > 0) {
        textureBindings =
            new (std::nothrow) MTL::Allocation*[descriptor->maxTextureBindCount]();
    }
    if ((descriptor->maxBufferBindCount > 0 && bufferBindings == nullptr) ||
        (descriptor->maxTextureBindCount > 0 && textureBindings == nullptr)) {
        delete[] textureBindings;
        delete[] bufferBindings;
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    auto* argumentTable = new (std::nothrow) MMTLArgumentTable_T{
        native,
        bufferBindings,
        textureBindings,
        descriptor->maxBufferBindCount,
        descriptor->maxTextureBindCount,
    };
    if (argumentTable == nullptr) {
        delete[] textureBindings;
        delete[] bufferBindings;
        native->release();
        return MMTL_ERROR_OUT_OF_MEMORY;
    }

    *outArgumentTable = argumentTable;
    return MMTL_SUCCESS;
}

void mmtlDestroyArgumentTable(MMTLArgumentTable argumentTable)
{
    if (argumentTable == nullptr) {
        return;
    }

    for (uint32_t index = 0; index < argumentTable->maxBufferBindCount; ++index) {
        if (argumentTable->bufferBindings[index] != nullptr) {
            argumentTable->bufferBindings[index]->release();
        }
    }
    for (uint32_t index = 0; index < argumentTable->maxTextureBindCount; ++index) {
        if (argumentTable->textureBindings[index] != nullptr) {
            argumentTable->textureBindings[index]->release();
        }
    }
    delete[] argumentTable->textureBindings;
    delete[] argumentTable->bufferBindings;
    argumentTable->native->release();
    delete argumentTable;
}

MMTLResult mmtlSetArgumentTableBuffer(
    MMTLArgumentTable argumentTable,
    uint32_t bindingIndex,
    MMTLBuffer buffer,
    uint64_t offset)
{
    if (argumentTable == nullptr || bindingIndex >= argumentTable->maxBufferBindCount) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (buffer == nullptr) {
        if (offset != 0) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
        argumentTable->native->setAddress(0, bindingIndex);
    } else {
        if (offset >= buffer->native->length()) {
            return MMTL_ERROR_INVALID_ARGUMENT;
        }
        buffer->native->retain();
        argumentTable->native->setAddress(buffer->native->gpuAddress() + offset, bindingIndex);
    }

    if (argumentTable->bufferBindings[bindingIndex] != nullptr) {
        argumentTable->bufferBindings[bindingIndex]->release();
    }
    argumentTable->bufferBindings[bindingIndex] =
        buffer == nullptr ? nullptr : buffer->native;
    return MMTL_SUCCESS;
}

MMTLResult mmtlSetArgumentTableAccelerationStructure(
    MMTLArgumentTable argumentTable,
    uint32_t bindingIndex,
    MMTLAccelerationStructure accelerationStructure)
{
    if (argumentTable == nullptr || bindingIndex >= argumentTable->maxBufferBindCount) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    if (accelerationStructure == nullptr) {
        argumentTable->native->setResource(MTL::ResourceID{}, bindingIndex);
    } else {
        accelerationStructure->native->retain();
        argumentTable->native->setResource(
            accelerationStructure->native->gpuResourceID(),
            bindingIndex);
    }

    if (argumentTable->bufferBindings[bindingIndex] != nullptr) {
        argumentTable->bufferBindings[bindingIndex]->release();
    }
    argumentTable->bufferBindings[bindingIndex] =
        accelerationStructure == nullptr ? nullptr : accelerationStructure->native;
    return MMTL_SUCCESS;
}

MMTLResult mmtlSetArgumentTableTexture(
    MMTLArgumentTable argumentTable,
    uint32_t bindingIndex,
    MMTLTexture texture)
{
    if (argumentTable == nullptr || bindingIndex >= argumentTable->maxTextureBindCount) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    if (texture == nullptr) {
        argumentTable->native->setTexture(MTL::ResourceID{}, bindingIndex);
    } else {
        texture->native->retain();
        argumentTable->native->setTexture(texture->native->gpuResourceID(), bindingIndex);
    }

    if (argumentTable->textureBindings[bindingIndex] != nullptr) {
        argumentTable->textureBindings[bindingIndex]->release();
    }
    argumentTable->textureBindings[bindingIndex] =
        texture == nullptr ? nullptr : texture->native;
    return MMTL_SUCCESS;
}

MMTLResult mmtlCmdDispatchThreads(
    MMTLCommandBuffer commandBuffer,
    MMTLComputePipelineState pipelineState,
    MMTLArgumentTable argumentTable,
    MMTLSize threadsPerGrid,
    MMTLSize threadsPerThreadgroup)
{
    if (commandBuffer == nullptr || pipelineState == nullptr ||
        !isValidSize(threadsPerGrid) || !isValidSize(threadsPerThreadgroup)) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (commandBuffer->state != CommandBufferState::recording) {
        return MMTL_ERROR_INVALID_STATE;
    }

    const MMTLResult residencyResult = ensureResidencySet(commandBuffer);
    if (residencyResult != MMTL_SUCCESS) {
        return residencyResult;
    }
    addResidentAllocation(commandBuffer, pipelineState->native);
    if (argumentTable != nullptr) {
        for (uint32_t index = 0; index < argumentTable->maxBufferBindCount; ++index) {
            MTL::Allocation* resource = argumentTable->bufferBindings[index];
            if (resource != nullptr) {
                addResidentAllocation(commandBuffer, resource);
            }
        }
        for (uint32_t index = 0; index < argumentTable->maxTextureBindCount; ++index) {
            MTL::Allocation* resource = argumentTable->textureBindings[index];
            if (resource != nullptr) {
                addResidentAllocation(commandBuffer, resource);
            }
        }
    }
    commandBuffer->residencySet->commit();

    ScopedAutoreleasePool pool;
    MTL4::ComputeCommandEncoder* encoder = commandBuffer->native->computeCommandEncoder();
    if (encoder == nullptr) {
        return MMTL_ERROR_INTERNAL;
    }
    encoder->setComputePipelineState(pipelineState->native);
    encoder->setArgumentTable(argumentTable == nullptr ? nullptr : argumentTable->native);
    encoder->dispatchThreads(nativeSize(threadsPerGrid), nativeSize(threadsPerThreadgroup));
    encoder->barrierAfterStages(
        MTL::StageDispatch,
        MTL::StageDispatch | MTL::StageBlit | MTL::StageAccelerationStructure,
        MTL4::VisibilityOptionDevice);
    encoder->endEncoding();
    return MMTL_SUCCESS;
}

MMTLResult mmtlCmdCopyTexture(
    MMTLCommandBuffer commandBuffer,
    MMTLTexture sourceTexture,
    MMTLTexture destinationTexture)
{
    if (commandBuffer == nullptr || sourceTexture == nullptr || destinationTexture == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (commandBuffer->state != CommandBufferState::recording) {
        return MMTL_ERROR_INVALID_STATE;
    }
    if ((sourceTexture->descriptor.usage & MMTL_TEXTURE_USAGE_COPY_SOURCE) == 0 ||
        (destinationTexture->descriptor.usage & MMTL_TEXTURE_USAGE_COPY_DESTINATION) == 0 ||
        sourceTexture->descriptor.width != destinationTexture->descriptor.width ||
        sourceTexture->descriptor.height != destinationTexture->descriptor.height ||
        sourceTexture->descriptor.pixelFormat != destinationTexture->descriptor.pixelFormat) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    const MMTLResult residencyResult = ensureResidencySet(commandBuffer);
    if (residencyResult != MMTL_SUCCESS) {
        return residencyResult;
    }
    addResidentAllocation(commandBuffer, sourceTexture->native);
    addResidentAllocation(commandBuffer, destinationTexture->native);
    commandBuffer->residencySet->commit();

    ScopedAutoreleasePool pool;
    MTL4::ComputeCommandEncoder* encoder = commandBuffer->native->computeCommandEncoder();
    if (encoder == nullptr) {
        return MMTL_ERROR_INTERNAL;
    }
    encoder->copyFromTexture(sourceTexture->native, destinationTexture->native);
    encoder->barrierAfterStages(
        MTL::StageBlit,
        MTL::StageDispatch | MTL::StageBlit | MTL::StageAccelerationStructure,
        MTL4::VisibilityOptionDevice);
    encoder->endEncoding();
    return MMTL_SUCCESS;
}

MMTLResult mmtlCmdCopyTextureToBuffer(
    MMTLCommandBuffer commandBuffer,
    MMTLTexture sourceTexture,
    MMTLBuffer destinationBuffer,
    uint64_t destinationOffset,
    uint64_t destinationBytesPerRow)
{
    if (commandBuffer == nullptr || sourceTexture == nullptr || destinationBuffer == nullptr) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    if (commandBuffer->state != CommandBufferState::recording) {
        return MMTL_ERROR_INVALID_STATE;
    }
    if ((sourceTexture->descriptor.usage & MMTL_TEXTURE_USAGE_COPY_SOURCE) == 0 ||
        destinationBytesPerRow % MMTL_TEXTURE_COPY_BYTES_PER_ROW_ALIGNMENT != 0) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    MTL::PixelFormat pixelFormat;
    uint32_t bytesPerPixel = 0;
    if (!getNativePixelFormat(
            sourceTexture->descriptor.pixelFormat,
            &pixelFormat,
            &bytesPerPixel)) {
        return MMTL_ERROR_INTERNAL;
    }
    (void)pixelFormat;

    const uint64_t tightBytesPerRow =
        static_cast<uint64_t>(sourceTexture->descriptor.width) * bytesPerPixel;
    if (destinationBytesPerRow < tightBytesPerRow ||
        sourceTexture->descriptor.height >
            std::numeric_limits<uint64_t>::max() / destinationBytesPerRow) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }
    const uint64_t destinationBytesPerImage =
        destinationBytesPerRow * sourceTexture->descriptor.height;
    const uint64_t destinationLength = destinationBuffer->native->length();
    if (destinationOffset > destinationLength ||
        destinationBytesPerImage > destinationLength - destinationOffset) {
        return MMTL_ERROR_INVALID_ARGUMENT;
    }

    const MMTLResult residencyResult = ensureResidencySet(commandBuffer);
    if (residencyResult != MMTL_SUCCESS) {
        return residencyResult;
    }
    addResidentAllocation(commandBuffer, sourceTexture->native);
    addResidentAllocation(commandBuffer, destinationBuffer->native);
    commandBuffer->residencySet->commit();

    ScopedAutoreleasePool pool;
    MTL4::ComputeCommandEncoder* encoder = commandBuffer->native->computeCommandEncoder();
    if (encoder == nullptr) {
        return MMTL_ERROR_INTERNAL;
    }
    encoder->copyFromTexture(
        sourceTexture->native,
        0,
        0,
        MTL::Origin(0, 0, 0),
        MTL::Size(
            sourceTexture->descriptor.width,
            sourceTexture->descriptor.height,
            1),
        destinationBuffer->native,
        destinationOffset,
        destinationBytesPerRow,
        destinationBytesPerImage);
    encoder->barrierAfterStages(
        MTL::StageBlit,
        MTL::StageDispatch | MTL::StageBlit | MTL::StageAccelerationStructure,
        MTL4::VisibilityOptionDevice);
    encoder->endEncoding();
    return MMTL_SUCCESS;
}

} // extern "C"
