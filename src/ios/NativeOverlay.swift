import UIKit

@objc(NativeOverlay)
class NativeOverlay: CDVPlugin {

    private static let overlayTag = 78432
    private static let feedbackTag = 78433
    private static let screenshotFileName = "nativeoverlay_screenshot.jpg"
    private var feedbackShown = false

    override func pluginInitialize() {
        super.pluginInitialize()
        DispatchQueue.main.async { [weak self] in
            // Set WKWebView native UIView background to match app theme.
            // Default is .white, which causes a white flash if splash hides
            // before the web content process has rendered the CSS background.
            self?.webView?.backgroundColor = UIColor.black
            self?.webView?.isOpaque = false
        }
    }

    private var screenshotPath: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(NativeOverlay.screenshotFileName)
    }

    private func getWindow() -> UIWindow? {
        return self.viewController.view.window
    }

    @objc(show:)
    func show(command: CDVInvokedUrlCommand) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let window = self.getWindow() else {
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

            window.addSubview(overlay)

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
                  let window = self.getWindow() else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "No window available")
                self?.commandDelegate.send(result, callbackId: command.callbackId)
                return
            }

            if window.viewWithTag(NativeOverlay.overlayTag) != nil {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "Overlay is visible, skipping capture")
                self.commandDelegate.send(result, callbackId: command.callbackId)
                return
            }

            let captureView = self.webView!
            let renderer = UIGraphicsImageRenderer(bounds: captureView.bounds)
            let screenshot = renderer.image { _ in
                captureView.drawHierarchy(in: captureView.bounds, afterScreenUpdates: true)
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
            guard let self = self,
                  let window = self.getWindow() else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "No window available")
                self?.commandDelegate.send(result, callbackId: command.callbackId)
                return
            }

            let path = self.screenshotPath.path
            guard FileManager.default.fileExists(atPath: path),
                  let rawImage = UIImage(contentsOfFile: path) else {
                let result = CDVPluginResult(status: CDVCommandStatus_ERROR, messageAs: "No saved screenshot")
                self.commandDelegate.send(result, callbackId: command.callbackId)
                return
            }

            let image = self.forceDecompress(rawImage)

            self.removeOverlay()
            self.feedbackShown = false

            let overlay = UIImageView(frame: window.bounds)
            overlay.image = image
            overlay.contentMode = .scaleAspectFill
            overlay.tag = NativeOverlay.overlayTag
            overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            overlay.isUserInteractionEnabled = true

            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.onOverlayTapped))
            overlay.addGestureRecognizer(tapGesture)

            window.addSubview(overlay)

            let result = CDVPluginResult(status: CDVCommandStatus_OK)
            self.commandDelegate.send(result, callbackId: command.callbackId)
        }
    }

    @objc private func onOverlayTapped() {
        guard !feedbackShown else { return }
        feedbackShown = true

        guard let window = getWindow(),
              let overlay = window.viewWithTag(NativeOverlay.overlayTag) else { return }

        let feedback = UIView(frame: overlay.bounds)
        feedback.tag = NativeOverlay.feedbackTag
        feedback.backgroundColor = UIColor.black.withAlphaComponent(0.0)
        feedback.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
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

    private func forceDecompress(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return image }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let decoded = context.makeImage() else { return image }
        return UIImage(cgImage: decoded, scale: image.scale, orientation: image.imageOrientation)
    }

    private func removeOverlay() {
        guard let window = getWindow() else { return }
        window.viewWithTag(NativeOverlay.feedbackTag)?.removeFromSuperview()
        window.viewWithTag(NativeOverlay.overlayTag)?.removeFromSuperview()
        feedbackShown = false
    }
}
