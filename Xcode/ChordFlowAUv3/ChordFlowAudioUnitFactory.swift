import AudioToolbox
import CoreAudioKit
import SwiftUI
import UIKit

// AUViewController subclass that serves as both the extension entry point (via storyboard)
// and the AUAudioUnitFactory. Hosts load this from MainInterface.storyboard, then call
// createAudioUnit(with:) to get the AU instance. The host displays this view controller
// as the AUv3's custom UI.
//
// Apple warns that viewDidLoad() and createAudioUnit(with:) can be called in either order,
// so we connect the SwiftUI view to the AU in whichever callback fires second.
public final class ChordFlowAUViewController: AUViewController, AUAudioUnitFactory {
    private var audioUnit: ChordFlowMIDIProcessorAudioUnit?
    private var hostingController: UIHostingController<AUv3View>?
    private var isUIConnected = false

    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        let au = try ChordFlowMIDIProcessorAudioUnit(componentDescription: componentDescription, options: [])
        audioUnit = au
        DispatchQueue.main.async { [weak self] in
            self?.connectUIIfReady()
        }
        return au
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        preferredContentSize = CGSize(width: 440, height: 700)
        view.backgroundColor = UIColor(red: 0x0E / 255, green: 0x0F / 255, blue: 0x1D / 255, alpha: 1)
        connectUIIfReady()
    }

    private func connectUIIfReady() {
        guard !isUIConnected, isViewLoaded, let au = audioUnit else { return }
        isUIConnected = true

        let vm = AUv3ViewModel(audioUnit: au)
        let hc = UIHostingController(rootView: AUv3View(vm: vm))
        addChild(hc)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        hc.view.backgroundColor = .clear
        view.addSubview(hc.view)
        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        hc.didMove(toParent: self)
        hostingController = hc
    }
}
