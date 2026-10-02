import UIKit

/// Список диалогов.
final class ConversationsViewController: TableScreenController {
    private var conversations: [VKConversation] = []

    /// Смещение для догрузки следующих страниц диалогов.
    private var conversationsOffset = 0
    /// Запрос уже в полёте — второй ответ перетирал бы первый.
    private var isFetching = false

    override var itemsCount: Int { return conversations.count }

    private lazy var composeButton = UIBarButtonItem(barButtonSystemItem: .compose,
                                                     target: self,
                                                     action: #selector(composeTapped))

    override func viewDidLoad() {
        super.viewDidLoad()
        paginationEnabled = true
        navigationItem.leftBarButtonItem = composeButton
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .refresh,
                                                            target: self,
                                                            action: #selector(refreshTapped))
        load()
    }

    /// Новое личное сообщение: список друзей, выбор открывает диалог.
    @objc private func composeTapped() {
        let picker = FriendsViewController()
        picker.pickerMode = true
        navigationController?.pushViewController(picker, animated: true)
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
        setLoadingMore(false)
        load()
    }

    override func load() {
        guard isFetching == false else { return }
        isFetching = true
        setLoading(conversations.isEmpty)
        showStatus(nil)

        var parameters = ["count": "30", "extended": "1"]
        if conversationsOffset > 0 {
            parameters["offset"] = String(conversationsOffset)
        }

        VKApiClient.shared.call("messages.getConversations", parameters) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isFetching = false
                self.setLoading(false)
                switch result {
                case .success(let value):
                    let raw = VKConversation.readList(value)
                    if self.isLoadingMore {
                        // При догрузке диалоги пересекаются с первой страницей —
                        // фильтруем по peer, иначе в списке появляются дубли.
                        let known = Set(self.conversations.map { $0.peer.id })
                        let fresh = raw.filter { known.contains($0.peer.id) == false }
                        self.conversations = self.conversations + fresh
                        self.conversationsOffset += raw.count
                        self.setLoadingMore(false)
                    } else {
                        self.conversationsOffset = raw.count
                        self.conversations = raw
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
        load()
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return conversations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let conversation = conversations[safe: indexPath.row],
            let cell = dequeueCell(ConversationCell.self,
                                   identifier: ConversationCell.reuseId,
                                   at: indexPath) else { return UITableViewCell() }
        conversation.apply(to: cell)
        cell.applyTheme()
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        table.deselectRow(at: indexPath, animated: true)
        guard let conversation = conversations[safe: indexPath.row] else { return }
        Navigator.openChat(conversation.peer, in: self)
    }

    override func reload() {
        table.reloadData()
    }
}