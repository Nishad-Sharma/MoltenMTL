#ifndef METAL_C_MTL4_COMMAND_ENCODER_H
#define METAL_C_MTL4_COMMAND_ENCODER_H
#include <Metal/MTLTypes.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4CommandEncoder MTL4CommandEncoder;
typedef uint64_t MTL4VisibilityOptions;
#define MTL4VisibilityOptionNone ((MTL4VisibilityOptions)0)
#define MTL4VisibilityOptionDevice ((MTL4VisibilityOptions)1)
#define MTL4VisibilityOptionResourceAlias ((MTL4VisibilityOptions)2)
METAL_C_EXPORT void MTL4CommandEncoderBarrierAfterEncoderStages(MTL4CommandEncoder* encoder, MTLStages after, MTLStages before, MTL4VisibilityOptions visibility);
METAL_C_EXPORT void MTL4CommandEncoderEndEncoding(MTL4CommandEncoder* encoder);
#ifdef __cplusplus
}
#endif
#endif
