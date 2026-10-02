import UIKit

/// Модальный список комментариев к записи (wall.getComments / wall.createComment).
final class CommentsViewController: TableScreenController {
    private let post: VKPost
    private var comments: [VKComment] = []
    /// Смещение для догрузки следующих страниц комментариев.
    private var commentsOffset = 0

    private let composer = UIView()
    private let input = UITextField()
    private let sendButton = UIButton(type: .system)
    private var composerBottom: NSLayoutConstraint!

    init(post: VKPost) {
        self.post = post
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var itemsCount: Int { return comments.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        paginationEnabled = true
        title = "Комментарии"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Закрыть",
                                                           style: .plain,
                                                           target: self,
                                                           action: #selector(closeTapped))
        buildComposer()
        load()
    }

    private func buildComposer() {
        composer.translatesAutoresizingMaskIntoConstraints = false
        composer.backgroundColor = Theme.composerBackground

        let topLine = UIView()
        topLine.backgroundColor = Theme.divider
        topLine.translatesAutoresizingMaskIntoConstraints = false

        input.placeholder = "Ваш комментарий"
        input.font = UIFont.systemFont(ofSize: 15)
        input.textColor = Theme.textPrimary
        input.backgroundColor = Theme.card
        input.borderStyle = .none
        input.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 36))
        input.leftViewMode = .always
        input.returnKeyType = .send
        input.delegate = self
        input.translatesAutoresizingMaskIntoConstraints = false

        sendButton.setTitle("Отправить", for: .normal)
        sendButton.setTitleColor(Theme.accent, for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(composer)
        composer.addSubview(topLine)
        composer.addSubview(input)
        composer.addSubview(sendButton)

        composerBottom = composer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        composer.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0,
                                                                     leading: 12,
                                                                     bottom: 0,
                                                                     trailing: 12)

        NSLayoutConstraint.activate([
            composerBottom,
            composer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composer.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),

            topLine.topAnchor.constraint(equalTo: composer.topAnchor),
            topLine.leadingAnchor.constraint(equalTo: composer.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: composer.trailingAnchor),
            topLine.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            input.leadingAnchor.constraint(equalTo: composer.layoutMarginsGuide.leadingAnchor),
            input.topAnchor.constraint(equalTo: composer.topAnchor, constant: 8),
            input.bottomAnchor.constraint(equalTo: composer.bottomAnchor, constant: -8),
            input.heightAnchor.constraint(equalToConstant: 36),

            sendButton.leadingAnchor.constraint(equalTo: input.trailingAnchor, constant: 8),
            sendButton.trailingAnchor.constraint(equalTo: composer.layoutMarginsGuide.trailingAnchor),
            sendButton.centerYAnchor.constraint(equalTo: input.centerYAnchor)
        ])

        pinTableBottom(to: composer.topAnchor)
        table.separatorInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChange),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let converted = view.convert(frame, from: nil)
        composerBottom.constant = -max(0, view.bounds.maxY - converted.minY)
        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - Данные

    override func load() {
        setLoading(comments.isEmpty)
        showStatus(nil)

        var parameters: [String: String] = ["post_id": String(post.id), "count": "30", "extended": "1"]
        if post.ownerId != 0 {
            parameters["owner_id"] = String(post.ownerId)
        }
        if commentsOffset > 0 {
            parameters["offset"] = String(commentsOffset)
        }

        VKApiClient.shared.call("wall.getComments", parameters) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    let raw = VKComment.readList(value)
                    if self.isLoadingMore {
                        // Догрузка: фильтруем по id, комментарии любят повторяться
                        // при пересечении страниц.
                        let known = Set(self.comments.map { $0.id })
                        let fresh = raw.filter { known.contains($0.id) == false }
                        self.commentsOffset += raw.count
                        self.comments = self.comments + fresh
                        self.setLoadingMore(false)
                    } else {
                        self.commentsOffset = raw.count
                        self.comments = raw
                    }
                    self.showStatus(self.comments.isEmpty ? "Комментариев пока нет" : nil)
                    self.reload()
                case .failure(let error):
                    self.setLoadingMore(false)
                    self.showError(error)
                }
            }
        }
    }

    /// Догрузка следующей страницы комментариев.
    override func loadMore() {
        guard isLoadingMore == false, isLoading == false, comments.isEmpty == false else { return }
        setLoadingMore(true)
        load()
    }

    @objc private func sendTapped() {
        let text = (input.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        guard text.count <= 10000 else {
            presentAlert(title: "Слишком длинно", message: "Комментарий не должен превышать 10 000 символов.")
            return
        }

        var parameters = ["post_id": String(post.id), "message": text]
        if post.ownerId != 0 {
            parameters["owner_id"] = String(post.ownerId)
        }

        input.text = nil
        sendButton.isEnabled = false

        VKApiClient.shared.call("wall.createComment", parameters) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.sendButton.isEnabled = true
                switch result {
                case .success:
                    self.load()
                case .failure(let error):
                    self.presentAlert(title: "Ошибка", message: error.message)
                }
            }
        }
    }

    // MARK: - Таблица

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let comment = comments[safe: indexPath.row],
            let cell = dequeueCell(MemberCell.self,
                                   identifier: MemberCell.reuseId,
                                   at: indexPath) else { return UITableViewCell() }
        cell.configure(title: comment.text, subtitle: comment.subtitle, photo: comment.authorPhoto)
        return cell
    }

    override func applyTheme() {
        super.applyTheme()
        composer.backgroundColor = Theme.composerBackground
        input.textColor = Theme.textPrimary
        input.backgroundColor = Theme.card
    }
}

// MARK: - UITextFieldDelegate

extension CommentsViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendTapped()
        return true
    }
}

/// Комментарий к записи: автор берётся из profiles/groups ответа метода.
struct VKComment {
    /// Идентификатор нужен для дедупликации при пагинации:
    /// сервер отдаёт пересекающиеся страницы комментариев.
    let id: Int
    let text: String
    let authorName: String
    let authorPhoto: String?
    let date: Int

    var subtitle: String {
        if date == 0 { return authorName }
        return "\(authorName) · \(TimeHelper.relative(date))"
    }

    static func readList(_ result: Any?) -> [VKComment] {
        let profiles = VKUser.readList(result)
        let groups = VKGroup.readList(result)

        return J.items(result).compactMap { element -> VKComment? in
            guard let dict = element as? [String: Any] else { return nil }
            let text = J.getString(dict, "text", "")
            let fromId = J.getInt(dict, "from_id", 0)
            let user = profiles.first(where: { $0.id == fromId })
            let group = groups.first(where: { $0.id == abs(fromId) })
            let authorName = user?.name ?? group?.name ?? "OpenVK"
            let authorPhoto = user?.photoMax ?? group?.photoMax
            return VKComment(id: J.getInt(dict, "id", 0),
                             text: text,
                             authorName: authorName,
                             authorPhoto: authorPhoto,
                             date: J.getInt(dict, "date", 0))
        }
    }
}