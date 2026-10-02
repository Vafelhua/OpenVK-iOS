import UIKit

/// Карточка записи: автор, текст, фото, лайк/комментарии/репост.
final class PostCell: UITableViewCell {
    static let reuseId = "PostCell"

    var onLike: (() -> Void)?
    var onComment: (() -> Void)?
    var onRepost: (() -> Void)?
    var onAuthor: (() -> Void)?

    private let card = UIView()
    private let avatarView = UIFactory.avatar(44)
    private let authorLabel = UIFactory.label("", size: 15, weight: .semibold)
    private let screenNameLabel = UIFactory.label("", size: 12, color: Theme.textSecondary)
    private let timeLabel = UIFactory.label("", size: 12, color: Theme.textSecondary)
    private let postLabel = UIFactory.label("", size: 15)
    private let photoView = RemoteImageView()

    private let likeButton = UIButton(type: .system)
    private let commentButton = UIButton(type: .system)
    private let repostButton = UIButton(type: .system)

    private var photoHeight: NSLayoutConstraint!
    /// Хранится отдельно, чтобы пересчитать высоту фото под реальную
    /// ширину карточки, а не под ширину экрана.
    private var photoAspectRatio: CGFloat = 0
    /// Состояние лайка нужно и в `applyTheme`, куда пост не передаётся.
    private var likedState = false

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .none
        // Фон ячейки — серая «подложка», сама карточка белая со скруглением.
        contentView.backgroundColor = Theme.background

        card.translatesAutoresizingMaskIntoConstraints = false
        card.layer.cornerRadius = Theme.cardRadius
        card.layer.masksToBounds = true

        photoView.translatesAutoresizingMaskIntoConstraints = false
        photoView.contentMode = .scaleAspectFill
        photoView.layer.cornerRadius = Theme.cardRadius
        photoView.layer.masksToBounds = true

        configureActionButton(likeButton, glyph: "♥", label: "", action: #selector(likeTapped))
        configureActionButton(commentButton, glyph: "✎", label: "", action: #selector(commentTapped))
        configureActionButton(repostButton, glyph: "↻", label: "", action: #selector(repostTapped))

        let authorTap = UITapGestureRecognizer(target: self, action: #selector(authorTapped))
        avatarView.addGestureRecognizer(authorTap)
        avatarView.isUserInteractionEnabled = true
        authorLabel.addGestureRecognizer(authorTap)
        authorLabel.isUserInteractionEnabled = true
        screenNameLabel.addGestureRecognizer(authorTap)
        screenNameLabel.isUserInteractionEnabled = true

        // Тап по фото открывает его во весь экран.
        photoView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(photoTapped)))
        photoView.isUserInteractionEnabled = true

        // Как в VK: иконка и счётчик рядом, третья колонка прижата вправо.
        let actionStack = UIStackView(arrangedSubviews: [likeButton, commentButton, repostButton])
        actionStack.axis = .horizontal
        actionStack.alignment = .center
        actionStack.spacing = 20
        actionStack.translatesAutoresizingMaskIntoConstraints = false

        let spacer = UIView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        let row = UIStackView(arrangedSubviews: [actionStack, spacer])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .fill
        row.translatesAutoresizingMaskIntoConstraints = false

        let stack = UIStackView(arrangedSubviews: [
            postLabel, photoView, row
        ])
        stack.axis = .vertical
        stack.spacing = 8
        stack.setCustomSpacing(12, after: photoView)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(card)
        card.addSubview(avatarView)
        card.addSubview(authorLabel)
        card.addSubview(screenNameLabel)
        card.addSubview(timeLabel)
        card.addSubview(stack)

        photoHeight = photoView.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 5),
            card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),

