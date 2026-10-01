import UIKit

/// Список диалогов.
final class ConversationsViewController: TableScreenController {
    private var conversations: [VKConversation] = []

    override var itemsCount: Int { return conversations.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(refreshTapped))
        load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if conversations.isEmpty == false { load() }
    }

    @objc private func refreshTapped() {
        load()
    }

    override func load() {
        setLoading(conversations.isEmpty)
        showStatus(nil)

        VKApiClient.shared.call("messages.getConversations", ["count": "30", "extended": "1"]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    self.conversations = VKConversation.readList(value)
                    self.showStatus(self.conversations.isEmpty ? "Диалогов пока нет" : nil)
                    self.reload()
                case .failure(let error):
                    self.showError(error)
                }
            }
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = table.dequeueReusableCell(withIdentifier: ConversationCell.reuseId, for: indexPath) as! ConversationCell
        conversations[indexPath.row].apply(to: cell)
        cell.applyTheme()
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)
        let conversation = conversations[indexPath.row]
        Navigator.openChat(conversation.peer, in: self)
    }

    override func reload() {
        table.reloadData()
    }
}