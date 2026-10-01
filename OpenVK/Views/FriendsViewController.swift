import UIKit

/// Список друзей с локальным фильтром по имени.
final class FriendsViewController: TableScreenController, UISearchBarDelegate {
    private var friends: [VKUser] = []
    private var filtered: [VKUser] = []
    private var searchBar: UISearchBar?

    override var itemsCount: Int { return filtered.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(refreshTapped))

        let bar = UISearchBar()
        bar.delegate = self
        bar.placeholder = "Поиск по друзьям"
        bar.searchBarStyle = .minimal
        bar.sizeToFit()
        table.tableHeaderView = bar
        searchBar = bar

        load()
    }

    @objc private func refreshTapped() {
        load()
    }

    override func load() {
        setLoading(friends.isEmpty)
        showStatus(nil)

        VKApiClient.shared.call("friends.get", ["fields": "photo_50,photo_100,status,online",
                                                "count": "200",
                                                "order": "hints"]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    self.friends = VKUser.readList(value, key: "items")
                    self.applyFilter("")
                    self.showStatus(self.friends.isEmpty ? "Список друзей пуст" : nil)
                    self.reload()
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        applyFilter(searchText)
        reload()
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }

    private func applyFilter(_ query: String) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if text.isEmpty {
            filtered = friends
            return
        }
        filtered = friends.filter {
            $0.name.lowercased().contains(text) || $0.screenName.lowercased().contains(text)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filtered.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = table.dequeueReusableCell(withIdentifier: MemberCell.reuseId, for: indexPath) as! MemberCell
        cell.configure(user: filtered[indexPath.row])
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)
        let user = filtered[indexPath.row]
        Navigator.openChat(VKPeer(id: user.id, kind: .user, title: user.name, photoURL: user.photoMax),
                           in: self)
    }

    override func reload() {
        table.reloadData()
    }
}