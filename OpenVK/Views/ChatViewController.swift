import UIKit

/// Экран переписки: история сообщений, Long Poll (с откатом на опрос), отправка.
final class ChatViewController: TableScreenController, UITextViewDelegate {
    private let peer: VKPeer
    private var messages: [VKMessage] = []

    private let composer = UIView()
    private let input = UITextView()
    private let sendButton = UIButton(type: .system)
    private let placeholderLabel = UIFactory.label("Сообщение…", size: 15, color: Theme.textSecondary)
    private var composerBottom: NSLayoutConstraint!
    private let longPoll = LongPollClient()

    init(peer: VKPeer) {
        self.peer = peer
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var itemsCount: Int { return messages.count }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = peer.title
        hidesBottomBarWhenPushed = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Профиль",
                                                            style: .plain,
                                                            target: self,
                                                            action: #selector(openPeerProfile))

        buildComposer()
        table.register(MessageCell.self, forCellReuseIdentifier: MessageCell.reuseId)
        registerKeyboard()

        longPoll.onUpdate = { [weak self] in
            self?.loadHistory(silent: true)
        }

        load()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        longPoll.start(peerId: peer.id)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        longPoll.stop()
    }

    deinit {
        longPoll.stop()
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Композер

    private func buildComposer() {
        composer.translatesAutoresizingMaskIntoConstraints = false
        composer.backgroundColor = Theme.composerBackground

        let separator = UIView()
        separator.backgroundColor = Theme.composerBorder
        separator.translatesAutoresizingMaskIntoConstraints = false

        input.translatesAutoresizingMaskIntoConstraints = false
        input.font = UIFont.systemFont(ofSize: 16)
        input.textColor = Theme.textPrimary
        input.backgroundColor = .clear
        input.isScrollEnabled = true
        input.delegate = self
        input.layer.borderWidth = 1
        input.layer.borderColor = Theme.composerBorder.cgColor

        sendButton.setTitle("Отправить", for: .normal)
        sendButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        sendButton.isEnabled = false
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)

        view.addSubview(composer)
        composer.addSubview(separator)
        composer.addSubview(input)
        composer.addSubview(placeholderLabel)
        composer.addSubview(sendButton)

        composerBottom = composer.bottomAnchor.constraint(equalTo: view.bottomAnchor)

        NSLayoutConstraint.activate([
            composerBottom,
            composer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composer.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),

            separator.topAnchor.constraint(equalTo: composer.topAnchor),
            separator.leadingAnchor.constraint(equalTo: composer.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: composer.trailingAnchor),
            separator.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            input.leadingAnchor.constraint(equalTo: composer.leadingAnchor, constant: 10),
            input.topAnchor.constraint(equalTo: composer.topAnchor, constant: 8),
            input.bottomAnchor.constraint(equalTo: composer.bottomAnchor, constant: -8),
            input.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            input.heightAnchor.constraint(lessThanOrEqualToConstant: 120),

            placeholderLabel.leadingAnchor.constraint(equalTo: input.leadingAnchor, constant: 9),
            placeholderLabel.topAnchor.constraint(equalTo: input.topAnchor, constant: 8),

            sendButton.leadingAnchor.constraint(equalTo: input.trailingAnchor, constant: 10),
            sendButton.trailingAnchor.constraint(equalTo: composer.trailingAnchor, constant: -12),
            sendButton.bottomAnchor.constraint(equalTo: composer.bottomAnchor, constant: -12)
        ])

        pinTableBottom(to: composer.topAnchor)
        table.separatorInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    }

    private func registerKeyboard() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChange),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
    }

    @objc private func keyboardWillChange(_ note: Notification) {
        guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let converted = view.convert(frame, from: nil)
        let overlap = max(0, view.bounds.maxY - converted.minY)
        composerBottom.constant = -overlap

        let duration = (note.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        UIView.animate(withDuration: duration) {
            self.view.layoutIfNeeded()
        }
        scrollToBottom(animated: false)
    }

    // MARK: - Данные

    override func load() {
        loadHistory(silent: false)
    }

    private func loadHistory(silent: Bool) {
        if silent == false {
            setLoading(messages.isEmpty)
        }

        VKApiClient.shared.call("messages.getHistory", ["peer_id": String(peer.id), "count": "50"]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.setLoading(false)
                switch result {
                case .success(let value):
                    let fresh = VKMessage.readList(value).sorted { $0.date < $1.date }
                    self.messages = fresh
                    self.showStatus(fresh.isEmpty ? "Сообщений пока нет" : nil)
                    self.reload()
                    self.scrollToBottom(animated: true)
                case .failure(let error):
                    if silent == false {
                        self.showError(error)
                    }
                }
            }
        }
    }

    @objc private func sendTapped() {
        let text = (input.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }

        input.text = nil
        textViewDidChange(input)
        sendButton.isEnabled = false

        let random = String(arc4random_uniform(UInt32.random(in: 1...UInt32(Int.max))))
        VKApiClient.shared.call("messages.send", ["peer_id": String(peer.id),
                                                  "message": text,
                                                  "random_id": random]) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.sendButton.isEnabled = true
                switch result {
                case .success:
                    self.loadHistory(silent: true)
                case .failure(let error):
                    self.input.text = text
                    self.textViewDidChange(self.input)
                    self.presentAlert(title: "Не отправлено", message: error.message)
                }
            }
        }
    }

    @objc private func openPeerProfile() {
        if peer.isGroup,
            let group = VKGroup(dict: ["id": abs(peer.id),
                                       "name": peer.title,
                                       "photo_200": peer.photoURL]) {
            Navigator.openGroup(group, in: self)
            return
        }
        Navigator.openUser(id: abs(peer.id), in: self)
    }

    // MARK: - Таблица

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = table.dequeueReusableCell(withIdentifier: MessageCell.reuseId, for: indexPath) as! MessageCell
        cell.configure(message: messages[indexPath.row])
        return cell
    }

    private func scrollToBottom(animated: Bool) {
        guard messages.isEmpty == false else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        guard table.numberOfRows(inSection: 0) > indexPath.row else { return }
        table.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }

    override func reload() {
        table.reloadData()
    }

    // MARK: - UITextViewDelegate

    func textViewDidChange(_ textView: UITextView) {
        placeholderLabel.isHidden = (textView.text?.isEmpty == false)
        sendButton.isEnabled = (textView.text?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    override func applyTheme() {
        super.applyTheme()
        composer.backgroundColor = Theme.composerBackground
        input.textColor = Theme.textPrimary
        input.layer.borderColor = Theme.composerBorder.cgColor
        placeholderLabel.textColor = Theme.textSecondary
    }
}