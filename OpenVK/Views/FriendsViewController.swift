import UIKit

/// Список друзей с локальным фильтром по имени.
final class FriendsViewController: TableScreenController, UISearchBarDelegate {
    private var friends: [VKUser] = []
    private var filtered: [VKUser] = []
    private var searchBar: UISearchBar?
    private var onlineOnly = false
    private var currentQuery = ""

    /// Режим выбора собеседника: заголовок меняется на «Новое сообщение».
    var pickerMode = false

    override var itemsCount: Int { return filtered.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = pickerMode ? "Новое сообщение" : "Друзья"
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(refreshTapped))

        // В режиме выбора собеседника фильтры лишние — только поиск.
        var headerHeight: CGFloat = 52
        let header = UIStackView()
        header.axis = .vertical
        header.spacing = 0

        if pickerMode == false {
            let segments = UISegmentedControl(items: ["Все", "Онлайн"])
            segments.selectedSegmentIndex = 0
            segments.addTarget(self, action: #selector(filterChanged(_:)), for: .valueChanged)
            segments.frame = CGRect(x: 8, y: 4, width: view.bounds.width - 16, height: 32)
            segments.autoresizingMask = [.flexibleWidth]
            header.addArrangedSubview(segments)
            headerHeight += 40
        }

        let bar = UISearchBar()
        bar.delegate = self
        bar.placeholder = "Поиск по друзьям"
        bar.searchBarStyle = .minimal
        bar.sizeToFit()
        header.addArrangedSubview(bar)
        searchBar = bar

        header.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: headerHeight)
        header.autoresizingMask = [.flexibleWidth]
        table.tableHeaderView = header

        load()
    }

    @objc private func filterChanged(_ sender: UISegmentedControl) {
        onlineOnly = sender.selectedSegmentIndex == 1
        applyFilter(currentQuery)
        reload()
    }

    @objc private func refreshTapped() {
        load()
    }

    override func load() {
        setLoading(friends.isEmpty)
        showStatus(nil)

        VKApiClient.shared.call("friends.get", ["fields": "photo_50,photo_100,photo_200,status,online",
                                                "count": "200",
                                                "order": "hints"]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    self.friends = VKUser.readList(value, key: "items")
                    self.applyFilter(self.currentQuery)
                    self.reload()
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        currentQuery = searchText
        applyFilter(searchText)
        reload()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    private func applyFilter(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var source = friends
        if onlineOnly {
            source = source.filter { $0.isOnline }
        }
        if text.isEmpty {
            filtered = source
        } else {
            filtered = source.filter {
                $0.name.lowercased().contains(text) || $0.screenName.lowercased().contains(text)
            }
        }
        showStatus(filtered.isEmpty ? (source.isEmpty ? "Список друзей пуст" : "Никого не найдено") : nil)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filtered.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let user = filtered[safe: indexPath.row],
            let cell = dequeueCell(MemberCell.self,
                                   identifier: MemberCell.reuseId,
                                   at: indexPath) else { return UITableViewCell() }
        cell.configure(user: user)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)
        guard let user = filtered[safe: indexPath.row] else { return }
        Navigator.openChat(VKPeer(id: user.id, kind: .user, title: user.name, photoURL: user.photoMax),
                           in: self)
    }

    override func reload() {
        table.reloadData()
    }
}