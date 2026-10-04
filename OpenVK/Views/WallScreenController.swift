import UIKit

/// Общий экран «шапка профиля + стена»: используется страницами пользователя,
/// сообщества и собственного профиля.
class WallScreenController: TableScreenController {
    /// Тег вторичных подписей в шапке (имя, статус).
    static let secondaryLabelTag = 7_301

    let headerView = UIView()
    let headerStack = UIStackView()

    /// Верх стека шапки: перепривязывается, если сверху добавляется обложка.
    private var headerStackTop: NSLayoutConstraint!

    /// Обложка уже добавлена (повторный вызов не должен дублировать вьюху).
    private var hasCover = false

    private(set) var posts: [VKPost] = []
    private var users: [Int: VKUser] = [:]
    private var groups: [Int: VKGroup] = [:]
    private var actionButtonGroups: [[UIButton]] = []

    /// Сколько записей уже загружено — используется как `offset` для следующей страницы.
    private var wallOffset = 0

    /// Владелец стены (сообщество передаёт отрицательный id).
    var wallOwnerId: Int { return 0 }
    var wallCount: String { return "20" }

    override var itemsCount: Int { return posts.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        paginationEnabled = true

        headerView.translatesAutoresizingMaskIntoConstraints = false
        headerView.backgroundColor = Theme.card

        headerStack.axis = .vertical
        headerStack.spacing = 8
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.alignment = .fill
        headerView.addSubview(headerStack)

        let separator = UIView()
        separator.backgroundColor = Theme.divider
        separator.translatesAutoresizingMaskIntoConstraints = false
        headerView.addSubview(separator)

        view.addSubview(headerView)

        let safe = view.safeAreaLayoutGuide
        headerStackTop = headerStack.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 14)
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: safe.topAnchor),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            headerStackTop,
            headerStack.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 16),
            headerStack.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -16),
            headerStack.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -14),

            separator.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: headerView.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])

        pinTableTop(to: headerView.bottomAnchor)

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(refreshTapped))

        buildHeader()
        load()
    }

    // MARK: - Шапка (переопределяется)

    func buildHeader() {}

    struct HeaderParts {
        let avatar: RemoteImageView
        let title: UILabel
        let subtitle: UILabel
        let counters: UILabel
    }

    /// Строка «аватар + имя + подпись + счётчики». Если передан `coverURL`,
    /// сверху добавляется обложка в пропорции 4:3.
    func addHeaderParts(avatarSize: CGFloat = 56, coverURL: String? = nil) -> HeaderParts {
        if let coverURL = coverURL, coverURL.isEmpty == false {
            addCover(coverURL)
        }

        let avatar = UIFactory.avatar(avatarSize, rounded: false)
        let title = UIFactory.label("", size: 18, weight: .bold)
        title.numberOfLines = 2
        let subtitle = UIFactory.label("", size: 13, color: Theme.textSecondary, lines: 2)
        subtitle.tag = WallScreenController.secondaryLabelTag
        let counters = UIFactory.label("", size: 13, color: Theme.textSecondary, lines: 2)
        counters.tag = WallScreenController.secondaryLabelTag

        let textStack = UIStackView(arrangedSubviews: [title, subtitle, counters])
        textStack.axis = .vertical
        textStack.spacing = 3

        let row = UIStackView(arrangedSubviews: [avatar, textStack])
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center

        headerStack.addArrangedSubview(row)
        return HeaderParts(avatar: avatar, title: title, subtitle: subtitle, counters: counters)
    }

    /// Обложка 4:3 на всю ширину шапки; стек шапки опускается под неё.
    /// Вызывается один раз даже при повторной загрузке профиля.
    func addCover(_ url: String) {
        guard hasCover == false, url.isEmpty == false else { return }
        hasCover = true

        let cover = RemoteImageView()
        cover.translatesAutoresizingMaskIntoConstraints = false
        cover.contentMode = .scaleAspectFill
        cover.clipsToBounds = true
        headerView.addSubview(cover)

        headerStackTop.isActive = false
        headerStackTop = headerStack.topAnchor.constraint(equalTo: cover.bottomAnchor, constant: 14)
        headerStackTop.isActive = true

        NSLayoutConstraint.activate([
            cover.topAnchor.constraint(equalTo: headerView.topAnchor),
            cover.leadingAnchor.constraint(equalTo: headerView.leadingAnchor),
            cover.trailingAnchor.constraint(equalTo: headerView.trailingAnchor),
            cover.heightAnchor.constraint(equalTo: headerView.widthAnchor, multiplier: 0.75)
        ])
        cover.setRemote(url, placeholder: Theme.divider)
    }

    /// Ряд кнопок-действий под шапкой.
    func addActionRow(_ actions: [(title: String, action: Selector, color: UIColor)]) {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 8

        for item in actions {
            let button = UIButton(type: .system)
            button.setTitle(item.title, for: .normal)
            button.setTitleColor(item.color, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
            button.backgroundColor = Theme.composerBackground
            button.addTarget(self, action: item.action, for: .touchUpInside)
            stack.addArrangedSubview(button)
        }

        stack.heightAnchor.constraint(equalToConstant: 40).isActive = true
        headerStack.addArrangedSubview(stack)
        actionButtonGroups.append(stack.arrangedSubviews.compactMap { $0 as? UIButton })
    }

    // MARK: - Стена

    @objc func refreshTapped() {
        load()
    }

    override func load() {
        wallOffset = 0
        setLoadingMore(false)
        loadWall()
    }

    /// Догрузка следующей страницы стены.
    override func loadMore() {
        guard isLoadingMore == false, isLoading == false, posts.isEmpty == false else { return }
        setLoadingMore(true)
        loadWall()
    }

    func loadWall() {
        setLoading(posts.isEmpty)
        showStatus(nil)

        // Догрузка следующих страниц стены через offset.
        var parameters = ["owner_id": String(wallOwnerId), "count": wallCount]
        if wallOffset > 0 {
            parameters["offset"] = String(wallOffset)
        }

        VKApiClient.shared.call("wall.get", parameters) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    self.readProfilesAndGroups(value)
                    let raw = VKPost.readList(value)
                    if self.isLoadingMore {
                        // При догрузке не дублируем записи первой страницы.
                        let known = Set(self.posts.map { $0.id })
                        let fresh = raw.filter { known.contains($0.id) == false }
                        self.wallOffset += raw.count
                        self.posts = self.posts + fresh
                        self.setLoadingMore(false)
                    } else {
                        self.wallOffset = raw.count
                        self.posts = raw
                    }
                    self.showStatus(self.posts.isEmpty ? "Записей пока нет" : nil)
                    self.reload()
                case .failure(let error):
                    self.setLoadingMore(false)
                    self.showError(error)
                }
            }
        }
    }

    func readProfilesAndGroups(_ value: Any) {
        users = VKUser.readList(value).reduce(into: [:]) { $0[$1.id] = $1 }
        groups = VKGroup.readList(value).reduce(into: [:]) { $0[$1.id] = $1 }
    }

    func authorName(for post: VKPost) -> String {
        if post.ownerIsGroup {
            return groups[post.groupId]?.title ?? "Сообщество"
        }
        if let user = users[post.fromId != 0 ? post.fromId : post.ownerId] {
            return user.name
        }
        return "OpenVK"
    }

    func authorScreenName(for post: VKPost) -> String? {
        if post.ownerIsGroup {
            return groups[post.groupId]?.screenName
        }
        return users[post.fromId != 0 ? post.fromId : post.ownerId]?.screenName
    }

    func authorPhoto(for post: VKPost) -> String? {
        if post.ownerIsGroup {
            return groups[post.groupId]?.photoMax
        }
        return users[post.fromId != 0 ? post.fromId : post.ownerId]?.photoMax
    }

    // MARK: - Таблица

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return posts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let post = posts[safe: indexPath.row],
            let cell = dequeueCell(PostCell.self,
                                   identifier: PostCell.reuseId,
                                   at: indexPath) else { return UITableViewCell() }
        cell.configure(post: post,
                       authorName: authorName(for: post),
                       authorScreenName: authorScreenName(for: post),
                       authorPhoto: authorPhoto(for: post))

        cell.onLike = { [weak self] in
            guard let self = self else { return }
            PostActions.toggleLike(post, in: self) {
                // `reloadRows` нельзя звать из сетевого callback во время
                // обновления таблицы — откладываем на следующий кадр.
                DispatchQueue.main.async {
                    guard let row = self.posts.identityIndex(of: post),
                        row < self.table.numberOfRows(inSection: 0) else { return }
                    self.table.reloadRows(at: [IndexPath(row: row, section: 0)], with: .none)
                }
            }
        }
        cell.onComment = { [weak self] in
            guard let self = self else { return }
            PostActions.openComments(post, in: self)
        }
        cell.onRepost = { [weak self] in
            guard let self = self else { return }
            PostActions.repost(post, in: self)
        }
        cell.onAuthor = { [weak self] in
            self?.openAuthor(of: post)
        }
        cell.onMore = { [weak self] in
            guard let self = self else { return }
            PostActions.openMenu(post, in: self)
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)
        guard let post = posts[safe: indexPath.row] else { return }
        PostActions.openComments(post, in: self)
    }

    func openAuthor(of post: VKPost) {
        if post.ownerIsGroup {
            if let group = groups[post.groupId] {
                Navigator.openGroup(group, in: self)
            } else {
                Navigator.openUser(id: -post.ownerId, in: self)
            }
        } else {
            Navigator.openUser(id: post.fromId != 0 ? post.fromId : post.ownerId, in: self)
        }
    }

    override func reload() {
        table.reloadData()
    }

    override func applyTheme() {
        super.applyTheme()
        headerView.backgroundColor = Theme.card
        for group in actionButtonGroups {
            for button in group {
                button.backgroundColor = Theme.composerBackground
            }
        }
        recolorLabels(in: headerStack)
    }

    /// Перекрашивает подписи шапки: вторичные помечены тегом.
    private func recolorLabels(in view: UIView) {
        if let label = view as? UILabel {
            label.textColor = (label.tag == WallScreenController.secondaryLabelTag) ? Theme.textSecondary : Theme.textPrimary
            return
        }
        for subview in view.subviews {
            recolorLabels(in: subview)
        }
    }
}