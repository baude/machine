//
//  main.swift
//  machine
//
//  Created by baude on 3/3/21.
//


import Foundation
import Virtualization

/// Errors for interacting with machine configurations
enum MachineConfigurationError: Error{
    case insufficientMemory(needed: Int)
    case invalidConfiguration
}

/// Errors for interacting with virtual machines
enum VirtualMachineError: Error {
    case invalidStateToStart
    case invalidStateToStop
    case invalidConfiguration
    case unableToCreateVM
    case unableToStop
    case unableToStart
}

/// machine configuration feeds a virtual machine
struct MachineConfiguration    {
    var name: String?
    var memory = 512
    var diskSize = 20
    /// Validates the configuration provided for a vm
    ///   - Throws:
    ///       - `MachineConfigurationError.insufficientMemory`
    ///       if memory is less than 512MB
    func validate() throws         {
        print(self.memory)
        if self.memory < 512 {
            throw MachineConfigurationError.insufficientMemory(needed: 512)
        }
    }
}

/// creates a new object of type MachineConfiguration
///   - Returns : `MachineConfiguration`
func NewMachineConfiguration(memory: Int, diskSize: Int) -> MachineConfiguration {
    var machineConfig = MachineConfiguration()
    machineConfig.diskSize = diskSize
    machineConfig.memory = memory
    
    return machineConfig
}

/// Podman machine represents the commands needed to manage
/// virtual machines.
class PodmanMachine :NSObject, VZVirtualMachineDelegate {
    //private var memorySize :UInt64
    private var mc :MachineConfiguration
    private var virtualMachine: VZVirtualMachine! = nil
    init(mc: MachineConfiguration){
        // todo: this needs to be simplified for when you have a name of the virtual machine
        // and you just want to start/stop it.  should just take name.  then second method
        // to create it.
        // Still need to do cpus, kernel, ramdisk, blockdevice, network, oh my
        self.mc = mc
    }
    /// Configures a new virtual machine
    ///   - Throws:
    ///
    func configure() throws {
        let kernel = URL(fileURLWithPath: "/Users/baude/Downloads/vmlinuz")
        let ramdisk = URL(fileURLWithPath: "/Users/baude/Downloads/initrd.img")
        let bootloader    = VZLinuxBootLoader(kernelURL: kernel)
        bootloader.initialRamdiskURL = ramdisk
        bootloader.commandLine = "console=hvc0"
        
        let serial = VZVirtioConsoleDeviceSerialPortConfiguration()
        serial.attachment = VZFileHandleSerialPortAttachment(fileHandleForReading: FileHandle.standardOutput, fileHandleForWriting: FileHandle.standardInput)
        
        let config = VZVirtualMachineConfiguration()
        config.bootLoader = bootloader
        config.serialPorts = [serial]
        config.memorySize = UInt64(self.mc.memory)
        config.cpuCount = 1
        
        do {
            try config.validate()
        } catch {
        NSLog("[!] Failure \(error)")
            throw error
        }
        self.virtualMachine =     VZVirtualMachine(configuration: config)
        self.virtualMachine.delegate = self
        
        
    }
    /// Starts a virtual machine
    ///   - Throws:
    ///      - `virtualMachineError.unableToStart` when container state is not stopped
    func start()  throws {
        self.virtualMachine.start { result in
            switch result {
            case .success:
                return
            case .failure(_):
                NSLog("failed to start vm: \(result)")
                break
            }
        }
        throw VirtualMachineError.unableToStart
    }
    /// Stops a virtual machine
    ///   - Throws:
    ///       - `virtualMachineError.invalidStateToStop`
    ///         when container state is not running
    func stop() throws {
        let canStop = self.virtualMachine.canRequestStop
        if canStop == false {
            throw VirtualMachineError.invalidStateToStop
        }
        try self.virtualMachine.requestStop()
                    }
   
} // end of class

var mc = NewMachineConfiguration(memory: 1024, diskSize: 20)
do {
    try mc.validate()
    let pm = PodmanMachine(mc: mc)
    try pm.configure()
}catch {
    NSLog("failed \(error)")
}



print("Hello, World!")

    

