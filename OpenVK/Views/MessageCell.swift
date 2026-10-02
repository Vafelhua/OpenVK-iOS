import UIKit

/// Пузырь сообщения в чате.
final class MessageCell: UITableViewCell {
    static let reuseId = "MessageCell"

    private let bubble = UIView()
    private let bubbleLabel = UIFactory.label("", size: 15)
    private let timeLabel = UIFactory.label("", size: 11, color: Theme.textSecondary)
    private let photoView = RemoteImageView()

    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    private var photoHeight: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.backgroundColor = .clear

        bubble.translatesAutoresizingMaskIntoConstraints = false
        bubble.layer.cornerRadius = 14
        bubble.layer.masksToBounds = true
        photoView.translatesAutoresizingMaskIntoConstraints = false
        photoView.contentMode = .scaleAspectFill
        photoView.layer.cornerRadius = 10
        photoView.layer.masksToBounds = true
        timeLabel.textAlignment = .right

        let textStack = UIStackView(arrangedSubviews: [bubbleLabel])
        textStack.axis = .vertical
        textStack.spacing = 4
        textStack.translatesAutoresizingMaskIntoConstraints = false

        bubble.addSubview(textStack)
        bubble.addSubview(photoView)
        bubble.addSubview(timeLabel)
        contentView.addSubview(bubble)

        leadingConstraint = bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10)
        trailingConstraint = bubble.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10)
        photoHeight = photoView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 3),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -3),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.78),

            textStack.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 7),
            textStack.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 12),
            textStack.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),

            photoView.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 6),
            photoView.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 4),
            photoView.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -4),
            photoHeight,

            timeLabel.topAnchor.constraint(equalTo: photoView.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: bubble.leadingAnchor, constant: 12),
            timeLabel.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -12),
            timeLabel.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -5)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoView.clear()
        bubbleLabel.text = nil
    }

    func configure(message: VKMessage) {
        bubbleLabel.text = message.text
        bubbleLabel.isHidden = message.text.isEmpty
        timeLabel.text = TimeHelper.clock(message.date)

        if let photo = message.photo {
            photoView.isHidden = false
            photoView.setRemote(photo.bigURL, placeholder: Theme.divider)
            photoHeight.constant = 180
        } else {
            photoView.isHidden = true
            photoView.clear()
            photoHeight.constant = 0
        }

        leadingConstraint.isActive = message.isOutgoing == false
        trailingConstraint.isActive = message.isOutgoing

        if message.isOutgoing {
            bubble.backgroundColor = Theme.outgoing
            bubbleLabel.textColor = .white
            timeLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        } else {
            bubble.backgroundColor = Theme.incoming
            bubbleLabel.textColor = Theme.incomingText
            timeLabel.textColor = Theme.textSecondary
        }
    }
}

/// Разделитель дней в чате («Сегодня», «Вчера», «5 января 2020»).
final class DateSeparatorCell: UITableViewCell {
    static let reuseId = "DateSeparatorCell"

    private let pill = UIView()
    private let label = UIFactory.label("", size: 12, weight: .medium, color: Theme.textSecondary)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        contentView.backgroundColor = .clear

        pill.layer.cornerRadius = 11
        pill.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        pill.addSubview(label)
        contentView.addSubview(pill)

        NSLayoutConstraint.activate([
            pill.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            pill.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            pill.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            label.topAnchor.constraint(equalTo: pill.topAnchor, constant: 3),
            label.bottomAnchor.constraint(equalTo: pill.bottomAnchor, constant: -3),
            label.leadingAnchor.constraint(equalTo: pill.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(equalTo: pill.trailingAnchor, constant: -12)
        ])

        applyTheme()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(_ text: String) {
        label.text = text
    }

    func applyTheme() {
        pill.backgroundColor = Theme.divider
        label.textColor = Theme.textSecondary
    }
}