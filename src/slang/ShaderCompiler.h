#pragma once

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct ShaderCompiler ShaderCompiler;

typedef uint32_t ShaderTarget;
enum {
    ShaderTargetMsl = 0,
    ShaderTargetSpirv = 1,
};

typedef uint32_t ShaderStage;
enum {
    ShaderStageVertex = 0,
    ShaderStageFragment = 1,
    ShaderStageCompute = 2,
};

typedef uint32_t ShaderStatus;
enum {
    ShaderStatusSuccess = 0,
    ShaderStatusCompilationFailed = 1,
    ShaderStatusInvalidArgument = 2,
    ShaderStatusOutOfMemory = 3,
    ShaderStatusInternalError = 4,
};

typedef struct ShaderCompileDescriptor {
    ShaderTarget target;
    ShaderStage stage;
    const uint8_t* source;
    size_t source_size;
    const char* module_name;
    const char* source_path;
    const char* entry_point;
    const char* profile;
    const char* const* search_paths;
    size_t search_path_count;
} ShaderCompileDescriptor;

typedef struct ShaderBlob {
    uint8_t* data;
    size_t size;
} ShaderBlob;

typedef struct ShaderCompileOutput {
    ShaderBlob code;
    ShaderBlob diagnostics;
} ShaderCompileOutput;

ShaderCompiler* ShaderCompilerCreate(void);
void ShaderCompilerDestroy(ShaderCompiler* compiler);
ShaderStatus ShaderCompilerCompile(
    ShaderCompiler* compiler,
    const ShaderCompileDescriptor* descriptor,
    ShaderCompileOutput* output);
void ShaderCompileOutputFree(ShaderCompileOutput* output);

#ifdef __cplusplus
}
#endif
