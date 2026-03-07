import UIKit

@objc(NativeOverlay)
class NativeOverlay: CDVPlugin {

    private static let overlayTag = 78432

    @objc(show:)
    func show(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let window = self.viewController.view.window else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "No window available")
                self?.commandDelegate.send(result, callbackId: command.callbackId)
                return
            }

            self.removeOverlay()

            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let screenshot = renderer.image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
            }

            let overlay = UIImageView(frame: window.bounds)
            overlay.image = screenshot
            overlay.contentMode = .scaleAspectFill
            overlay.tag = NativeOverlay.overlayTag
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            self.viewController.view.addSubview(overlay)

            let result = CDVPluginResult(status: CDVCommandStatus_OK)
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    @objc(hide:)
    func hide(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async { [weak self] in
            self?.removeOverlay()
            let result = CDVPluginResult(status: CDVCommandStatus_OK)
            self?.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    private func removeOverlay() {
        self.viewController.view.viewWithTag(NativeOverlay.overlayTag)?.removeFromSuperview()
    }
}
