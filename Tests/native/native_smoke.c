#include <stdio.h>

int runDeviceQueueSmoke(void);
int runBufferComputeSmoke(void);
int runOutputTextureSmoke(void);
int runPixelFormatSmoke(void);
int runRayQuerySmoke(const char* shaderPath);
int runSampledTextureSmoke(const char* shaderPath);

int main(int argumentCount, char** arguments)
{
    if (argumentCount != 3) {
        fprintf(
            stderr,
            "usage: native-smoke <ray-query-shader> <sampled-texture-shader>\n");
        return 1;
    }

    if (runDeviceQueueSmoke() != 0 ||
        runBufferComputeSmoke() != 0 ||
        runOutputTextureSmoke() != 0 ||
        runPixelFormatSmoke() != 0 ||
        runRayQuerySmoke(arguments[1]) != 0 ||
        runSampledTextureSmoke(arguments[2]) != 0) {
        return 1;
    }

    puts("all native C API smoke tests passed");
    return 0;
}
