import UIKit

/// Страница пользователя: шапка, счётчики, добавление в друзья, стена.
final class UserViewController: WallScreenController {
    private let user: VKUser
    private var headerParts: HeaderParts?
    private let addButton = UIButton(type: .system)
    private var isFriend = false

    init(user: VKUser) {
        self.user = user
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var wallOwnerId: Int { return user.id }
    override var wallCount: String { return "20" }

    override func buildHeader() {
        title = user.name

        let parts = addHeaderParts(avatarSize: 64, coverURL: user.photoMax)
        parts.avatar.setRemote(user.photoMax)
        parts.title.text = user.name
        parts.subtitle.text = user.subtitle
        parts.counters.text = user.countersText
        headerParts = parts

        // Дополнительная информация о пользователе — кнопкой в нав-баре.
        let infoItem = UIBarButtonItem(title: "Инфо", style: .plain, target: self, action: #selector(openInfo))
        navigationItem.rightBarButtonItems = [infoItem, navigationItem.rightBarButtonItem].compactMap { $0 }

        let actions = UIStackView()
        actions.axis = .horizontal
        actions.distribution = .fillEqually
        actions.spacing = 8

        let messageButton = UIButton(type: .system)
        messageButton.setTitle("Написать", for: .normal)
        messageButton.setTitleColor(Theme.accent, for: .normal)
        messageButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        messageButton.backgroundColor = Theme.composerBackground
        messageButton.addTarget(self, action: #selector(openChat), for: .touchUpInside)
        actions.addArrangedSubview(messageButton)

        let photosButton = UIButton(type: .system)
        photosButton.setTitle("Фото", for: .normal)
        photosButton.setTitleColor(Theme.accent, for: .normal)
        photosButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        photosButton.backgroundColor = Theme.composerBackground
        photosButton.addTarget(self, action: #selector(openPhotos), for: .touchUpInside)
        actions.addArrangedSubview(photosButton)

        addButton.setTitle("Добавить в друзья", for: .normal)
        addButton.setTitleColor(Theme.accent, for: .normal)
        addButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        addButton.backgroundColor = Theme.composerBackground
        addButton.addTarget(self, action: #selector(addFriend), for: .touchUpInside)
        actions.addArrangedSubview(addButton)

        actions.heightAnchor.constraint(equalToConstant: 40).isActive = true
        headerStack.addArrangedSubview(actions)

        refreshFriendState()
    }

    private func refreshFriendState() {
        guard user.id != LocalSettings.shared.userId else {
            addButton.setTitle("Это вы", for: .normal)
            addButton.isEnabled = false
            return
        }
        addButton.setTitle("Проверяем…", for: .normal)
        addButton.isEnabled = false

        VKApiClient.shared.call("friends.get", ["fields": "photo_50,photo_100"]) { [weak self] result in
            guard let self = self else { return }
            var found = false
            if case .success(let value) = result {
                let ids = VKUser.readList(value, key: "items").map { $0.id }
                found = ids.contains(self.user.id)
            }
            DispatchQueue.main.async {
                self.isFriend = found
                self.addButton.isEnabled = true
                self.addButton.setTitle(found ? "Вы друзья" : "Добавить в друзья", for: .normal)
                self.addButton.setTitleColor(found ? Theme.textSecondary : Theme.accent, for: .normal)
            }
        }
    }

    @objc private func addFriend() {
        guard isFriend == false else { return }
        addButton.isEnabled = false
        addButton.setTitle("Добавляем…", for: .normal)

        VKApiClient.shared.call("friends.add", ["user_id": String(user.id), "follow": "1"]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.addButton.isEnabled = true
                switch result {
                case .success:
                    self.isFriend = true
                    self.addButton.setTitle("Вы друзья", for: .normal)
                    self.addButton.setTitleColor(Theme.textSecondary, for: .normal)
                case .failure(let error):
                    self.addButton.setTitle("Добавить в друзья", for: .normal)
                    self.presentAlert(title: "Ошибка", message: error.message)
                }
            }
        }
    }

    @objc private func openChat() {
        let peer = VKPeer(id: user.id, kind: .user, title: user.name, photoURL: user.photoMax)
        Navigator.openChat(peer, in: self)
    }

    @objc private func openInfo() {
        navigationController?.pushViewController(UserInfoViewController(userId: user.id, name: user.name), animated: true)
    }

    @objc private func openPhotos() {
        Navigator.openPhotos(ownerId: user.id, in: self)
    }
}

/// Экран «Дополнительная информация»: подтягивает расширенные поля профиля
/// (`users.get` с большим списком fields) и показывает их списком.
final class UserInfoViewController: UITableViewController {
    private let userId: Int
    private let initialName: String
    private var rows: [(title: String, value: String)] = []

    init(userId: Int, name: String) {
        self.userId = userId
        self.initialName = name
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Информация"
        Theme.decorate(self)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 52
        tableView.backgroundColor = Theme.background
        load()
    }

    private func load() {
        setLoading(true)
        let fields = "photo_50,photo_100,photo_200,status,online,counters,bdate,city,country,about,site,domain,sex,relation,last_seen,verified"
        VKApiClient.shared.call("users.get",
                                ["user_ids": String(userId), "fields": fields]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    let dict = J.items(value).first as? [String: Any] ?? J.dict(value) ?? [:]
                    self.rows = self.makeRows(from: dict)
                    self.tableView.reloadData()
                case .failure(let error):
                    self.presentAlert(title: "Ошибка", message: error.message)
                }
            }
        }
    }

    private func setLoading(_ loading: Bool) {
        if loading {
            let spinner = UIActivityIndicatorView(style: .gray)
            spinner.startAnimating()
            tableView.backgroundView = spinner
        } else {
            tableView.backgroundView = nil
        }
    }

    private func makeRows(from dict: [String: Any]) -> [(title: String, value: String)] {
        var rows: [(title: String, value: String)] = []

        func add(_ title: String, _ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.isEmpty == false else { return }
            rows.append((title: title, value: trimmed))
        }

        add("Имя", J.getString(dict, "first_name", "") + " " + J.getString(dict, "last_name", ""))
        let screenName = J.getString(dict, "screen_name", "")
        add("Ник", screenName.isEmpty ? "" : "@" + screenName)

        let status = J.getString(dict, "status", "")
        add("Статус", status)

        let online = J.getBool(dict, "online", false)
        let lastSeen = J.getDict(dict, "last_seen")
        let lastSeenTime = J.getInt(lastSeen, "time", 0)
        if online {
            add("Был(а) в сети", "в сети")
        } else if lastSeenTime > 0 {
            add("Был(а) в сети", Self.dateText(from: lastSeenTime))
        }

        add("Пол", Self.sexText(J.getInt(dict, "sex", 0)))
        add("День рождения", J.getString(dict, "bdate", ""))

        let city = J.getDict(dict, "city")
        add("Город", J.getString(city, "title", ""))
        let country = J.getDict(dict, "country")
        add("Страна", J.getString(country, "title", ""))

        add("Сайт", J.getString(dict, "site", ""))
        add("О себе", J.getString(dict, "about", ""))
        add("Семейное положение", Self.relationText(J.getInt(dict, "relation", 0)))

        let counters = J.getDict(dict, "counters")
        add("Друзья", Self.countText(J.getInt(counters, "friends", 0)))
        add("Подписчики", Self.countText(J.getInt(counters, "followers", 0)))
        add("Подписки", Self.countText(J.getInt(counters, "subscriptions", 0)))

        add("ID", String(userId))
        return rows
    }

    private static func countText(_ value: Int) -> String {
        return value <= 0 ? "" : String(value)
    }

    private static func sexText(_ value: Int) -> String {
        switch value {
        case 1: return "Женский"
        case 2: return "Мужской"
        default: return ""
        }
    }

    private static func relationText(_ value: Int) -> String {
        switch value {
        case 1: return "Не женат/не замужем"
        case 2: return "Встречается"
        case 3: return "Помолвлен(а)"
        case 4: return "Женат/замужем"
        case 5: return "Всё сложно"
        case 6: return "В активном поиске"
        case 7: return "Влюблён(а)"
        case 8: return "В гражданском браке"
        default: return ""
        }
    }

    private static func dateText(from unix: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(unix))
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy, HH:mm"
        return formatter.string(from: date)
    }

    // MARK: - Таблица

    override func numberOfSections(in tableView: UITableView) -> Int {
        return rows.isEmpty ? 0 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return rows.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let row = rows[safe: indexPath.row] else { return UITableViewCell() }
        let identifier = "UserInfoCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier)
            ?? UITableViewCell(style: .subtitle, reuseIdentifier: identifier)
        cell.backgroundColor = Theme.card
        cell.textLabel?.text = row.title
        cell.textLabel?.font = UIFont.systemFont(ofSize: 13, weight: .semibold)
        cell.textLabel?.textColor = Theme.textSecondary
        cell.detailTextLabel?.text = row.value
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 16)
        cell.detailTextLabel?.textColor = Theme.textPrimary
        cell.detailTextLabel?.numberOfLines = 0
        cell.selectionStyle = .none
        return cell
    }
}

