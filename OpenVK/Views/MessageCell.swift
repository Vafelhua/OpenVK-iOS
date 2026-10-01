import UIKit

/// Пузырь сообщения в чате.
final class MessageCell: UITableViewCell {
    static let reuseId = "MessageCell"

    private let bubble = UIView()
    private let textLabel = UIFactory.label("", size: 15)
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
        photoView.translatesAutoresizingMaskIntoConstraints = false
        photoView.contentMode = .scaleAspectFill

        let textStack = UIStackView(arrangedSubviews: [textLabel])
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
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubble.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.82),

            textStack.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 7),
            textStack.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 10),
            textStack.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -10),

            photoView.topAnchor.constraint(equalTo: textStack.bottomAnchor, constant: 6),
            photoView.leadingAnchor.constraint(equalTo: bubble.leadingAnchor),
            photoView.trailingAnchor.constraint(equalTo: bubble.trailingAnchor),
            photoHeight,

            timeLabel.topAnchor.constraint(equalTo: photoView.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 10),
            timeLabel.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -6)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoView.clear()
        textLabel.text = nil
    }

    func configure(message: VKMessage) {
        textLabel.text = message.text
        textLabel.isHidden = message.text.isEmpty
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
            textLabel.textColor = .white
            timeLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        } else {
            bubble.backgroundColor = Theme.incoming
            textLabel.textColor = Theme.incomingText
            timeLabel.textColor = Theme.textSecondary
        }
    }
}