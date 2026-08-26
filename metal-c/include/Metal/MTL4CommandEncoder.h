#pragma once
#include <Metal/MTLTypes.h>
#ifdef __cplusplus
extern "C" {
#endif
typedef struct MTL4CommandEncoder MTL4CommandEncoder;
MTL_C_OPTIONS(uint64_t, MTL4VisibilityOptions) {
    MTL4VisibilityOptionNone = 0,
    MTL4VisibilityOptionDevice = 1,
    MTL4VisibilityOptionResourceAlias = 2
};
METAL_C_EXPORT void MTL4CommandEncoderBarrierAfterEncoderStages(MTL4CommandEncoder* encoder, MTLStages after, MTLStages before, MTL4VisibilityOptions visibility);
METAL_C_EXPORT void MTL4CommandEncoderEndEncoding(MTL4CommandEncoder* encoder);
#ifdef __cplusplus
}
#endif