/// Ячейка сетки фотографий: квадратная миниатюра без скруглений в стиле VK 6.56.
final class PhotoGridCell: UICollectionViewCell {
    static let reuseId = "PhotoGridCell"

    private let photoImage = RemoteImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        photoImage.contentMode = .scaleAspectFill
        photoImage.clipsToBounds = true
        photoImage.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(photoImage)
        NSLayoutConstraint.activate([
            photoImage.topAnchor.constraint(equalTo: contentView.topAnchor),
            photoImage.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            photoImage.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            photoImage.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        photoImage.clear()
    }

    func configure(_ photo: VKPhoto) {
        photoImage.layer.cornerRadius = Theme.cardRadius
        photoImage.setRemote(photo.smallURL, placeholder: Theme.divider)
    }
}

/// Кнопка альбома в ленте над сеткой фотографий.
final class AlbumChipButton: UIButton {
    var albumId: Int?
    var isChosen: Bool = false {
        didSet { updateLook() }
    }

    func updateLook() {
        backgroundColor = isChosen ? Theme.accent : Theme.composerBackground
        setTitleColor(isChosen ? Theme.buttonText : Theme.accent, for: .normal)
        layer.borderWidth = isChosen ? 0 : 1
        layer.borderColor = Theme.divider.cgColor
    }
}

/// Сетка фотографий пользователя или сообщества с полноэкранным просмотром.
final class PhotosViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate {
    private let ownerId: Int
    private var photos: [VKPhoto] = []
    private var albums: [VKPhotoAlbum] = []
    private var selectedAlbumId: Int?
    private var offset = 0
    private var isLoading = false

