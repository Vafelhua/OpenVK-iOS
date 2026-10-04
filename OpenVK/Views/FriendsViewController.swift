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
        let header = UIStackView()
        header.axis = .vertical
        header.spacing = 0

        if pickerMode == false {
            let segments = UISegmentedControl(items: ["Все", "Онлайн"])
            segments.selectedSegmentIndex = 0
            segments.addTarget(self, action: #selector(filterChanged(_:)), for: .valueChanged)
            segments.translatesAutoresizingMaskIntoConstraints = false
            segments.heightAnchor.constraint(equalToConstant: 30).isActive = true
            header.addArrangedSubview(segments)
            header.layoutMargins = UIEdgeInsets(top: 6, left: 8, bottom: 2, right: 8)
            header.isLayoutMarginsRelativeArrangement = true
        }

        let bar = UISearchBar()
        bar.delegate = self
        bar.placeholder = "Поиск по друзьям"
        bar.searchBarStyle = .minimal
        bar.sizeToFit()
        header.addArrangedSubview(bar)
        searchBar = bar

        // Высота шапки считается по реальному содержимому: у UISearchBar своя
        // intrinsic-высота, и жёстко заданная константа обрезала бы его.
        let width = view.bounds.width
        header.frame = CGRect(x: 0, y: 0, width: width, height: 1)
        let fitted = header.systemLayoutSizeFitting(
            CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
            withHorizontalFittingPriority: .required,
            verticalFittingPriority: .fittingSizeLevel)
        header.frame = CGRect(x: 0, y: 0, width: width, height: max(fitted.height, 56))
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