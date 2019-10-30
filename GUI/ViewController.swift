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

class ViewController: NSViewController, NSComboBoxDataSource, NSComboBoxDelegate, NSTextDelegate {
    @IBOutlet weak var patchTextField: NSTextField!
    @IBOutlet weak var deviceComboBox: NSComboBox!
    @IBOutlet weak var uninstallCheckbox: NSButton!
    @IBOutlet weak var busySpinner: NSProgressIndicator!
    @IBOutlet weak var logTextView: NSTextView!
    @IBOutlet weak var flashButton: NSButton!
    
    var busy: Bool = false {
        willSet {
            if newValue {
                self.flashButton.isEnabled = false
                busySpinner.startAnimation(nil)
            } else {
                self.flashButton.isEnabled = self.ready
                busySpinner.stopAnimation(nil)
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
            let smartScroll = self.logTextView.visibleRect.maxY == self.logTextView.bounds.maxY
            self.logTextView.textStorage?.append(NSAttributedString(string: line + "\n", attributes: [NSAttributedString.Key.foregroundColor : NSColor.controlTextColor]))
            if smartScroll {
                self.logTextView.scrollToEndOfDocument(self)
            }
        }
        refreshDevices()
    }
    
    func showAlert(message msg: String, alertStyle style: NSAlert.Style) {
        let alert = NSAlert()
        alert.messageText = msg
        alert.alertStyle = style
        alert.addButton(withTitle: "OK")
        alert.runModal()
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
    
    // MARK: -
    // MARK: Find devices and patching
    
    func refreshDevices() {
        busy = true
        DispatchQueue.main.async {
            self.tbpManager.discoverDevices()
            self.devices = [String] (self.tbpManager.devices.keys)
            self.deviceComboBox.reloadData()
            if let foundDev = self.tbpManager.findDevice(withPath: self.filterDevice, uuid: nil) {
                for (index, dev) in self.tbpManager.devices.values.enumerated() {
                    if dev == foundDev {
                        self.deviceComboBox.selectItem(at: index)
                    }
                }
            }
            self.busy = false
            
            if self.devices.count == 0 {
                self.showAlert(message: "No devices found. Make sure you have the right ACPI tables "
                    + "installed and that you are running this application as root.", alertStyle: .warning)
            }
        }
    }
    
    func flashEeprom(device: TPS6598XDevice, patchPath: String, reverse: Bool) {
        busy = true
        DispatchQueue.main.async {
            
        }
    }
}

