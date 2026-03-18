import UIKit

// MARK: - Highlight

extension BarcodeScannerViewController {
    func setupHighlightView() {
        let highlight = UIView()
        highlight.layer.cornerRadius = 8
        highlight.alpha = 0
        highlight.isUserInteractionEnabled = false
        view.addSubview(highlight)
        highlightView = highlight
    }

    func showHighlight(at rect: CGRect) {
        guard let highlight = highlightView else { return }
        let color: UIColor = continuousMode ? .systemGreen : .systemYellow
        highlight.layer.borderColor = color.cgColor
        highlight.layer.borderWidth = 3
        highlight.backgroundColor = color.withAlphaComponent(0.15)

        let padded = rect.insetBy(dx: -8, dy: -8)
        highlight.frame = padded
        highlight.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        highlight.alpha = 0

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            highlight.alpha = 1
            highlight.transform = .identity
        }

        if continuousMode {
            UIView.animate(withDuration: 0.2, delay: 0.4, options: .curveEaseIn) {
                highlight.alpha = 0
            }
        }
    }

    func showPooledHighlight(at rect: CGRect) {
        let highlight = highlightPool.first(where: { $0.alpha == 0 }) ?? makeHighlightView()
        let color: UIColor = .systemGreen
        highlight.layer.borderColor = color.cgColor
        highlight.layer.borderWidth = 3
        highlight.backgroundColor = color.withAlphaComponent(0.15)

        let padded = rect.insetBy(dx: -8, dy: -8)
        highlight.frame = padded
        highlight.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        highlight.alpha = 0

        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            highlight.alpha = 1
            highlight.transform = .identity
        }
        UIView.animate(withDuration: 0.2, delay: 0.4, options: .curveEaseIn) {
            highlight.alpha = 0
        }
    }

    private func makeHighlightView() -> UIView {
        let highlight = UIView()
        highlight.layer.cornerRadius = 8
        highlight.alpha = 0
        highlight.isUserInteractionEnabled = false
        view.addSubview(highlight)
        highlightPool.append(highlight)
        return highlight
    }

    func hideHighlight(animated: Bool = true) {
        let allViews = [highlightView].compactMap(\.self) + highlightPool
        for highlight in allViews where highlight.alpha > 0 {
            if animated {
                UIView.animate(withDuration: 0.2) { highlight.alpha = 0 }
            } else {
                highlight.layer.removeAllAnimations()
                highlight.alpha = 0
            }
        }
    }
}
