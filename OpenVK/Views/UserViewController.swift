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