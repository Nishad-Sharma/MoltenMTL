#include "ShaderCompiler.h"

#include <slang-com-ptr.h>
#include <slang.h>

#include <cstdlib>
#include <cstring>
#include <new>
#include <string>

namespace {

void appendDiagnostics(slang::IBlob* blob, std::string& diagnostics)
{
    if (!blob || blob->getBufferSize() == 0) {
        return;
    }
    if (!diagnostics.empty() && diagnostics.back() != '\n') {
        diagnostics.push_back('\n');
    }
    diagnostics.append(
        static_cast<const char*>(blob->getBufferPointer()),
        blob->getBufferSize());
}

bool copyBytes(const void* bytes, size_t size, ShaderBlob* output)
{
    if (size == 0) {
        return true;
    }
    output->data = static_cast<uint8_t*>(std::malloc(size));
    if (!output->data) {
        return false;
    }
    std::memcpy(output->data, bytes, size);
    output->size = size;
    return true;
}

bool copyDiagnostics(const std::string& diagnostics, ShaderBlob* output)
{
    return copyBytes(diagnostics.data(), diagnostics.size(), output);
}

SlangCompileTarget compileTarget(ShaderTarget target)
{
    switch (target) {
    case ShaderTargetMsl:
        return SLANG_METAL;
    case ShaderTargetSpirv:
        return SLANG_SPIRV;
    default:
        return SLANG_TARGET_UNKNOWN;
    }
}

SlangStage shaderStage(ShaderStage stage)
{
    switch (stage) {
    case ShaderStageVertex:
        return SLANG_STAGE_VERTEX;
    case ShaderStageFragment:
        return SLANG_STAGE_FRAGMENT;
    case ShaderStageCompute:
        return SLANG_STAGE_COMPUTE;
    default:
        return SLANG_STAGE_NONE;
    }
}

} // namespace

struct ShaderCompiler {
    Slang::ComPtr<slang::IGlobalSession> global_session;
};

extern "C" ShaderCompiler* ShaderCompilerCreate(void)
{
    ShaderCompiler* compiler = new (std::nothrow) ShaderCompiler();
    if (!compiler) {
        return nullptr;
    }
    const SlangResult result = slang_createGlobalSession(
        SLANG_API_VERSION,
        compiler->global_session.writeRef());
    if (SLANG_FAILED(result)) {
        delete compiler;
        return nullptr;
    }
    return compiler;
}

extern "C" void ShaderCompilerDestroy(ShaderCompiler* compiler)
{
    delete compiler;
}

