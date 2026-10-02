import UIKit

/// Список сообществ.
final class GroupsViewController: TableScreenController {
    private var groups: [VKGroup] = []

    override var itemsCount: Int { return groups.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(refreshTapped))
        load()
    }

    @objc private func refreshTapped() {
        load()
    }

    override func load() {
        setLoading(groups.isEmpty)
        showStatus(nil)

        VKApiClient.shared.call("groups.get", ["extended": "1",
                                                "fields": "photo_50,photo_100,members_count,type",
                                                "count": "100"]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    self.groups = VKGroup.readList(value, key: "items")
                    self.showStatus(self.groups.isEmpty ? "Вы не состоите ни в одном сообществе" : nil)
                    self.reload()
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return groups.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let group = groups[safe: indexPath.row],
            let cell = dequeueCell(MemberCell.self,
                                   identifier: MemberCell.reuseId,
                                   at: indexPath) else { return UITableViewCell() }
        cell.configure(group: group)
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)
        guard let group = groups[safe: indexPath.row] else { return }
        Navigator.openGroup(group, in: self)
    }

    override func reload() {
        table.reloadData()
    }
}