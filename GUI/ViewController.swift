//
// Copyright © 2019 osy86. All rights reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Cocoa

let eepromSize: UInt32 = 0x100000

class ViewController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTextDelegate {
    @IBOutlet weak var patchTextField: NSTextField!
    @IBOutlet weak var deviceComboBox: NSComboBox!
    @IBOutlet weak var uninstallCheckbox: NSButton!
    @IBOutlet weak var busySpinner: NSProgressIndicator!
    @IBOutlet weak var logTextView: NSTextView!
    @IBOutlet weak var flashButton: NSButton!
    
    var busy: Bool = false {
        willSet {
            DispatchQueue.main.async {
                if newValue {
                    self.flashButton.isEnabled = false
                    self.busySpinner.startAnimation(nil)
                } else {
                    self.flashButton.isEnabled = self.ready
                    self.busySpinner.stopAnimation(nil)
                }
            }
        }
    }
    
    var ready: Bool {
        get {
            !deviceComboBox.stringValue.isEmpty && !patchTextField.stringValue.isEmpty
        }
    }
    
    let tbpManager: TBPManager = TBPManager.init()
    
    var filterDevice: String?
    
    var devices: [String] = []
    
    // MARK: -
    // MARK: Display functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        if CommandLine.argc > 1 {
            filterDevice = CommandLine.arguments[1]
        }
        if CommandLine.argc > 2 {
            patchTextField.stringValue = CommandLine.arguments[2]
        }
        TBPLogger.sharedInstance().logger = { (line: String) in
            DispatchQueue.main.async {
                let smartScroll = self.logTextView.visibleRect.maxY == self.logTextView.bounds.maxY
                self.logTextView.textStorage?.append(NSAttributedString(string: line + "\n", attributes: [NSAttributedString.Key.foregroundColor : NSColor.controlTextColor]))
                if smartScroll {
                    self.logTextView.scrollToEndOfDocument(self)
                }
            }
        }
        refreshDevices()
    }
    
    @discardableResult
    func showAlert(message msg: String, alertStyle style: NSAlert.Style, showCancel: Bool = false) -> Bool {
        let alert = NSAlert()
        alert.messageText = msg
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        if showCancel {
            alert.addButton(withTitle: "Cancel")
        }
        return alert.runModal() == .alertFirstButtonReturn
    }
    
    // MARK: -
    // MARK: Device Select Box
    
    func comboBox(_ comboBox: NSComboBox, objectValueForItemAt index: Int) -> Any? {
        self.devices[index]
    }
    
    func numberOfItems(in comboBox: NSComboBox) -> Int {
        self.devices.count
    }
    
    func comboBoxSelectionDidChange(_ notification: Notification) {
        self.flashButton.isEnabled = self.ready && !self.busy
    }
    
    // MARK: -
    // MARK: Patch path
    
    func textDidChange(_ notification: Notification) {
        self.flashButton.isEnabled = self.ready && !self.busy
    }
    
    // MARK: -
    // MARK: Buttons

    @IBAction func selectPatchButtonClicked(_ sender: NSButton) {
        let dialog = NSOpenPanel()
        dialog.title = "Choose patch file"
        dialog.canChooseDirectories = false
        dialog.canChooseFiles = true
        dialog.canCreateDirectories = false
        dialog.allowsMultipleSelection = false
        dialog.allowedFileTypes = ["plist"]
        if dialog.runModal() == .OK {
            if let result = dialog.url {
                self.patchTextField.stringValue = result.path
            }
        }
    }
    
    @IBAction func flashButtonClicked(_ sender: Any) {
        let device = self.tbpManager.devices[devices[deviceComboBox.indexOfSelectedItem]]
        let patchPath = self.patchTextField.stringValue
        let reverse = self.uninstallCheckbox.state == .on
        flashEeprom(device: device!, patchPath: patchPath, reverse: reverse)
    }
    
    @IBAction func newDocument(_ sender: Any) {
        let dialog = NSSavePanel()
        dialog.title = "Choose output"
        dialog.isExtensionHidden = false
        guard dialog.runModal() == .OK else {
            return
        }
        guard let path = dialog.url else {
            return
        }
        guard let device = self.tbpManager.devices[devices[deviceComboBox.indexOfSelectedItem]] else {
            return
        }
        dumpEeprom(device: device, dumpPath: path, at: 0x0, size: eepromSize)
    }
    
    // MARK: -
    // MARK: Find devices and patching
    
    func asyncJob(_ job : @escaping () -> Void) {
        if busy {
            DispatchQueue.main.async {
                self.showAlert(message: "Already running an operation.", alertStyle: .critical)
            }
            return
        }
        busy = true
        DispatchQueue.global(qos: .userInitiated).async {
            job()
            self.busy = false
        }
    }
    
    func refreshDevices() {
        asyncJob {
            self.tbpManager.discoverDevices()
            self.devices = [String] (self.tbpManager.devices.keys)
            DispatchQueue.main.sync { self.deviceComboBox.reloadData() }
            if let foundDev = self.tbpManager.findDevice(withPath: self.filterDevice, uuid: nil) {
                for (index, key) in self.devices.enumerated() {
                    if self.tbpManager.devices[key] == foundDev {
                        DispatchQueue.main.sync { self.deviceComboBox.selectItem(at: index) }
                    }
                }
            }
            
            if self.devices.count == 0 {
                DispatchQueue.main.async {
                    self.showAlert(message: "No devices found. Make sure you have the right ACPI tables "
                    + "installed and that you are running this application as root.", alertStyle: .warning)
                }
            }
        }
    }
    
    func dumpEeprom(device: TPS6598XDevice, dumpPath: URL, at: UInt32, size: UInt32) {
        asyncJob {
            guard let data = self.tbpManager.eepromDump(device, at: at, size: size) else {
                DispatchQueue.main.async {
                    self.showAlert(message: "Error dumping", alertStyle: .critical)
                }
                return
            }
            do {
                try data.write(to: dumpPath)
                DispatchQueue.main.async {
                    self.showAlert(message: "Dump complete.", alertStyle: .informational)
                }
            } catch {
                DispatchQueue.main.async {
                    self.showAlert(message: "Error writing to file.", alertStyle: .critical)
                }
            }
        }
    }
    
    func flashEeprom(device: TPS6598XDevice, patchPath: String, reverse: Bool) {
        asyncJob {
            guard let patch = NSDictionary(contentsOfFile: patchPath) else {
                DispatchQueue.main.async {
                    self.showAlert(message: "Failed to load patch", alertStyle: .critical)
                }
                return
            }
            if let welcome = patch.value(forKeyPath: "Messages.Welcome") as! String? {
                let res = DispatchQueue.main.sync {
                    self.showAlert(message: welcome, alertStyle: .informational, showCancel: true)
                }
                if !res {
                    print("canceled")
                    return
                }
            }
            guard let rawPatches = patch["Patches"] as? [Any] else {
                DispatchQueue.main.async {
                    self.showAlert(message: "Failed to read patches", alertStyle: .critical)
                }
                return
            }
            guard let patchSets = self.tbpManager.generatePatchSets(rawPatches) else {
                DispatchQueue.main.async {
                    self.showAlert(message: "Failed to parse patchlist", alertStyle: .critical)
                }
                return
            }
            if self.tbpManager.eepromPatch(device, patches: patchSets, reverse: reverse) == kIOReturnSuccess {
                if let complete = patch.value(forKeyPath: "Messages.Complete") as! String? {
                    DispatchQueue.main.async {
                        self.showAlert(message: complete, alertStyle: .informational)
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.showAlert(message: "Patch failed", alertStyle: .critical)
                }
            }
        }
    }
}

