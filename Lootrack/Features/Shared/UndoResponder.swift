import SwiftUI
import UIKit

struct UndoResponderView: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> UndoResponderViewController {
        UndoResponderViewController()
    }

    func updateUIViewController(_ uiViewController: UndoResponderViewController,
                                context _: Context)
    {
        /*
         * Don't steal focus from TextFields, search,
         * sheets, etc.
         *
         * Only reclaim first-responder status when
         * nobody else currently owns it.
         */
        guard UIResponder.currentFirstResponder == nil else {
            return
        }

        if !uiViewController.isFirstResponder {
            uiViewController.becomeFirstResponder()
        }
    }
}

final class UndoResponderViewController: UIViewController {
    override var canBecomeFirstResponder: Bool {
        true
    }

    override var undoManager: UndoManager? {
        view.window?.undoManager
            ?? super.undoManager
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        becomeFirstResponder()
    }
}

extension UIResponder {
    private weak static var capturedFirstResponder:
        UIResponder?

    @objc
    private func captureFirstResponder(_: Any) {
        UIResponder.capturedFirstResponder = self
    }

    static var currentFirstResponder:
        UIResponder?
    {
        capturedFirstResponder = nil

        UIApplication.shared.sendAction(#selector(captureFirstResponder(_:)),
                                        to: nil,
                                        from: nil,
                                        for: nil)

        return capturedFirstResponder
    }
}