    private let statusLabel = UILabel()
    private let spinner = UIActivityIndicatorView(style: .gray)
    private let albumBar = UIScrollView()
    private let albumStack = UIStackView()
    private lazy var collection: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = Theme.background
        view.alwaysBounceVertical = true
        view.dataSource = self
        view.delegate = self
        view.register(PhotoGridCell.self, forCellWithReuseIdentifier: PhotoGridCell.reuseId)
        return view
    }()

    init(ownerId: Int) {
        self.ownerId = ownerId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Фотографии"
        Theme.decorate(self)

        statusLabel.font = UIFont.systemFont(ofSize: 15)
        statusLabel.textColor = Theme.textSecondary
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        spinner.hidesWhenStopped = true
        spinner.translatesAutoresizingMaskIntoConstraints = false

        albumBar.translatesAutoresizingMaskIntoConstraints = false
        albumBar.showsHorizontalScrollIndicator = false
        albumBar.backgroundColor = Theme.background
        albumStack.axis = .horizontal
        albumStack.spacing = 8
        albumStack.alignment = .center
        albumStack.translatesAutoresizingMaskIntoConstraints = false
        albumBar.addSubview(albumStack)

        view.addSubview(albumBar)
        view.addSubview(collection)
        view.addSubview(statusLabel)
        view.addSubview(spinner)

        let safe = view.safeAreaLayoutGuide
        albumBarHeight = albumBar.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            albumBar.topAnchor.constraint(equalTo: safe.topAnchor),
            albumBar.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            albumBar.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            albumBarHeight,

            albumStack.topAnchor.constraint(equalTo: albumBar.topAnchor, constant: 6),
            albumStack.bottomAnchor.constraint(equalTo: albumBar.bottomAnchor, constant: -6),
            albumStack.leadingAnchor.constraint(equalTo: albumBar.leadingAnchor, constant: 12),
            albumStack.trailingAnchor.constraint(equalTo: albumBar.trailingAnchor, constant: -12),
            albumStack.heightAnchor.constraint(equalToConstant: 30),

            collection.topAnchor.constraint(equalTo: albumBar.bottomAnchor),
            collection.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            collection.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            statusLabel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),

