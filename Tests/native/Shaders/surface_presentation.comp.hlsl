RWTexture2D<float4> outputTexture : register(u0);

[numthreads(16, 16, 1)]
void writeSurface(uint3 dispatchThreadID : SV_DispatchThreadID)
{
    outputTexture[dispatchThreadID.xy] = float4(1.0f, 0.5f, 0.25f, 1.0f);
}
