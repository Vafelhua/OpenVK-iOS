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
        let view = RemoteImageView(cornerRadius: rounded ? size / 2 : 0)
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

    static func alert(title: String, message: String) -> UIAlertController {
        let controller = UIAlertController(title: title, message: message, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "ОК", style: .default, handler: nil))
        return controller
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
}