            spinner.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: safe.centerYAnchor)
        ])

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(themeDidChange),
                                               name: .openVKThemeDidChange,
                                               object: nil)

        loadAlbums()
        load(reset: true)
    }

    private var albumBarHeight: NSLayoutConstraint!

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        guard let layout = collection.collectionViewLayout as? UICollectionViewFlowLayout else { return }
        // Сетка 3×N. Отступы вычитаем, чтобы последняя колонка не обрезалась.
        let side = floor((collection.bounds.width - 4) / 3)
        layout.itemSize = CGSize(width: side, height: side)
    }

    private func applyTheme() {
        Theme.decorate(self)
        collection.backgroundColor = Theme.background
        albumBar.backgroundColor = Theme.background
        statusLabel.textColor = Theme.textSecondary
        refreshAlbumChips()
    }

    @objc private func themeDidChange() {
        applyTheme()
    }

    // MARK: - Альбомы

    private func loadAlbums() {
        VKApiClient.shared.call("photos.getAlbums",
                                ["owner_id": String(ownerId),
                                 "count": "50"]) { [weak self] result in
            guard let self = self else { return }
            guard case .success(let value) = result else { return }
            self.albums = VKPhotoAlbum.readList(value)
                .filter { $0.id != -1 && $0.id != -3 } // служебные «все»/«фотоальбом»
            DispatchQueue.main.async {
                self.refreshAlbumChips()
                self.albumBarHeight.constant = self.albums.isEmpty ? 0 : 42
                self.view.layoutIfNeeded()
            }
        }
    }

    /// Горизонтальная лента альбомов. Пустой albumId — «все фотографии».
    private func refreshAlbumChips() {
        guard isViewLoaded else { return }
        for subview in albumStack.arrangedSubviews {
            albumStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        guard albums.isEmpty == false else { return }

        albumStack.addArrangedSubview(makeChip(title: "Все", albumId: nil))
        for album in albums {
            albumStack.addArrangedSubview(makeChip(title: album.displayTitle, albumId: album.id))
        }
        styleChips()
    }

    private func makeChip(title: String, albumId: Int?) -> AlbumChipButton {
        let button = AlbumChipButton(type: .system)
        button.albumId = albumId
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.layer.cornerRadius = Theme.isVK56 ? 2 : 15
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(albumTapped(_:)), for: .touchUpInside)
        button.updateLook()
        return button
    }

    private func styleChips() {
        for case let button as AlbumChipButton in albumStack.arrangedSubviews {
            button.isChosen = (button.albumId == nil && selectedAlbumId == nil)
                || (button.albumId != nil && button.albumId == selectedAlbumId)
        }
    }

    @objc private func albumTapped(_ sender: AlbumChipButton) {
        selectedAlbumId = sender.albumId
        styleChips()
        load(reset: true)
    }

    private func load(reset: Bool) {
        guard isLoading == false else { return }
        isLoading = true
        if reset {
            offset = 0
            spinner.startAnimating()
        }
        statusLabel.isHidden = true

        var parameters = ["owner_id": String(ownerId), "count": "100"]
        if offset > 0 { parameters["offset"] = String(offset) }
        if let albumId = selectedAlbumId { parameters["album_id"] = String(albumId) }

        VKApiClient.shared.call("photos.get", parameters) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isLoading = false
                self.spinner.stopAnimating()
                switch result {
                case .success(let value):
                    let raw = J.getArr(value, "items").compactMap { VKPhoto(dict: ($0 as? [String: Any]) ?? [:]) }
                    self.offset += raw.count
                    if reset {
                        self.photos = raw
                    } else {
                        let known = Set(self.photos.map { $0.id })
                        self.photos = self.photos + raw.filter { known.contains($0.id) == false }
                    }
                    self.collection.reloadData()
                    self.statusLabel.text = self.photos.isEmpty ? "Фотографий пока нет" : nil
                    self.statusLabel.isHidden = self.photos.isEmpty == false
                case .failure(let error):
                    self.statusLabel.text = self.photos.isEmpty ? error.message : nil
                    self.statusLabel.isHidden = self.photos.isEmpty == false
                }
            }
        }
    }

    // MARK: - Коллекция

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photos.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let photo = photos[safe: indexPath.item],
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotoGridCell.reuseId,
                                                           for: indexPath) as? PhotoGridCell else {
            return UICollectionViewCell()
        }
        cell.configure(photo)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let photo = photos[safe: indexPath.item] else { return }
        PhotoViewer.present(url: photo.bigURL)
    }

    @available(iOS 13.0, *)
    func collectionView(_ collectionView: UICollectionView,
                        contextMenuConfigurationForItemAt indexPath: IndexPath,
                        point: CGPoint) -> UIContextMenuConfiguration? {
        guard let photo = photos[safe: indexPath.item] else { return nil }
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            guard let self = self else { return nil }
            return self.makeMenu(for: photo)
        }
    }

    @available(iOS 13.0, *)
    private func makeMenu(for photo: VKPhoto) -> UIMenu {
        let items = [UIAction(title: "Открыть", image: UIFactory.icon("⤢", size: 16)) { _ in
            PhotoViewer.present(url: photo.bigURL)
        }]

        guard photo.ownerId == LocalSettings.shared.userId else {
            return UIMenu(title: "", children: items)
        }
        let remove = UIAction(title: "Удалить", attributes: .destructive) { [weak self] _ in
            self?.confirmDelete(photo)
        }
        return UIMenu(title: "", children: items + [remove])
    }

    private func confirmDelete(_ photo: VKPhoto) {
        let sheet = UIAlertController(title: "Удалить фотографию?",
                                      message: "Действие нельзя отменить.",
                                      preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.delete(photo)
        })
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = collection
            popover.sourceRect = CGRect(x: collection.bounds.midX,
                                        y: collection.bounds.midY,
                                        width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        present(sheet, animated: true, completion: nil)
    }

    private func delete(_ photo: VKPhoto) {
        setBusy(true)
        VKApiClient.shared.call("photos.delete",
                                ["owner_id": String(photo.ownerId),
                                 "photo_id": String(photo.id)]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setBusy(false)
                switch result {
                case .success:
                    self.photos = self.photos.filter { $0 !== photo }
                    self.offset = max(self.offset - 1, 0)
                    self.collection.reloadData()
                    self.statusLabel.text = self.photos.isEmpty ? "Фотографий пока нет" : nil
                    self.statusLabel.isHidden = self.photos.isEmpty == false
                case .failure(let error):
                    self.presentAlert(title: "Ошибка", message: error.message)
                }
            }
        }
    }

    private func setBusy(_ busy: Bool) {
        if busy {
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
        }
        collection.isUserInteractionEnabled = busy == false
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collection, photos.isEmpty == false else { return }
        let threshold = scrollView.contentSize.height - scrollView.bounds.height - 240
        if scrollView.contentOffset.y > threshold {
            load(reset: false)
        }
    }
}

