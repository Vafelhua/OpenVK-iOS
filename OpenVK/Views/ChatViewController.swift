import UIKit

/// Экран переписки: история сообщений, Long Poll (с откатом на опрос), отправка.
final class ChatViewController: TableScreenController, UITextViewDelegate {
    private let peer: VKPeer
    private var messages: [VKMessage] = []
    /// Запрос истории уже в полёте — второй ответ перетирал бы первый.
    private var isFetchingHistory = false
    /// Старая история закончилась (сервер вернул пустую страницу).
    private var reachedHistoryEnd = false

    private let composer = UIView()
    private let input = UITextView()
    private let sendButton = UIButton(type: .system)
    private let placeholderLabel = UIFactory.label("Сообщение…", size: 15, color: Theme.textSecondary)
    private var composerBottom: NSLayoutConstraint!
    private let longPoll = LongPollClient()

    /// Строка чата: либо сообщение, либо разделитель дат.
    private enum ChatItem {
        case date(String)
        case message(VKMessage)
    }
    private var displayItems: [ChatItem] = []

    private static let dayInYearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter
    }()

    private static let dayFullFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter
    }()

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
        table.register(DateSeparatorCell.self, forCellReuseIdentifier: DateSeparatorCell.reuseId)
        registerKeyboard()
        table.keyboardDismissMode = .interactive

        // Приход нового сообщения не должен прокручивать чат вниз,
        // если пользователь читает историю выше.
        longPoll.onUpdate = { [weak self] in
            guard let self = self else { return }
            self.loadHistory(silent: true)
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
        // Поля отступов прижимают поле ввода и кнопку к safe area:
        // на iPhone с home indicator они больше не уезжают под системную полосу.
        composer.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0,
                                                                      leading: 12,
                                                                      bottom: 0,
                                                                      trailing: 12)

        let separator = UIView()
        separator.backgroundColor = Theme.composerBorder
        separator.translatesAutoresizingMaskIntoConstraints = false

        input.translatesAutoresizingMaskIntoConstraints = false
        input.font = UIFont.systemFont(ofSize: 16)
        input.textColor = Theme.textPrimary
        input.backgroundColor = Theme.card
        input.isScrollEnabled = true
        input.delegate = self
        input.layer.cornerRadius = Theme.isVK56 ? 2 : 18
        input.layer.borderWidth = Theme.cardBorderWidth
        input.layer.borderColor = Theme.border.cgColor
        input.layer.masksToBounds = true

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

            input.leadingAnchor.constraint(equalTo: composer.layoutMarginsGuide.leadingAnchor),
            input.topAnchor.constraint(equalTo: composer.topAnchor, constant: 8),
            input.bottomAnchor.constraint(equalTo: composer.bottomAnchor, constant: -8),
            input.heightAnchor.constraint(greaterThanOrEqualToConstant: 36),
            input.heightAnchor.constraint(lessThanOrEqualToConstant: 120),

            placeholderLabel.leadingAnchor.constraint(equalTo: input.leadingAnchor, constant: 12),
            placeholderLabel.topAnchor.constraint(equalTo: input.topAnchor, constant: 8),

            sendButton.leadingAnchor.constraint(equalTo: input.trailingAnchor, constant: 10),
            sendButton.trailingAnchor.constraint(equalTo: composer.layoutMarginsGuide.trailingAnchor),
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
        // Явная перезагрузка (pull-to-refresh, retry) начинает историю заново,
        // иначе offset продолжил бы догружать старую страницу.
        resetPagination()
        reachedHistoryEnd = false
        messages = []
        rebuildDisplayItems()
        reload()
        loadHistory(silent: false)
    }

    private func loadHistory(silent: Bool, older: Bool = false) {
        if silent == false {
            setLoading(messages.isEmpty)
        }
        // Параллельные ответы getHistory перетирали друг друга: держим
        // один запрос за раз, остальные пропускаем.
        guard isFetchingHistory == false else {
            if older { setLoadingMore(false) }
            return
        }
        isFetchingHistory = true

        // offset — догрузка старых сообщений при прокрутке вверх.
        var parameters = ["peer_id": String(peer.id), "count": "50"]
        if historyOffset > 0 {
            parameters["offset"] = String(historyOffset)
        }

        VKApiClient.shared.call("messages.getHistory", parameters) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isFetchingHistory = false
                self.setLoading(false)
                switch result {
                case .success(let value):
                    var fresh = VKMessage.readList(value).sorted { $0.date < $1.date }
                    // Не выкидываем то, что уже показано: сервер отдаёт
                    // пересекающиеся страницы при быстрых отправках.
                    let known = Set(self.messages.map { $0.id })
                    let existing = self.messages
                    fresh = fresh.filter { known.contains($0.id) == false }
                    guard fresh.isEmpty == false else {
                        // Ответ пришёл целиком из уже загруженных сообщений:
                        // это обычное состояние при Long Poll, не ошибка.
                        if older { self.reachedHistoryEnd = true }
                        self.setLoadingMore(false)
                        self.updateScrollToBottomButton()
                        return
                    }
                    self.messages = existing + fresh
                    // Смещение двигает только догрузка вверх: иначе новые
                    // сообщения из Long Poll «съедали» бы по одному из выборки.
                    if older { self.historyOffset += fresh.count }
                    self.rebuildDisplayItems()
                    self.showStatus(self.messages.isEmpty ? "Сообщений пока нет" : nil)
                    self.reload()
                    if self.isLoadingFirstPage {
                        // Первая страница всегда открывается снизу.
                        self.scrollToBottom(animated: silent == false)
                        self.isLoadingFirstPage = false
                    } else if older {
                        // Догруженная история не должна прокручивать чат вниз.
                        self.preserveVisiblePosition(inserted: fresh.count)
                    } else if self.isScrolledToBottom() {
                        // Пользователь внизу — новое сообщение должно быть видно.
                        self.scrollToBottom(animated: true)
                    }
                    self.updateScrollToBottomButton()
                case .failure(let error):
                    // Спиннер догрузки нужно снять всегда, иначе он залипает.
                    self.setLoadingMore(false)
                    if silent == false {
                        self.showError(error)
                    }
                }
            }
        }
    }

    private func loadOlderMessages() {
        guard isLoadingMore == false, isLoading == false, hasMoreHistory else { return }
        setLoadingMore(true)
        loadHistory(silent: true, older: true)
    }

    private var hasMoreHistory: Bool {
        return historyOffset > 0 && messages.count >= 10 && reachedHistoryEnd == false
    }

    /// Догруженная история добавляется сверху: держим тот же контент перед глазами.
    private func preserveVisiblePosition(inserted count: Int) {
        guard count > 0 else { return }
        let previousHeight = table.contentSize.height
        let previousOffset = table.contentOffset
        table.layoutIfNeeded()
        let delta = table.contentSize.height - previousHeight
        guard delta > 0 else { return }
        table.setContentOffset(CGPoint(x: previousOffset.x, y: previousOffset.y + delta), animated: false)
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

    /// Пересобирает список с разделителями дней перед группами сообщений.
    private func rebuildDisplayItems() {
        var items: [ChatItem] = []
        var currentDay: TimeInterval?
        let calendar = Calendar.current
        for message in messages {
            let date = Date(timeIntervalSince1970: TimeInterval(message.date))
            let dayKey = calendar.startOfDay(for: date).timeIntervalSince1970
            if dayKey != currentDay {
                items.append(.date(dayText(for: date)))
                currentDay = dayKey
            }
            items.append(.message(message))
        }
        displayItems = items
    }

    private func dayText(for date: Date) -> String {
        if TimeHelper.isToday(date) { return "Сегодня" }
        if TimeHelper.isYesterday(date) { return "Вчера" }
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .year)
            ? ChatViewController.dayInYearFormatter.string(from: date)
            : ChatViewController.dayFullFormatter.string(from: date)
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return displayItems.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch displayItems[safe: indexPath.row] {
        case .date(let text)?:
            guard let cell = dequeueCell(DateSeparatorCell.self,
                                         identifier: DateSeparatorCell.reuseId,
                                         at: indexPath) else { return UITableViewCell() }
            cell.configure(text)
            cell.applyTheme()
            return cell
        case .message(let message)?:
            guard let cell = dequeueCell(MessageCell.self,
                                         identifier: MessageCell.reuseId,
                                         at: indexPath) else { return UITableViewCell() }
            cell.configure(message: message)
            return cell
        case .none:
            return UITableViewCell()
        }
    }

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        // Догружаем историю, когда пользователь доскроллил до верха.
        if indexPath.row == 0 { loadOlderMessages() }
        super.tableView(tableView, willDisplay: cell, forRowAt: indexPath)
    }

    /// Кнопка «вниз» нужна, когда пользователь читает историю выше дна.
    private func updateScrollToBottomButton() {
        let isAtBottom = isScrolledToBottom()
        scrollToBottomButton.isHidden = isAtBottom
        if isAtBottom {
            unreadBadge.isHidden = true
            unreadCount = 0
        } else {
            unreadBadge.isHidden = unreadCount == 0
            unreadBadge.text = " \(unreadCount) "
        }
    }

    /// Пользователь внизу чата? От этого зависит, прокручивать ли новые
    /// сообщения — иначе чат выкидывал на середину истории.
    private func isScrolledToBottom() -> Bool {
        guard table.numberOfSections > 0, table.numberOfRows(inSection: 0) > 0 else { return true }
        let visibleBottom = table.contentOffset.y + table.bounds.height - table.adjustedContentInset.bottom
        return visibleBottom >= table.contentSize.height - 80
    }

    override func reload() {
        table.reloadData()
        updateScrollToBottomButton()
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
        input.backgroundColor = Theme.card
        input.layer.cornerRadius = Theme.isVK56 ? 2 : 18
        input.layer.borderWidth = Theme.cardBorderWidth
        if Theme.cardBorderWidth > 0 { input.layer.borderColor = Theme.border.cgColor }
        placeholderLabel.textColor = Theme.textSecondary
        sendButton.setTitleColor(Theme.accent, for: .normal)
        sendButton.setTitleColor(Theme.textSecondary.withAlphaComponent(0.5), for: .disabled)
    }
}