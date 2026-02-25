import XCTest
import AudioToolbox

final class HostHarnessTests: XCTestCase {
    private func fourCC(_ s: String) -> OSType {
        s.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }

    func testFourCCEncoding() {
        XCTAssertEqual(fourCC("chrd"), 0x63687264)
        XCTAssertEqual(fourCC("NWF1"), 0x4E574631)
    }

    func testComponentDescriptionShape() {
        let desc = AudioComponentDescription(
            componentType: kAudioUnitType_MIDIProcessor,
            componentSubType: fourCC("chrd"),
            componentManufacturer: fourCC("NWF1"),
            componentFlags: 0,
            componentFlagsMask: 0
        )

        XCTAssertEqual(desc.componentType, 0x61756D69)
        XCTAssertEqual(desc.componentSubType, 0x63687264)
        XCTAssertEqual(desc.componentManufacturer, 0x4E574631)
    }
}