/// Список пользователей, которым понравилась запись.
final class LikesViewController: TableScreenController {
    private let ownerId: Int
    private let postId: Int
    private var users: [VKUser] = []

    init(ownerId: Int, postId: Int) {
        self.ownerId = ownerId
        self.postId = postId
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var itemsCount: Int { return users.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Понравилось"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(refreshTapped))
        load()
    }

    @objc private func refreshTapped() {
        load()
    }

    override func load() {
        setLoading(users.isEmpty)
        showStatus(nil)

        VKApiClient.shared.call("likes.getUsers",
                                ["type": "post",
                                 "owner_id": String(ownerId),
                                 "item_id": String(postId),
                                 "count": "200",
                                 "fields": "photo_50,photo_100"]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    self.users = VKUser.readList(value)
                    self.showStatus(self.users.isEmpty ? "Нет оценок" : nil)
                    self.reload()
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let user = users[safe: indexPath.row],
            let cell = dequeueCell(MemberCell.self, identifier: MemberCell.reuseId, at: indexPath) else {
            return UITableViewCell()
        }
        cell.configure(user: user)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)
        guard let user = users[safe: indexPath.row] else { return }
        Navigator.openUser(user, in: self)
    }

    override func reload() {
        table.reloadData()
    }
}

/// Ячейка события: аватар, текст действия и автор со временем.
final class NotificationCell: UITableViewCell {
    static let reuseId = "NotificationCell"

