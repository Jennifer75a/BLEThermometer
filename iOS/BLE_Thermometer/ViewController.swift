//
//  ViewController.swift
//  BLE_Thermometer
//
//  Created by Jennifer AUBINAIS on 19/12/2018.
//  Copyright © 2018 Jennifer AUBINAIS. All rights reserved.
//
// https://www.kevinhoyt.com/2016/05/20/the-12-steps-of-bluetooth-swift/
// http://make.analogfolk.com/getting-started-with-ios10-swift-and-bluetooth-4-0-for-wearables-hardware/
//

import UIKit
// 1 - Import
//-----------
//Unlike beacons, which use Core Location, if you are communicating to a BLE device,
// you will use CoreBluetooth.
import CoreBluetooth

// extract String inside deux Strings
//----------------------------------
extension String {
    func slice(from: String, to: String) -> String? {
        return (range(of: from)?.upperBound).flatMap { substringFrom in
            (range(of: to, range: substringFrom..<endIndex)?.lowerBound).map { substringTo in
                String(self[substringFrom..<substringTo])
            }
        }
    }
}

// 2 - Delegates
//--------------
// Eventually you are going to want to get callbacks from some functionality.
// There are two delegates to implement: CBCentralManagerDelegate, and CBPeripheralDelegate.
class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate  {
    
    @IBOutlet weak var txtValue: UILabel!
    @IBOutlet weak var txtStatus: UILabel!
    
    // 3 - Declare Manager and Peripheral
    //-----------------------------------
    // The CBCentralManager install will be what you use to find, connect, and manage BLE devices.
    // Once you are connected, and are working with a specific service, the peripheral will help you
    // iterate characteristics and interacting with them.
    var manager: CBCentralManager!
    var peripheral: CBPeripheral!
    
    // 4 - UUID and Service Name
    //--------------------------
    // You will need UUID for the BLE service, and a UUID for the specific characteristic.
    // In some cases, you will need additional UUIDs. They get used repeatedly throughout the code,
    // so having constants for them will keep the code cleaner, and easier to maintain. T
    // here are also many service/characteristic pairs called out in the specification.
    let MY_NAME = "JATEMP"
    let MY_SERVICE_UUID = CBUUID(string: "569A1101-B87F-490C-92CB-11BA5EA5167C")
    let MY_CHARACTERISTIC_UUID = CBUUID(string: "569A2000-B87F-490C-92CB-11BA5EA5167C")
    
    // 5 - Instantiate Manager
    //------------------------
    // One-liner to create an instance of CBCentralManager. It takes the delegate as an argument,
    // and options, which in most cases are not needed. This is also the jumping off point for
    // what effectively becomes a chain of the remaining seven waterfall steps.
    override func viewDidLoad() {
        super.viewDidLoad()
        manager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // 6 - Scan for Devices
    //---------------------
    // Once the CBCentralManager instance is finished creating, it will call centralManagerDidUpdateState
    // on the delegate class. From there, if Bluetooth is available (as in "turned on"),
    // you can start scanning for devices.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
            case .unknown:
                print("Bluetooth status : Unknown")
            case .resetting:
                print("Bluetooth status : Resetting")
            case .unsupported:
                print("Bluetooth status : Unsupported")
            case .unauthorized:
                print("Bluetooth status : Unauthorized")
            case .poweredOff:
                print("Bluetooth status : Powered off")
            case .poweredOn:
                print("Bluetooth status : Powered on")
                 txtStatus.text = "Powered on"
                central.scanForPeripherals(withServices: [MY_SERVICE_UUID], options: nil)
        }
    }
    
    // 7 - Connect to a Device
    //------------------------
    // When you find the device you are interested in interacting with,
    // you will want to connect to it. This is the only place where the device name shows up in the code,
    // but I still like to declare it as a constant with the UUIDs.
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        if peripheral.name?.contains(MY_NAME) == true {
            print("Found device OK : \(MY_NAME)")
             txtStatus.text = "Device found"
            self.manager.stopScan()
            self.peripheral = peripheral
            self.peripheral.delegate = self
            manager.connect(peripheral)
        }
        else {
            if peripheral.name != nil {
                print("Device : \(peripheral.name!)")
            }
        }
    }
    
    // 8 - Get Services
    //-----------------
    // Once you are connected to a device, you can get a list of services on that device.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected !")
        txtStatus.text = "Connected"
        peripheral.discoverServices([MY_SERVICE_UUID])
    }
    
    // 9 - Get Characteristics
    //------------------------
    // Once you get a list of the services offered by the device, you will want to get
    // a list of the characteristics. You can get crazy here, or limit listing of characteristics to just
    // a specific service. If you go crazy watch for threading issues.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if error != nil {
            //print("error: \(error)")
            return
        }
        for service in peripheral.services! {
            if service.description != "" {
                let peripheralService = service.description.slice(from:"<CBService: ",to:",")
                print("Found service : \(peripheralService!) - \(service.uuid)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    // 10 - Setup Notifications
    //-------------------------
    //There are different ways to approach getting data from the BLE device.
    // One approach would be to read changes incrementally. Another approach,
    //the approach I used in my application,
    // would be to have the BLE device notify you whenever a characteristic value has changed.
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        if error != nil {
            //print("error: \(error)")
            return
        }
        for characteristic in service.characteristics! {
            let characteristicName = characteristic.description.slice(from:"<CBCharacteristic: ",to:",")
            peripheral.readValue(for: characteristic)
            let thisCharacteristic = characteristic as CBCharacteristic
            if thisCharacteristic.uuid == MY_CHARACTERISTIC_UUID {
                print("Characteristic OK : \(characteristicName!) - \(characteristic.uuid)")
                 txtStatus.text = "Characteristic OK"
                self.peripheral.setNotifyValue(true,for: thisCharacteristic)
            }
            else {
                print("Found characteristic : \(characteristicName!) - \(characteristic.uuid)")
            }
        }
    }
    
    // 11 - Changes Are Coming
    //------------------------
    // Any characteristic changes you have setup to receive notifications for will call this delegate method.
    // You will want to be sure and filter them out to take the appropriate action for the specific change.
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?)
    {
        if error != nil {
            //print("Failed… error: \(error)")
            return
        }
        if characteristic.value != nil {
            let stringValue = String(data: characteristic.value!, encoding: String.Encoding.utf8)!
                        print("characteristic value: \(stringValue.replacingOccurrences(of: "\r\n", with: ""))")
            if characteristic.uuid == MY_CHARACTERISTIC_UUID {
                if stringValue.contains("PW") {
                    txtValue.text = stringValue
                }
            }
        }
    }
    
    // 12 - Disconnect and Try Again
    //------------------------------
    // This is an optional step, but hey, let us be good programmers and clean up after ourselves.
    // Also a good place to start scanning all over again.
    func centralManager(_ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?) {
        print("Restart Scan")
        txtStatus.text = "Restart Scan"
        central.scanForPeripherals(withServices: [MY_SERVICE_UUID], options: nil)
    }
    
}

