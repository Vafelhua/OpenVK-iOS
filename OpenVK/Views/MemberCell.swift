import UIKit

/// Строка списка: друг / сообщество / пользователь.
final class MemberCell: UITableViewCell {
    static let reuseId = "MemberCell"

    let avatarView = UIFactory.avatar(48)
    private let titleLabel = UIFactory.label("", size: 16, weight: .semibold)
    private let subtitleLabel = UIFactory.label("", size: 13, color: Theme.textSecondary)
    private let separator = UIView()
    private var separatorLeading: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = Theme.card
        contentView.backgroundColor = Theme.card
        selectionStyle = .default

        separator.backgroundColor = Theme.divider
        separator.translatesAutoresizingMaskIntoConstraints = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.spacing = 2
        textStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(avatarView)
        contentView.addSubview(textStack)
        contentView.addSubview(separator)

        // В стиле VK 6.56 разделитель во всю ширину, в современном — от текста.
        separatorLeading = separator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor,
                                                              constant: Theme.isVK56 ? 0 : 72)
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            textStack.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            textStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            textStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),

            separatorLeading,
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
        titleLabel.text = nil
        subtitleLabel.text = nil
    }

    func configure(title: String, subtitle: String?, photo: String?, badge: String? = nil) {
        titleLabel.text = title

        var parts: [String] = []
        if let subtitle = subtitle, subtitle.isEmpty == false { parts.append(subtitle) }
        if let badge = badge, badge.isEmpty == false { parts.append(badge) }
        subtitleLabel.text = parts.joined(separator: " · ")
        subtitleLabel.isHidden = parts.isEmpty

        avatarView.setRemote(photo)
        applyTheme()
    }

    func configure(user: VKUser, badge: String? = nil) {
        let nick = user.screenName.isEmpty ? nil : "@\(user.screenName)"
        configure(title: user.name, subtitle: user.subtitle, photo: user.photoMax, badge: badge ?? nick)
    }

    func configure(group: VKGroup) {
        configure(title: group.title,
                  subtitle: group.membersText.isEmpty ? group.screenName : group.membersText,
                  photo: group.photoMax)
    }

    func applyTheme() {
        backgroundColor = Theme.card
        contentView.backgroundColor = Theme.card
        titleLabel.textColor = Theme.textPrimary
        subtitleLabel.textColor = Theme.textSecondary
        avatarView.layer.borderColor = Theme.divider.cgColor
        separator.backgroundColor = Theme.divider
        separatorLeading.constant = Theme.isVK56 ? 0 : 72
    }

    /// Подсветить строку как играющий трек.
    func setPlaying(_ playing: Bool) {
        titleLabel.textColor = playing ? Theme.accent : Theme.textPrimary
    }
}