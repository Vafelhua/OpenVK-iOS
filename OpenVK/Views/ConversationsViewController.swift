import UIKit

/// Список диалогов.
final class ConversationsViewController: TableScreenController {
    private var conversations: [VKConversation] = []

    /// Смещение для догрузки следующих страниц диалогов.
    private var conversationsOffset = 0

    override var itemsCount: Int { return conversations.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        paginationEnabled = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(refreshTapped))
        load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Обновляем уже загруженный список: непрочитанные могли прийти в фоне.
        if conversations.isEmpty == false {
            refreshFirstPage()
        }
    }

    @objc private func refreshTapped() {
        refreshFirstPage()
    }

    /// Перезагрузка с нуля: первая страница заменяет список целиком,
    /// чтобы вернуть диалог, ушедший вниз после нового сообщения.
    private func refreshFirstPage() {
        conversationsOffset = 0
        load()
    }

    override func load() {
        setLoading(conversations.isEmpty)
        showStatus(nil)

        var parameters = ["count": "30", "extended": "1"]
        if conversationsOffset > 0 {
            parameters["offset"] = String(conversationsOffset)
        }

        VKApiClient.shared.call("messages.getConversations", parameters) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    var fresh = VKConversation.readList(value)
                    if self.conversationsOffset > 0 {
                        // При догрузке диалоги пересекаются с первой страницей —
                        // фильтруем по peer, иначе в списке появляются дубли.
                        let known = Set(self.conversations.map { $0.peer.id })
                        fresh = fresh.filter { known.contains($0.peer.id) == false }
                        self.conversations = self.conversations + fresh
                        self.setLoadingMore(false)
                    } else {
                        self.conversationsOffset = fresh.count
                        self.conversations = fresh
                    }
                    self.showStatus(self.conversations.isEmpty ? "Диалогов пока нет" : nil)
                    self.reload()
                case .failure(let error):
                    self.setLoadingMore(false)
                    self.showError(error)
                }
            }
        }
    }

    /// Догрузка следующей страницы диалогов.
    override func loadMore() {
        guard isLoadingMore == false, isLoading == false, conversations.isEmpty == false else { return }
        setLoadingMore(true)
        conversationsOffset += 30
        load()
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