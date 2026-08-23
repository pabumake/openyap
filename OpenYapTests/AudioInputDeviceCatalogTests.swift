import CoreAudio
import XCTest
@testable import OpenYap

final class AudioInputDeviceCatalogTests: XCTestCase {
    func testAutomaticSelectionPrefersAirPods() {
        let builtIn = device(uid: "built-in", name: "MacBook Air Microphone", id: 1, transport: kAudioDeviceTransportTypeBuiltIn)
        let airPods = device(uid: "airpods", name: "AirPods Pro", id: 2, transport: kAudioDeviceTransportTypeBluetooth)

        let selected = AudioInputDeviceCatalog.automaticDevice(
            from: [builtIn, airPods],
            defaultDeviceID: builtIn.coreAudioID
        )

        XCTAssertEqual(selected, airPods)
    }

    func testAutomaticSelectionFallsBackToBuiltInMicrophone() {
        let external = device(uid: "usb", name: "USB Microphone", id: 1, transport: kAudioDeviceTransportTypeUSB)
        let builtIn = device(uid: "built-in", name: "MacBook Air Microphone", id: 2, transport: kAudioDeviceTransportTypeBuiltIn)

        let selected = AudioInputDeviceCatalog.automaticDevice(
            from: [external, builtIn],
            defaultDeviceID: external.coreAudioID
        )

        XCTAssertEqual(selected, builtIn)
    }

    func testAutomaticSelectionUsesAnotherInputWhenNoPreferredDeviceExists() {
        let external = device(uid: "usb", name: "USB Microphone", id: 1, transport: kAudioDeviceTransportTypeUSB)

        let selected = AudioInputDeviceCatalog.automaticDevice(
            from: [external],
            defaultDeviceID: external.coreAudioID
        )

        XCTAssertEqual(selected, external)
    }

    func testAutomaticSelectionReturnsNilWithoutInputs() {
        XCTAssertNil(AudioInputDeviceCatalog.automaticDevice(from: [], defaultDeviceID: nil))
    }

    private func device(
        uid: String,
        name: String,
        id: AudioDeviceID,
        transport: UInt32
    ) -> AudioInputDevice {
        AudioInputDevice(id: uid, name: name, coreAudioID: id, transportType: transport)
    }
}
