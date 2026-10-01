import UIKit

/// Новостная лента: глобальная/личная, поиск людей и записей, лайки, комментарии, репост.
final class NewsfeedViewController: TableScreenController, UISearchBarDelegate {
    private var posts: [VKPost] = []
    private var foundUsers: [VKUser] = []
    private var foundPosts: [VKPost] = []
    private var users: [Int: VKUser] = [:]
    private var groups: [Int: VKGroup] = [:]

    private var isGlobal = true
    private var isSearching = false
    private var searchBar: UISearchBar?

    /// Смещение для догрузки ленты (`newsfeed.get` и `newsfeed.getGlobal`).
    private var feedOffset = 0
    /// Страница возвращает меньше лимита — значит, дальше записей нет.
    private var reachedFeedEnd = false

    private let scopeButton = UIBarButtonItem(title: "Глобальная", style: .plain, target: nil, action: nil)
    private lazy var refreshButton = UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refreshTapped))
    private lazy var searchButton = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(searchTapped))

    override var itemsCount: Int { return posts.count + foundUsers.count + foundPosts.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        paginationEnabled = true
        scopeButton.target = self
        scopeButton.action = #selector(scopeTapped)
        navigationItem.rightBarButtonItems = [searchButton, scopeButton, refreshButton]
        load()
    }

    // MARK: - Загрузка

    override func load() {
        if isSearching {
            runSearch(searchBar?.text ?? "")
            return
        }
        setLoading(itemsCount == 0)
        showStatus(nil)

        let method = isGlobal ? "newsfeed.getGlobal" : "newsfeed.get"
        var parameters: [String: String] = isGlobal
            ? ["count": "20"]
            : ["filters": "post", "count": "20"]
        if feedOffset > 0 {
            parameters["offset"] = String(feedOffset)
        }

        VKApiClient.shared.call(method, parameters) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)

                switch result {
                case .success(let value):
                    self.readProfilesAndGroups(value)
                    var fresh = VKPost.readList(value)
                    if self.feedOffset > 0 {
                        // Догрузка: не дублируем записи первой страницы.
                        let known = Set(self.posts.map { $0.id })
                        fresh = fresh.filter { known.contains($0.id) == false }
                        self.posts = self.posts + fresh
                        self.setLoadingMore(false)
                    } else {
                        self.feedOffset = fresh.count
                        self.posts = fresh
                    }
                    // Страница короче лимита — лента исчерпана, догружать больше нечего.
                    self.reachedFeedEnd = fresh.count < 20
                    self.showStatus(self.posts.isEmpty ? "Пока нет записей" : nil)
                    self.reload()
                case .failure(let error):
                    // На части инстансов newsfeed.getGlobal отсутствует (error_code 3).
                    if error.isMethodMissing && self.isGlobal {
                        self.isGlobal = false
                        self.updateScopeTitle()
                        self.load()
                        return
                    }
                    self.setLoadingMore(false)
                    self.showError(error)
                }
            }
        }
    }

    /// Догрузка следующей страницы ленты.
    override func loadMore() {
        guard isLoadingMore == false, isLoading == false, reachedFeedEnd == false else { return }
        setLoadingMore(true)
        feedOffset += 20
        load()
    }

    /// Номер последнего введённого текста: ответы «старых» запросов игнорируются,
    /// иначе медленный ответ по «кот» перетирает результат по «кото».
    private var searchGeneration = 0
    private var searchDebounce: DispatchWorkItem?

    private func runSearch(_ query: String) {
        searchDebounce?.cancel()
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            foundUsers = []
            foundPosts = []
            showStatus(nil)
            reload()
            return
        }

        // Пауза перед запросом: сокращает число обращений к API и убирает
        // «мигание» результатов на каждое нажатие.
        let work = DispatchWorkItem { [weak self] in self?.performSearch(text) }
        searchDebounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func performSearch(_ text: String) {
        searchGeneration += 1
        let generation = searchGeneration

        setLoading(foundUsers.isEmpty && foundPosts.isEmpty)
        let group = DispatchGroup()

        group.enter()
        VKApiClient.shared.call("users.search",
                                ["q": text, "count": "15", "fields": "photo_100,status,online"],
                                cancelKey: "newsfeed.search.users") { [weak self] result in
            if case .success(let value) = result {
                DispatchQueue.main.async {
                    guard let self = self, self.searchGeneration == generation else { return }
                    self.foundUsers = VKUser.readList(value, key: "items")
                    self.reload()
                }
            }
            group.leave()
        }

        group.enter()
        VKApiClient.shared.call("newsfeed.search",
                                ["q": text, "count": "20"],
                                cancelKey: "newsfeed.search.posts") { [weak self] result in
            switch result {
            case .success(let value):
                DispatchQueue.main.async {
                    guard let self = self, self.searchGeneration == generation else { return }
                    self.readProfilesAndGroups(value)
                    self.foundPosts = VKPost.readList(value)
                    self.reload()
                }
            case .failure:
                break
            }
            group.leave()
        }

        group.notify(queue: .main) { [weak self] in
            guard let self = self, self.searchGeneration == generation else { return }
            self.setLoading(false)
            if self.foundUsers.isEmpty && self.foundPosts.isEmpty {
                self.showStatus("Ничего не найдено по запросу «\(text)»")
            } else {
                self.showStatus(nil)
            }
        }
    }

    private func readProfilesAndGroups(_ value: Any) {
        let profiles = VKUser.readList(value)
        let groupList = VKGroup.readList(value)
        users = profiles.reduce(into: [:]) { $0[$1.id] = $1 }
        groups = groupList.reduce(into: [:]) { $0[$1.id] = $1 }
    }

    // MARK: - Действия

    @objc private func refreshTapped() {
        load()
    }

    @objc private func scopeTapped() {
        isGlobal = isGlobal == false
        updateScopeTitle()
        posts = []
        feedOffset = 0
        reachedFeedEnd = false
        load()
    }

    private func updateScopeTitle() {
        scopeButton.title = isGlobal ? "Глобальная" : "Моя"
    }

    @objc private func searchTapped() {
        isSearching = isSearching == false
        setSearchMode(isSearching)
    }

    private func setSearchMode(_ enabled: Bool) {
        searchDebounce?.cancel()
        VKApiClient.shared.cancel("newsfeed.search.users")
        VKApiClient.shared.cancel("newsfeed.search.posts")
        if enabled {
            let bar = UISearchBar()
            bar.delegate = self
            bar.placeholder = "Люди и записи"
            bar.searchBarStyle = .minimal
            bar.showsCancelButton = true
            bar.sizeToFit()
            table.tableHeaderView = bar
            searchBar = bar
            posts = []
            foundUsers = []
            foundPosts = []
            reload()
            bar.becomeFirstResponder()
        } else {
            table.tableHeaderView = nil
            searchBar = nil
            foundUsers = []
            foundPosts = []
            load()
        }
        navigationItem.rightBarButtonItems = isSearching
            ? [refreshButton, scopeButton]
            : [searchButton, scopeButton, refreshButton]
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        runSearch(searchText)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchDebounce?.cancel()
        performSearch((searchBar.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        setSearchMode(false)
    }

    // MARK: - Таблица

    override func tableView(_ tableView: UITableView, numberOfSections section: Int) -> Int {
        return isSearching ? 2 : 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isSearching {
            return section == 0 ? foundUsers.count : foundPosts.count
        }
        return posts.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard isSearching else { return nil }
        if section == 0 {
            return foundUsers.isEmpty ? nil : "Люди"
        }
        return foundPosts.isEmpty ? nil : "Записи"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if isSearching && indexPath.section == 0 {
            let cell = table.dequeueReusableCell(withIdentifier: MemberCell.reuseId, for: indexPath) as! MemberCell
            cell.configure(user: foundUsers[indexPath.row])
            return cell
        }

        let list = isSearching ? foundPosts : posts
        let post = list[indexPath.row]
        let cell = table.dequeueReusableCell(withIdentifier: PostCell.reuseId, for: indexPath) as! PostCell
        cell.configure(post: post, authorName: authorName(for: post), authorPhoto: authorPhoto(for: post))

        cell.onLike = { [weak self] in
            guard let self = self else { return }
            PostActions.toggleLike(post, in: self) {
                self.reloadRow(with: post, isFound: self.isSearching)
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
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)

        if isSearching && indexPath.section == 0 {
            Navigator.openUser(foundUsers[indexPath.row], in: self)
            return
        }
        let list = isSearching ? foundPosts : posts
        guard indexPath.row < list.count else { return }
        PostActions.openComments(list[indexPath.row], in: self)
    }

    private func reloadRow(with post: VKPost, isFound: Bool) {
        let list = isFound ? foundPosts : posts
        guard let row = list.identityIndex(of: post) else { return }
        let section = isFound ? 1 : 0
        guard row < table.numberOfRows(inSection: section) else { return }
        table.reloadRows(at: [IndexPath(row: row, section: section)], with: .none)
    }

    private func openAuthor(of post: VKPost) {
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

    private func authorName(for post: VKPost) -> String {
        if post.ownerIsGroup {
            return groups[post.groupId]?.title ?? "Сообщество"
        }
        if let user = users[post.fromId != 0 ? post.fromId : post.ownerId] {
            return user.name
        }
        return "OpenVK"
    }

    private func authorPhoto(for post: VKPost) -> String? {
        if post.ownerIsGroup {
            return groups[post.groupId]?.photoMax
        }
        return users[post.fromId != 0 ? post.fromId : post.ownerId]?.photoMax
    }

    override func reload() {
        table.reloadData()
    }
}