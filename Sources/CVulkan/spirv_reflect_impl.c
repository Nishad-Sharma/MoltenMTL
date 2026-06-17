// Compile SPIRV-Reflect exactly once.
// The Vulkan SDK ships the implementation at Source/SPIRV-Reflect/spirv_reflect.c.
// Package.swift adds that directory to the C include search path so the
// quoted include below resolves to the SDK's copy — same pattern as VMA.cpp.
#include "spirv_reflect.c"
