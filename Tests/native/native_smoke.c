#include <stdio.h>

int runDeviceQueueSmoke(void);
int runBufferComputeSmoke(void);
int runOutputTextureSmoke(void);
int runRayQuerySmoke(void);

int main(void)
{
    if (runDeviceQueueSmoke() != 0 ||
        runBufferComputeSmoke() != 0 ||
        runOutputTextureSmoke() != 0 ||
        runRayQuerySmoke() != 0) {
        return 1;
    }

    puts("all native C API smoke tests passed");
    return 0;
}