    private let avatar = UIFactory.avatar(44)
    private let titleLabel = UIFactory.label("", size: 15)
    private let subtitleLabel = UIFactory.label("", size: 13, color: Theme.textSecondary)

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        selectionStyle = .default
        titleLabel.numberOfLines = 2
        subtitleLabel.numberOfLines = 1

        avatar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(avatar)

        let text = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        text.axis = .vertical
        text.spacing = 2
        text.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(text)

        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            avatar.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatar.topAnchor.constraint(greaterThanOrEqualTo: contentView.topAnchor, constant: 10),

            text.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            text.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            text.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            text.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatar.clear()
    }

    func configure(title: String, subtitle: String, photoURL: String?, showsArrow: Bool) {
        titleLabel.text = title
        subtitleLabel.text = subtitle
        avatar.setRemote(photoURL)
        accessoryType = showsArrow ? .disclosureIndicator : .none
    }

    func applyTheme() {
        contentView.backgroundColor = Theme.card
        titleLabel.textColor = Theme.textPrimary
        subtitleLabel.textColor = Theme.textSecondary
    }
}

/// События: лайки, комментарии, заявки в друзья, новые записи.
/// Поля ответа на разных инстансах отличаются, поэтому текст собирается
/// из того, что сервер вернул, а неизвестные типы показываются как есть.
final class NotificationsViewController: TableScreenController {
    private struct Item {
        let title: String
        let subtitle: String
        let photoURL: String?
        let userId: Int
        let photoTarget: VKPhoto?
    }

    private var items: [Item] = []
    private var offset = 0
    private var profiles: [Int: VKUser] = [:]

