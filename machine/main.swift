//
//  main.swift
//  machine
//
//  Created by baude on 3/3/21.
//


import Foundation
import Virtualization
import SwiftTerm
import Cocoa


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
    var memory = 1073741824
    var diskSize = 20
    /// Validates the configuration provided for a vm
    ///   - Throws:
    ///       - `MachineConfigurationError.insufficientMemory`
    ///       if memory is less than 512MB
    func validate() throws         {
        print(self.memory)
        if self.memory < 512 {
            throw MachineConfigurationError.insufficientMemory(needed: 1073741824)
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

class ConsoleViewController: NSViewController, TerminalViewDelegate {
    
    private lazy var terminalView: TerminalView = {
        let terminalView = TerminalView()
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        terminalView.terminalDelegate = self
        return terminalView
    }()
    
    private var readPipe: Pipe?
    private var writePipe: Pipe?
        
    override func loadView() {
        view = NSView()
    }
    
    deinit {
        readPipe?.fileHandleForReading.readabilityHandler = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(terminalView)
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: view.topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            terminalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }
    
    func configure(with readPipe: Pipe, writePipe: Pipe) {
        self.readPipe = readPipe
        self.writePipe = writePipe
        
        readPipe.fileHandleForReading.readabilityHandler = { [weak self] pipe in
            let data = pipe.availableData
            if let strongSelf = self {
                DispatchQueue.main.sync {
                    strongSelf.terminalView.feed(byteArray: [UInt8](data)[...])
                }
            }
        }
    }
    
    func sizeChanged(source: TerminalView, newCols: Int, newRows: Int) {
        
    }
    
    func setTerminalTitle(source: TerminalView, title: String) {
        
    }
    
    func send(source: TerminalView, data: ArraySlice<UInt8>) {
        writePipe?.fileHandleForWriting.write(Data(data))
    }
    
    func scrolled(source: TerminalView, position: Double) {
        
    }
    func hostCurrentDirectoryUpdate (source: TerminalView, directory: String?) {
        
    }

    func bell (source: TerminalView) {
        
    }
    func requestOpenLink (source: TerminalView, link: String, params: [String:String]) {
        
    }


}


/// Podman machine represents the commands needed to manage
/// virtual machines.
class PodmanMachine :NSObject, VZVirtualMachineDelegate {
    //private var memorySize :UInt64
    private var mc :MachineConfiguration
    private var virtualMachine: VZVirtualMachine! = nil
    var readPipe = Pipe()
    var writePipe = Pipe()
    
    private lazy var consoleWindow: NSWindow = {
        let viewController = ConsoleViewController()
        viewController.configure(with: readPipe, writePipe: writePipe)
        return NSWindow(contentViewController: viewController)
    }()
    
    private lazy var consoleWindowController: NSWindowController = {
        let windowController = NSWindowController(window: consoleWindow)
        return windowController
    }()
    
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
        let kernel = URL(fileURLWithPath: "/Users/baude/.podman/vmlinuz")
        let ramdisk = URL(fileURLWithPath: "/Users/baude/.podman/initrd")
        let bootloader    = VZLinuxBootLoader(kernelURL: kernel)
        bootloader.initialRamdiskURL = ramdisk
        bootloader.commandLine = "console=hvc0"
    
//         let readPipe = Pipe()
//         let writePipe = Pipe()
        
        
        let serial = VZVirtioConsoleDeviceSerialPortConfiguration()
        serial.attachment = VZFileHandleSerialPortAttachment(fileHandleForReading: self.readPipe.fileHandleForReading, fileHandleForWriting: self.writePipe.fileHandleForWriting)
        
        
        
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
        print(self.virtualMachine.hashValue)
        
    }
    /// Starts a virtual machine
    ///   - Throws:
    ///      - `virtualMachineError.unableToStart` when container state is not stopped
    func start()  {
        print("3")
        print(self.virtualMachine.canStart)
        print(self.virtualMachine.hashValue)
        
        self.virtualMachine.start { result in
            switch result {
            case .success:
                print("1")
                return
            case .failure(let error):
                print("2")
                NSLog("failed: \(result)")
                NSLog("failed to start vm: \(error)")
                exit(1)
            }
        }
        print("4")
        print(self.virtualMachine.`self`())
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

    func openConsole() {
        print("open console")
        consoleWindow.setContentSize(NSSize(width: 400, height: 300))
        consoleWindow.title = "Console"
        consoleWindowController.showWindow(nil)
  
    }
    
} // end of class

let memory = 1073741824
var mc = NewMachineConfiguration(memory: memory, diskSize: 20)
do {
    try mc.validate()
    let pm = PodmanMachine(mc: mc)
    try pm.configure()
    pm.start()
    pm.openConsole()
    
}catch {
    NSLog("failed \(error)")
}



print("Hello, World!")

var runloop = RunLoop.current
var d = Date.init(timeIntervalSinceNow: 1.0)

while(runloop.run(mode: RunLoop.Mode.default, before: d)) {
    // pass
}

