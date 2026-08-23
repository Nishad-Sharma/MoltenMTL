Texture2D<float4> inputTextures[2] : register(t0);
SamplerState textureSampler : register(s0);
RWTexture2D<float4> outputTexture : register(u2);

[numthreads(2, 2, 1)]
void sampleTextures(uint3 dispatchThreadID : SV_DispatchThreadID)
{
    uint2 position = dispatchThreadID.xy;
    float2 uv = (float2(position) + 0.5f) / float2(2.0f, 2.0f);
    float4 first = inputTextures[0].SampleLevel(textureSampler, uv, 0.0f);
    float4 second = inputTextures[1].SampleLevel(textureSampler, uv, 0.0f);
    outputTexture[position] = first * 0.25f + second * 0.75f;
}
