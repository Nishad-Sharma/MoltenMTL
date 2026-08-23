RaytracingAccelerationStructure scene : register(t0);
RWStructuredBuffer<uint> results : register(u1);

[numthreads(3, 1, 1)]
void traceScene(uint3 dispatchThreadID : SV_DispatchThreadID)
{
    uint index = dispatchThreadID.x;
    RayDesc queryRay;
    queryRay.Origin = index == 0 ? float3(0.0f, 0.0f, -1.0f)
        : (index == 1 ? float3(3.0f, 0.0f, -1.0f)
        : float3(6.0f, 6.0f, -1.0f));
    queryRay.Direction = float3(0.0f, 0.0f, 1.0f);
    queryRay.TMin = 0.001f;
    queryRay.TMax = 10.0f;

    RayQuery<RAY_FLAG_ACCEPT_FIRST_HIT_AND_END_SEARCH | RAY_FLAG_FORCE_OPAQUE> rayQuery;
    rayQuery.TraceRayInline(scene, RAY_FLAG_NONE, 0xff, queryRay);
    rayQuery.Proceed();
    results[index] = rayQuery.CommittedStatus() != COMMITTED_NOTHING;
}