extern "C" ShaderStatus ShaderCompilerCompile(
    ShaderCompiler* compiler,
    const ShaderCompileDescriptor* descriptor,
    ShaderCompileOutput* output)
{
    if (output) {
        *output = {};
    }
    if (!compiler || !descriptor || !output ||
        !descriptor->module_name || !descriptor->source_path ||
        (!descriptor->source && descriptor->source_size != 0) ||
        !descriptor->entry_point || !descriptor->profile ||
        (!descriptor->search_paths && descriptor->search_path_count != 0)) {
        return ShaderStatusInvalidArgument;
    }

    try {
        std::string diagnostics;
        const SlangCompileTarget target = compileTarget(descriptor->target);
        const SlangStage stage = shaderStage(descriptor->stage);
        if (target == SLANG_TARGET_UNKNOWN || stage == SLANG_STAGE_NONE) {
            return ShaderStatusInvalidArgument;
        }

        slang::TargetDesc target_descriptor = {};
        target_descriptor.format = target;
        target_descriptor.profile = compiler->global_session->findProfile(descriptor->profile);
        if (target_descriptor.profile == SLANG_PROFILE_UNKNOWN) {
            diagnostics = "Slang could not find the requested profile";
            if (!copyDiagnostics(diagnostics, &output->diagnostics)) {
                return ShaderStatusOutOfMemory;
            }
            return ShaderStatusInvalidArgument;
        }

        slang::SessionDesc session_descriptor = {};
        session_descriptor.targets = &target_descriptor;
        session_descriptor.targetCount = 1;
        session_descriptor.searchPaths = descriptor->search_paths;
        session_descriptor.searchPathCount =
            static_cast<SlangInt>(descriptor->search_path_count);

        Slang::ComPtr<slang::ISession> session;
        SlangResult result = compiler->global_session->createSession(
            session_descriptor,
            session.writeRef());
        if (SLANG_FAILED(result)) {
            diagnostics = "Slang could not create a compilation session";
            if (!copyDiagnostics(diagnostics, &output->diagnostics)) {
                return ShaderStatusOutOfMemory;
            }
            return ShaderStatusInternalError;
        }

        const char* source_bytes = descriptor->source
            ? reinterpret_cast<const char*>(descriptor->source)
            : "";
        const std::string source(source_bytes, descriptor->source_size);
        Slang::ComPtr<slang::IBlob> diagnostic_blob;
        Slang::ComPtr<slang::IModule> module;
        module = session->loadModuleFromSourceString(
            descriptor->module_name,
            descriptor->source_path,
            source.c_str(),
            diagnostic_blob.writeRef());
        appendDiagnostics(diagnostic_blob, diagnostics);
        if (!module) {
            if (!copyDiagnostics(diagnostics, &output->diagnostics)) {
                return ShaderStatusOutOfMemory;
            }
            return ShaderStatusCompilationFailed;
        }

        Slang::ComPtr<slang::IEntryPoint> entry_point;
        diagnostic_blob.setNull();
        result = module->findAndCheckEntryPoint(
            descriptor->entry_point,
            stage,
            entry_point.writeRef(),
            diagnostic_blob.writeRef());
        appendDiagnostics(diagnostic_blob, diagnostics);
        if (SLANG_FAILED(result)) {
            if (!copyDiagnostics(diagnostics, &output->diagnostics)) {
                return ShaderStatusOutOfMemory;
            }
            return ShaderStatusCompilationFailed;
        }

        slang::IComponentType* components[] = { module.get(), entry_point.get() };
        Slang::ComPtr<slang::IComponentType> program;
        diagnostic_blob.setNull();
        result = session->createCompositeComponentType(
            components,
            2,
            program.writeRef(),
            diagnostic_blob.writeRef());
        appendDiagnostics(diagnostic_blob, diagnostics);
        if (SLANG_FAILED(result)) {
            if (!copyDiagnostics(diagnostics, &output->diagnostics)) {
                return ShaderStatusOutOfMemory;
            }
            return ShaderStatusCompilationFailed;
        }

        Slang::ComPtr<slang::IComponentType> linked_program;
        diagnostic_blob.setNull();
        result = program->link(
            linked_program.writeRef(),
            diagnostic_blob.writeRef());
        appendDiagnostics(diagnostic_blob, diagnostics);
        if (SLANG_FAILED(result)) {
            if (!copyDiagnostics(diagnostics, &output->diagnostics)) {
                return ShaderStatusOutOfMemory;
            }
            return ShaderStatusCompilationFailed;
        }

        Slang::ComPtr<slang::IBlob> code;
        diagnostic_blob.setNull();
        result = linked_program->getEntryPointCode(
            0,
            0,
            code.writeRef(),
            diagnostic_blob.writeRef());
        appendDiagnostics(diagnostic_blob, diagnostics);
        if (SLANG_FAILED(result) || !code) {
            if (!copyDiagnostics(diagnostics, &output->diagnostics)) {
                return ShaderStatusOutOfMemory;
            }
            return ShaderStatusCompilationFailed;
        }

        if (!copyBytes(
                code->getBufferPointer(),
                code->getBufferSize(),
                &output->code)) {
            return ShaderStatusOutOfMemory;
        }
        if (!copyDiagnostics(diagnostics, &output->diagnostics)) {
            ShaderCompileOutputFree(output);
            return ShaderStatusOutOfMemory;
        }
        return ShaderStatusSuccess;
    } catch (const std::bad_alloc&) {
        ShaderCompileOutputFree(output);
        return ShaderStatusOutOfMemory;
    } catch (...) {
        ShaderCompileOutputFree(output);
        return ShaderStatusInternalError;
    }
}

extern "C" void ShaderCompileOutputFree(ShaderCompileOutput* output)
{
    if (!output) {
        return;
    }
    std::free(output->code.data);
    std::free(output->diagnostics.data);
    *output = {};
}
