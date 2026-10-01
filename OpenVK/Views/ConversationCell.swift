import UIKit

/// Строка списка диалогов: аватар, заголовок, последнее сообщение, время, непрочитанные.
final class ConversationCell: UITableViewCell {
    static let reuseId = "ConversationCell"

    let avatarView = UIFactory.avatar(48)
    let photoView = UIFactory.avatar(40)
    private let titleLabel = UIFactory.label("", size: 16, weight: .semibold)
    private let messageLabel = UIFactory.label("", size: 14, color: Theme.textSecondary, lines: 1)
    private let timeLabel = UIFactory.label("", size: 12, color: Theme.textSecondary)
    private let badgeLabel = UIFactory.label("", size: 11, weight: .bold, color: .white)
    private let separator = UIView()
    private var photoWidth: NSLayoutConstraint?

    var unreadCount: Int = 0

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default

        badgeLabel.textAlignment = .center
        badgeLabel.backgroundColor = Theme.accent
        badgeLabel.layer.cornerRadius = 9
        badgeLabel.clipsToBounds = true

        separator.backgroundColor = Theme.divider
        separator.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, messageLabel])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(avatarView)
        contentView.addSubview(textStack)
        contentView.addSubview(timeLabel)
        contentView.addSubview(photoView)
        contentView.addSubview(badgeLabel)
        contentView.addSubview(separator)

        photoWidth = photoView.widthAnchor.constraint(equalToConstant: 40)

        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        messageLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),

            badgeLabel.trailingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: -2),
            badgeLabel.bottomAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 2),
            badgeLabel.heightAnchor.constraint(equalToConstant: 18),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 18),

            textStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 13),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: photoView.leadingAnchor, constant: -8),
            textStack.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -13),

            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),

            photoView.leadingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16 - 40),
            photoView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            photoWidth!,
            photoView.heightAnchor.constraint(equalToConstant: 40),

            separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 72),
            separator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.clear()
        photoView.clear()
        setPhoto(nil)
        timeText = nil
        unreadCount = 0
    }

    func setPhoto(_ url: String?) {
        let hasPhoto = (url?.isEmpty == false)
        photoWidth?.constant = hasPhoto ? 40 : 0
        photoView.isHidden = !hasPhoto
        if hasPhoto {
            photoView.setRemote(url, placeholder: Theme.divider)
        } else {
            photoView.clear()
        }
    }

    var titleText: String? {
        get { return titleLabel.text }
        set { titleLabel.text = newValue }
    }

    var messageText: String? {
        get { return messageLabel.text }
        set { messageLabel.text = newValue }
    }

    var timeText: String? {
        get { return timeLabel.text }
        set {
            timeLabel.text = newValue
            timeLabel.isHidden = (newValue?.isEmpty ?? true)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if unreadCount > 0 {
            let text = unreadCount > 99 ? "99+" : String(unreadCount)
            badgeLabel.text = " \(text) "
        }
        badgeLabel.isHidden = unreadCount <= 0
    }

    func applyTheme() {
        backgroundColor = Theme.card
        contentView.backgroundColor = Theme.card
        titleLabel.textColor = Theme.textPrimary
        messageLabel.textColor = Theme.textSecondary
        timeLabel.textColor = Theme.textSecondary
        separator.backgroundColor = Theme.divider
        badgeLabel.backgroundColor = Theme.accent
    }
}