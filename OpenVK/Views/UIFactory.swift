import UIKit

/// Мелкие фабрики UI-элементов, чтобы не дублировать код в вёрстке.
enum UIFactory {
    static func label(_ text: String = "",
                      size: CGFloat = 15,
                      weight: UIFont.Weight = .regular,
                      color: UIColor = Theme.textPrimary,
                      lines: Int = 0) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = UIFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.numberOfLines = lines
        return label
    }

    static func avatar(_ size: CGFloat, rounded: Bool = true) -> RemoteImageView {
        // В клиенте 6.56 аватары квадратные, скругление минимальное.
        let view = RemoteImageView(cornerRadius: rounded ? Theme.avatarRadius(size) : 0)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: size),
            view.heightAnchor.constraint(equalToConstant: size)
        ])
        return view
    }

    /// Иконка из текстового глифа: на iOS 12 нет SF Symbols, а шаблонные картинки
    /// корректно перекрашиваются UITabBar/UINavigationBar.
    static func icon(_ glyph: String, size: CGFloat = 24) -> UIImage? {
        let text = glyph as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size)
        ]
        let bounds = text.size(withAttributes: attributes)
        guard bounds.width > 0, bounds.height > 0 else { return nil }

        UIGraphicsBeginImageContextWithOptions(CGSize(width: ceil(bounds.width), height: ceil(bounds.height)), false, 0)
        text.draw(at: .zero, withAttributes: attributes)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image?.withRenderingMode(.alwaysTemplate)
    }

    /// Иконки таб-бара. SF Symbols появились только в iOS 13, поэтому значки
    /// рисуются путями: на iOS 12 это единственный способ получить
    /// аккуратную векторную иконку вместо текстовых глифов.
    enum TabIcon: String {
        case news
        case messages
        case profile
        case settings
    }

    static func tabIcon(_ kind: TabIcon, size: CGFloat = 26) -> UIImage? {
        let side = max(size, 12)
        UIGraphicsBeginImageContextWithOptions(CGSize(width: side, height: side), false, 0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        context.setShouldAntialias(true)
        UIColor.black.setFill()
        UIColor.black.setStroke()

        let unit = side / 26.0
        func x(_ value: CGFloat) -> CGFloat { return value * unit }
        func y(_ value: CGFloat) -> CGFloat { return value * unit }
        func rect(_ a: CGFloat, _ b: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            return CGRect(x: x(a), y: y(b), width: x(w), height: y(h))
        }

        switch kind {
        case .news:
            // Домик — как вкладка «Лента» в клиенте VK/OpenVK.
            let roof = UIBezierPath()
            roof.move(to: CGPoint(x: x(2), y: y(12.5)))
            roof.addLine(to: CGPoint(x: x(13), y: y(3)))
            roof.addLine(to: CGPoint(x: x(24), y: y(12.5)))
            roof.close()
            roof.fill()
            UIBezierPath(roundedRect: rect(5, 11, 16, 12), cornerRadius: x(1.5)).fill()
        case .messages:
            let bubble = UIBezierPath(roundedRect: rect(3, 5, 20, 14), cornerRadius: x(4))
            bubble.fill()
            // Хвостик у пузыря.
            let tail = UIBezierPath()
            tail.move(to: CGPoint(x: x(8), y: y(19)))
            tail.addLine(to: CGPoint(x: x(8), y: y(23)))
            tail.addLine(to: CGPoint(x: x(14), y: y(19)))
            tail.close()
            tail.fill()
        case .profile:
            let head = UIBezierPath(ovalIn: rect(8.5, 3, 9, 9))
            head.fill()
            let shoulders = UIBezierPath()
            shoulders.move(to: CGPoint(x: x(3.5), y: y(23)))
            shoulders.addCurve(to: CGPoint(x: x(22.5), y: y(23)),
                               controlPoint1: CGPoint(x: x(3.5), y: y(14.5)),
                               controlPoint2: CGPoint(x: x(22.5), y: y(14.5)))
            shoulders.addCurve(to: CGPoint(x: x(3.5), y: y(23)),
                               controlPoint1: CGPoint(x: x(22.5), y: y(26)),
                               controlPoint2: CGPoint(x: x(3.5), y: y(26)))
            shoulders.close()
            shoulders.fill()
        case .settings:
            // Сетка 2×2 — вкладка «Прочее» в клиенте VK/OpenVK.
            let radius = x(1.5)
            UIBezierPath(roundedRect: rect(3, 3, 9, 9), cornerRadius: radius).fill()
            UIBezierPath(roundedRect: rect(14, 3, 9, 9), cornerRadius: radius).fill()
            UIBezierPath(roundedRect: rect(3, 14, 9, 9), cornerRadius: radius).fill()
            UIBezierPath(roundedRect: rect(14, 14, 9, 9), cornerRadius: radius).fill()
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image?.withRenderingMode(.alwaysTemplate)
    }

    static func alert(title: String, message: String) -> UIAlertController {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "ОК", style: .default, handler: nil))
        return controller
    }

    /// Поле поиска в стиле 6.56: белая плашка с тонкой рамкой на сером фоне,
    /// без скругления и тени. Системный `UISearchBar` на iOS 12 округляет поле,
    /// поэтому текстовое поле перекрашивается вручную.
    static func searchBar(placeholder: String) -> UISearchBar {
        let bar = UISearchBar()
        bar.placeholder = placeholder
        bar.searchBarStyle = .minimal
        bar.barTintColor = Theme.card
        bar.backgroundColor = Theme.background
        bar.isTranslucent = false
        bar.tintColor = Theme.accent
        bar.sizeToFit()

        let field: UITextField?
        if #available(iOS 13.0, *) {
            field = bar.searchTextField
        } else {
            field = bar.subviews.first?.subviews.first(where: { $0 is UITextField }) as? UITextField
        }
        field?.backgroundColor = Theme.card
        field?.layer.cornerRadius = 0
        field?.layer.borderWidth = 1
        field?.layer.borderColor = Theme.border.cgColor
        field?.leftView?.tintColor = Theme.textSecondary
        return bar
    }

    static func textField(placeholder: String, secure: Bool = false) -> UITextField {
        let field = UITextField()
        field.placeholder = placeholder
        field.isSecureTextEntry = secure
        field.font = UIFont.systemFont(ofSize: 17)
        field.textColor = Theme.textPrimary
        field.backgroundColor = Theme.card
        field.borderStyle = .none
        field.layer.cornerRadius = 0
        field.layer.borderWidth = 1
        field.layer.borderColor = Theme.divider.cgColor
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        field.leftViewMode = .always
        field.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 44))
        field.rightViewMode = .always
        field.translatesAutoresizingMaskIntoConstraints = false
        return field
    }

    static func flatButton(_ title: String, color: UIColor = Theme.accent) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(color, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        button.contentHorizontalAlignment = .left
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    /// Кнопка-действие с синим фоном — как кнопки «Отправить»/«Подписаться»
    /// в клиенте VK 6.56: сплошная заливка, тонкий тёмный контур, скругление 2pt.
    static func primaryButton(_ title: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.setTitle(title, for: .normal)
        button.setTitleColor(Theme.buttonText, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.backgroundColor = Theme.button
        button.layer.cornerRadius = Theme.cardRadius
        button.layer.borderWidth = Theme.cardBorderWidth
        button.layer.borderColor = Theme.border.cgColor
        button.contentEdgeInsets = UIEdgeInsets(top: 7, left: 14, bottom: 7, right: 14)
        return button
    }

    /// Полосы в клиенте 6.56 разделены фоном страницы, а не обводкой, поэтому
    /// рамка не рисуется.
    static func applyCardBorder(to view: UIView) {
        view.layer.borderWidth = Theme.cardBorderWidth
        if Theme.cardBorderWidth > 0 {
            view.layer.borderColor = Theme.border.cgColor
        }
    }
}