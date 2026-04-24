import SwiftUI
import VisionKit
import CodeLightProtocol

/// Camera-based QR code scanner using DataScannerViewController.
struct QRScannerView: UIViewControllerRepresentable {
    let onCodeScanned: (String) -> Void
    var onScannerError: ((String) -> Void)? = nil

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            do {
                try uiViewController.startScanning()
            } catch {
                DispatchQueue.main.async {
                    context.coordinator.onScannerError?(error.localizedDescription)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned, onScannerError: onScannerError)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCodeScanned: (String) -> Void
        let onScannerError: ((String) -> Void)?
        private var hasScanned = false

        init(onCodeScanned: @escaping (String) -> Void, onScannerError: ((String) -> Void)?) {
            self.onCodeScanned = onCodeScanned
            self.onScannerError = onScannerError
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasScanned else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item,
                   let value = barcode.payloadStringValue {
                    hasScanned = true
                    dataScanner.stopScanning()
                    onCodeScanned(value)
                    break
                }
            }
        }
    }
}
