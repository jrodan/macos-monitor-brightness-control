import XCTest
import SwiftUI
@testable import BrightnessControlCore

final class BrightnessControlTests: XCTestCase {
    func testDisplayModel() {
        let display = Display(id: 1, name: "Test Display", isInternal: true)
        XCTAssertEqual(display.name, "Test Display")
        XCTAssertTrue(display.isInternal)
        XCTAssertEqual(display.brightness, 0.5)
    }
    
    @MainActor
    func testBrightnessManagerInitialization() {
        let manager = BrightnessManager()
        XCTAssertFalse(manager.syncAllDisplays)
    }

    func testSyncDisplays() async {
        let manager = await BrightnessManager()
        
        let display1 = Display(id: 1, name: "Display 1", isInternal: true)
        let display2 = Display(id: 2, name: "Display 2", isInternal: false)
        
        await MainActor.run {
            manager.displays = [display1, display2]
            manager.syncAllDisplays = true
            
            // Set brightness for display 1, should sync to display 2
            manager.setBrightness(for: display1, to: 0.7)
            
            XCTAssertEqual(manager.displays[0].brightness, 0.7)
            XCTAssertEqual(manager.displays[1].brightness, 0.7)
        }
    }

    @MainActor
    func testMenuBarManager() {
        let manager = MenuBarManager()
        manager.resetToDefault() // Ensure fresh state
        XCTAssertEqual(manager.spacing, 16)
        
        manager.spacing = 8
        XCTAssertEqual(manager.spacing, 8)
    }

    @MainActor
    func testBatteryManagerColors() {
        let manager = BatteryManager()
        
        // Test Charging / AC (Vibrant Green)
        manager.isOnAC = true
        manager.isLowPowerMode = false
        manager.percentage = 100
        XCTAssertEqual(manager.batteryColor, Color(red: 0.0, green: 0.85, blue: 0.1))
        
        // Test Low Power Mode (Vibrant Yellow)
        manager.isOnAC = false
        manager.isLowPowerMode = true
        XCTAssertEqual(manager.batteryColor, Color(red: 1.0, green: 0.8, blue: 0.0))
        
        // Test Low Battery (Vibrant Red)
        manager.isLowPowerMode = false
        manager.percentage = 10
        XCTAssertEqual(manager.batteryColor, Color(red: 1.0, green: 0.2, blue: 0.2))
        
        // Test Normal Battery (Primary/Default)
        manager.percentage = 50
        XCTAssertEqual(manager.batteryColor, .primary)
    }

    @MainActor
    func testDisplaySoftwareControl() {
        var display = Display(id: 1, name: "HDMI Display", isInternal: false)
        XCTAssertFalse(display.isSoftwareControl, "Should default to hardware control")
        
        display.isSoftwareControl = true
        XCTAssertTrue(display.isSoftwareControl)
    }

    @MainActor
    func testBrightnessSyncLogic() async {
        let manager = BrightnessManager()
        let d1 = Display(id: 1, name: "Int", isInternal: true)
        let d2 = Display(id: 2, name: "Ext", isInternal: false)
        manager.displays = [d1, d2]
        
        // Test sync off
        manager.syncAllDisplays = false
        manager.setBrightness(for: d1, to: 0.3)
        XCTAssertEqual(manager.displays[0].brightness, 0.3)
        XCTAssertEqual(manager.displays[1].brightness, 0.5) // Default
        
        // Test sync on
        manager.toggleSync()
        XCTAssertTrue(manager.syncAllDisplays)
        manager.setBrightness(for: d1, to: 0.8)
        XCTAssertEqual(manager.displays[0].brightness, 0.8)
        XCTAssertEqual(manager.displays[1].brightness, 0.8)
    }
}
