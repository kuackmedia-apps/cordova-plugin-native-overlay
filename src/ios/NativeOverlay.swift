import UIKit

@objc(NativeOverlay)
class NativeOverlay: CDVPlugin {

    private static let overlayTag = 78432
    private static let feedbackTag = 78433
    private static let screenshotFileName = "nativeoverlay_screenshot.jpg"
    private var feedbackShown = false

    private var screenshotPath: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(NativeOverlay.screenshotFileName)
    }

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

    @objc(save:)
    func save(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let window = self.viewController.view.window else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "No window available")
                self?.commandDelegate.send(result, callbackId: command.callbackId)
                return
            }

            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let screenshot = renderer.image { _ in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }

            self.commandDelegate.run(inBackground: {
                guard let data = screenshot.jpegData(compressionQuality: 0.7) else {
                    let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Failed to encode JPEG")
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                    return
                }
                do {
                    try data.write(to: self.screenshotPath, options: .atomic)
                    let result = CDVPluginResult(status: CDVCommandStatus_OK)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                } catch {
                    let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: error.localizedDescription)
                    self.commandDelegate.send(result, callbackId: command.callbackId)
                }
            })
        }
    }

    @objc(showSaved:)
    func showSaved(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Plugin deallocated")
                self?.commandDelegate.send(result, callbackId: command.callbackId)
                return
            }

            let path = self.screenshotPath.path
            guard FileManager.default.fileExists(atPath: path),
                  let image = UIImage(contentsOfFile: path) else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "No saved screenshot")
                self.commandDelegate.send(result, callbackId: command.callbackId)
                return
            }

            self.removeOverlay()
            self.feedbackShown = false

            let overlay = UIImageView(frame: self.viewController.view.bounds)
            overlay.image = image
            overlay.contentMode = .scaleAspectFill
            overlay.tag = NativeOverlay.overlayTag
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.isUserInteractionEnabled = true

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.onOverlayTapped))
            overlay.addGestureRecognizer(tapGesture)

            self.viewController.view.addSubview(overlay)

            let result = CDVPluginResult(status: CDVCommandStatus_OK)
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    @objc private func onOverlayTapped() {
        guard !feedbackShown else { return }
        feedbackShown = true

        guard let overlay = self.viewController.view.viewWithTag(NativeOverlay.overlayTag) else { return }

        let feedback = UIView(frame: overlay.bounds)
        feedback.tag = NativeOverlay.feedbackTag
        feedback.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        feedback.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let spinner = UIActivityIndicatorView(style: .whiteLarge)
        spinner.center = CGPoint(x: feedback.bounds.midX, y: feedback.bounds.midY)
        spinner.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        spinner.startAnimating()
        feedback.addSubview(spinner)

        overlay.addSubview(feedback)

        UIView.animate(withDuration: 0.3) {
            feedback.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        }
    }

    @objc(deleteSaved:)
    func deleteSaved(command: CDVInvokedUrlCommand) {
        commandDelegate.run(inBackground: { [weak self] in
            guard let self = self else { return }
            let path = self.screenshotPath.path
            if FileManager.default.fileExists(atPath: path) {
                try? FileManager.default.removeItem(atPath: path)
            }
            let result = CDVPluginResult(status: CDVCommandStatus_OK)
            self.commandDelegate.send(result, callbackId: command.callbackId)
        })
    }

    private func removeOverlay() {
        self.viewController.view.viewWithTag(NativeOverlay.overlayTag)?.removeFromSuperview()
        feedbackShown = false
    }
}