            avatarView.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            avatarView.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),

            authorLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            authorLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),
            authorLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

            screenNameLabel.leadingAnchor.constraint(equalTo: authorLabel.leadingAnchor),
            screenNameLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 1),
            screenNameLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),

            timeLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            timeLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 15),

            stack.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),

            row.heightAnchor.constraint(equalToConstant: 34),
            spacer.heightAnchor.constraint(equalToConstant: 1),

            photoHeight
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
        screenNameLabel.text = nil
        photoAspectRatio = 0
        photoHeight.constant = 0
        onLike = nil
        onComment = nil
        onRepost = nil
        onAuthor = nil
    }

    /// Высота фото считается от фактической ширины карточки: на iPad и при
    /// разделении экрана старая формула по ширине экрана давала перекос.
    override func layoutSubviews() {
        super.layoutSubviews()
        guard photoAspectRatio > 0 else { return }
        let available = photoView.bounds.width
        guard available > 0 else { return }
        let height = max(120, (available * photoAspectRatio).rounded())
        if abs(photoHeight.constant - height) > 0.5 {
            photoHeight.constant = height
        }
    }

    private func configureActionButton(_ button: UIButton, glyph: String, label: String, action: Selector) {
        button.setImage(UIFactory.icon(glyph, size: 19), for: .normal)
        button.accessibilityLabel = label.isEmpty ? glyph : label
        button.contentHorizontalAlignment = .left
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 6)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 13, weight: .medium)
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    /// Заголовок кнопки-действия: глиф + счётчик, как в клиенте VK.
    private func actionTitle(glyph: String, count: Int) -> String {
        guard count > 0 else { return "" }
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        }
        return String(count)
    }

    func configure(post: VKPost, authorName: String, authorScreenName: String? = nil, authorPhoto: String?, isLiked: Bool? = nil) {
        let liked = isLiked ?? post.isLiked
        likedState = liked

        authorLabel.text = authorName
        let screenName = authorScreenName?.trimmingCharacters(in: .whitespaces) ?? ""
        screenNameLabel.text = screenName.isEmpty ? nil : "@\(screenName)"
        screenNameLabel.isHidden = screenName.isEmpty
        timeLabel.text = TimeHelper.relative(post.date)
        postLabel.text = post.text
        postLabel.isHidden = post.text.isEmpty
        avatarView.setRemote(authorPhoto)

        likeButton.setTitle(actionTitle(glyph: "♥", count: post.likesCount), for: .normal)
        likeButton.setImage(UIFactory.icon(liked ? "♥" : "♡", size: 19), for: .normal)
        commentButton.setTitle(actionTitle(glyph: "✎", count: post.commentsCount), for: .normal)
        repostButton.setTitle(actionTitle(glyph: "↻", count: post.repostsCount), for: .normal)

        if let photo = post.photo {
            photoView.isHidden = false
            photoView.setRemote(photo.bigURL, placeholder: Theme.divider)
            photoAspectRatio = photo.aspectRatio
            photoHeight.constant = max(120, (photoView.bounds.width * photo.aspectRatio).rounded())
        } else {
            photoView.isHidden = true
            photoView.clear()
            photoAspectRatio = 0
            photoHeight.constant = 0
        }

        applyTheme()
    }

    func applyTheme() {
        card.backgroundColor = Theme.card
        contentView.backgroundColor = Theme.background
        authorLabel.textColor = Theme.textPrimary
        screenNameLabel.textColor = Theme.textSecondary
        postLabel.textColor = Theme.textPrimary
        timeLabel.textColor = Theme.textSecondary
        let actionTint = likedState ? Theme.error : Theme.textSecondary
        likeButton.setTitleColor(actionTint, for: .normal)
        likeButton.tintColor = actionTint
        commentButton.setTitleColor(Theme.accent, for: .normal)
        commentButton.tintColor = Theme.accent
        repostButton.setTitleColor(Theme.accent, for: .normal)
        repostButton.tintColor = Theme.accent
    }

    // MARK: - Действия

    @objc private func likeTapped() { onLike?() }
    @objc private func photoTapped() {
        guard let url = photoView.remoteURL, url.isEmpty == false else { return }
        PhotoViewer.present(url: url)
    }
    @objc private func commentTapped() { onComment?() }
    @objc private func repostTapped() { onRepost?() }
    @objc private func authorTapped() { onAuthor?() }
}