    override var itemsCount: Int { return items.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Уведомления"
        paginationEnabled = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(refreshTapped))
        load()
    }

    @objc private func refreshTapped() {
        load()
    }

    override func load() {
        setLoading(items.isEmpty)
        showStatus(nil)

        var parameters: [String: String] = ["count": "50"]
        if offset > 0 { parameters["offset"] = String(offset) }

        VKApiClient.shared.call("notifications.get", parameters) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                self.setLoadingMore(false)
                switch result {
                case .success(let value):
                    let raw = J.getArr(value, "items")
                    self.offset += raw.count
                    let fresh = raw.compactMap { self.makeItem(($0 as? [String: Any]) ?? [:]) }
                    if self.isLoadingMore {
                        self.items = self.items + fresh
                    } else {
                        self.offset = raw.count
                        self.items = fresh
                    }
                    if fresh.isEmpty {
                        self.showStatus(self.items.isEmpty ? "Пока нет событий" : nil)
                    }
                    self.loadProfiles()
                    self.reload()
                case .failure(let error):
                    // На части инстансов notifications.get отсутствует.
                    if error.isMethodMissing {
                        self.showStatus("Инстанс не поддерживает уведомления",
                                        isError: false)
                    } else {
                        self.showError(error)
                    }
                }
            }
        }
    }

    override func loadMore() {
        guard items.isEmpty == false else { return }
        load()
    }

    /// Подтягивает профили, чтобы у события были имя и аватар.
    private func loadProfiles() {
        let ids = items.compactMap { $0.userId != 0 ? $0.userId : nil }
        let missing = ids.filter { profiles[$0] == nil }
        guard missing.isEmpty == false else { return }

        let unique = Array(Set(missing)).map(String.init).joined(separator: ",")
        VKApiClient.shared.call("users.get",
                                ["user_ids": unique,
                                 "fields": "photo_50,photo_100"]) { [weak self] result in
            guard let self = self else { return }
            guard case .success(let value) = result else { return }
            for user in VKUser.readList(value) {
                self.profiles[user.id] = user
            }
            DispatchQueue.main.async { self.reload() }
        }
    }

    private func makeItem(_ dict: [String: Any]) -> Item? {
        let type = J.getString(dict, "type", "")
        guard type.isEmpty == false else { return nil }
        let date = J.getInt(dict, "date", 0)

        // Источник события: для заявок в друзья это `friend`, для остального —
        // `user_id` внутри вложенного объекта.
        var userId = J.getInt(J.getDict(dict, "friend"), "id", 0)
        if userId == 0 {
            let subject = J.getDict(dict, dict["like"] != nil ? "like"
                : (dict["comment"] != nil ? "comment" : "subject"))
            userId = J.getInt(subject, "user_id", 0)
        }
        if userId == 0 {
            userId = J.getInt(dict, "user_id", 0)
        }

        let authorName = profiles[userId]?.name ?? ""
        let commentText = J.getString(J.getDict(dict, "comment"), "text", "")
        let photo = VKPhoto(dict: J.getDict(dict, "photo"))
        var attachedPhoto = photo

        if attachedPhoto == nil {
            let attachment = VKAttachment(dict: dict["attach"] as? [String: Any] ?? [:])
            attachedPhoto = attachment.photo
        }

        var text: String
        switch type {
        case "friend":
            text = "Добавил вас в друзья"
        case "like":
            text = "Оценил вашу запись"
        case "comment", "photo_comment":
            text = commentText.isEmpty ? "Комментировал запись" : commentText
        case "post":
            text = "Опубликовал запись на вашей стене"
        case "group_join":
            text = "Вступил в сообщество"
        case "mention", "mention_comment":
            text = "Упомянул вас"
        default:
            text = "Событие: \(type)"
        }

        let subtitle = authorName.isEmpty
            ? TimeHelper.relative(date)
            : authorName + " · " + TimeHelper.relative(date)

        return Item(title: text,
                    subtitle: subtitle,
                    photoURL: profiles[userId]?.photoMax,
                    userId: userId,
                    photoTarget: attachedPhoto)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let item = items[safe: indexPath.row],
            let cell = dequeueCell(NotificationCell.self,
                                   identifier: NotificationCell.reuseId,
                                   at: indexPath) else { return UITableViewCell() }
        cell.configure(title: item.title,
                       subtitle: item.subtitle,
                       photoURL: item.photoURL,
                       showsArrow: item.userId != 0)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)
        guard let item = items[safe: indexPath.row] else { return }

        if let photo = item.photoTarget {
            PhotoViewer.present(url: photo.bigURL)
            return
        }
        if item.userId != 0 {
            Navigator.openUser(id: item.userId, in: self)
        }
    }

    override func reload() {
        table.reloadData()
    }

    override func applyTheme() {
        super.applyTheme()
        for case let cell as NotificationCell in table.visibleCells {
            cell.applyTheme()
        }
    }
}