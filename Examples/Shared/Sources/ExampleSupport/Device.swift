import MoltenMTL

/// Creates the default device + a command queue (traps with a clear message if there's
/// no Vulkan-capable GPU).
public func makeDeviceAndQueue() -> (MTLDevice, MTLCommandQueue) {
    guard let device = MTLCreateSystemDefaultDevice() else {
        fatalError("No Vulkan-capable GPU found")
    }
    return (device, device.makeCommandQueue()!)
}
