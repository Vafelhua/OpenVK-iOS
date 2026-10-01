import UIKit

/// Карточка записи: автор, текст, фото, лайк/комментарии/репост.
final class PostCell: UITableViewCell {
    static let reuseId = "PostCell"

    var onLike: (() -> Void)?
    var onComment: (() -> Void)?
    var onRepost: (() -> Void)?
    var onAuthor: (() -> Void)?

    private let card = UIView()
    private let avatarView = UIFactory.avatar(40)
    private let authorLabel = UIFactory.label("", size: 15, weight: .semibold)
    private let timeLabel = UIFactory.label("", size: 12, color: Theme.textSecondary)
    private let postLabel = UIFactory.label("", size: 15)
    private let photoView = RemoteImageView()
    private let separator = UIView()

    private let likeButton = UIButton(type: .system)
    private let commentButton = UIButton(type: .system)
    private let repostButton = UIButton(type: .system)
    private let likeCountLabel = UIFactory.label("", size: 13, color: Theme.textSecondary)
    private let commentCountLabel = UIFactory.label("", size: 13, color: Theme.textSecondary)
    private let repostCountLabel = UIFactory.label("", size: 13, color: Theme.textSecondary)

    private var photoHeight: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none

        card.translatesAutoresizingMaskIntoConstraints = false
        photoView.translatesAutoresizingMaskIntoConstraints = false
        photoView.contentMode = .scaleAspectFill
        separator.backgroundColor = Theme.divider
        separator.translatesAutoresizingMaskIntoConstraints = false

        configureActionButton(likeButton, glyph: "♡", label: "Нравится", action: #selector(likeTapped))
        configureActionButton(commentButton, glyph: "✎", label: "Комментарии", action: #selector(commentTapped))
        configureActionButton(repostButton, glyph: "↻", label: "Репост", action: #selector(repostTapped))

        let authorTap = UITapGestureRecognizer(target: self, action: #selector(authorTapped))
        avatarView.addGestureRecognizer(authorTap)
        avatarView.isUserInteractionEnabled = true
        authorLabel.addGestureRecognizer(authorTap)
        authorLabel.isUserInteractionEnabled = true

        let actionStack = UIStackView(arrangedSubviews: [likeButton, commentButton, repostButton])
        actionStack.axis = .horizontal
        actionStack.distribution = .fillEqually
        actionStack.translatesAutoresizingMaskIntoConstraints = false

        let counts = UIStackView(arrangedSubviews: [likeCountLabel, commentCountLabel, repostCountLabel])
        counts.axis = .horizontal
        counts.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [
            postLabel, photoView, actionStack, counts, separator
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(12, after: photoView)
        stack.setCustomSpacing(2, after: actionStack)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(card)
        card.addSubview(avatarView)
        card.addSubview(authorLabel)
        card.addSubview(timeLabel)
        card.addSubview(stack)

        photoHeight = photoView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            avatarView.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            avatarView.topAnchor.constraint(equalTo: card.topAnchor),

            authorLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            authorLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 2),
            authorLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            timeLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 4),

            stack.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8),

            photoHeight,
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
        postLabel.text = nil
        onLike = nil
        onComment = nil
        onRepost = nil
        onAuthor = nil
    }

    private func configureActionButton(_ button: UIButton, glyph: String, label: String, action: Selector) {
        button.setTitle(" \(glyph) \(label)", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        button.titleLabel?.lineBreakMode = .byTruncatingTail
        button.contentHorizontalAlignment = .left
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    func configure(post: VKPost, authorName: String, authorPhoto: String?, isLiked: Bool? = nil) {
        let liked = isLiked ?? post.isLiked

        authorLabel.text = authorName
        timeLabel.text = TimeHelper.relative(post.date)
        postLabel.text = post.text
        postLabel.isHidden = post.text.isEmpty
        avatarView.setRemote(authorPhoto)

        likeButton.setTitle(liked ? " ♥ Нравится" : " ♡ Нравится", for: .normal)
        likeCountLabel.text = post.likesCount > 0 ? String(post.likesCount) : ""
        commentCountLabel.text = post.commentsCount > 0 ? String(post.commentsCount) : ""
        repostCountLabel.text = post.repostsCount > 0 ? String(post.repostsCount) : ""

        if let photo = post.photo {
            photoView.isHidden = false
            photoView.setRemote(photo.bigURL, placeholder: Theme.divider)
            photoHeight.constant = 240
        } else {
            photoView.isHidden = true
            photoView.clear()
            photoHeight.constant = 0
        }

        applyTheme()
    }

    func applyTheme() {
        card.backgroundColor = Theme.card
        contentView.backgroundColor = Theme.background
        authorLabel.textColor = Theme.textPrimary
        postLabel.textColor = Theme.textPrimary
        timeLabel.textColor = Theme.textSecondary
        likeCountLabel.textColor = Theme.textSecondary
        commentCountLabel.textColor = Theme.textSecondary
        repostCountLabel.textColor = Theme.textSecondary
        likeButton.setTitleColor(Theme.accent, for: .normal)
        commentButton.setTitleColor(Theme.accent, for: .normal)
        repostButton.setTitleColor(Theme.accent, for: .normal)
        separator.backgroundColor = Theme.divider
    }

    // MARK: - Действия

    @objc private func likeTapped() { onLike?() }
    @objc private func commentTapped() { onComment?() }
    @objc private func repostTapped() { onRepost?() }
    @objc private func authorTapped() { onAuthor?() }
}