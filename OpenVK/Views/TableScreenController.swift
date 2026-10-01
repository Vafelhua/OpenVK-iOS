import UIKit

/// Базовый экран со списком: UITableView, индикатор загрузки, статус-строка,
/// pull-to-refresh, догрузка следующих страниц и подписка на смену темы.
///
/// Наследники переопределяют `load()`, `reload()`, `loadMore()` и методы таблицы.
class TableScreenController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    let table = UITableView(frame: .zero, style: .plain)
    let refreshControl = UIRefreshControl()

    private let spinner = UIActivityIndicatorView(style: .gray)
    /// Элементы панели чата. Не private: ими пользуется ChatViewController.
    let scrollToBottomButton = UIButton(type: .system)
    let unreadBadge = UILabel()
    private var scrollToBottomBottom: NSLayoutConstraint!

    /// Счётчик сообщений, пришедших пока пользователь листал историю вверх.
    var unreadCount = 0
    /// Смещение пагинации истории.
    var historyOffset = 0
    /// Первая страница ещё не открывалась снизу.
    var isLoadingFirstPage = true
    private let statusLabel = UILabel()
    private let footerSpinner = UIActivityIndicatorView(style: .gray)

    /// Якорные ограничения таблицы — наследники переставляют их,
    /// если снизу/сверху появляется свой постоянный элемент (композер, шапка).
    private(set) var tableTopConstraint: NSLayoutConstraint!
    private(set) var tableBottomConstraint: NSLayoutConstraint!

    private(set) var isLoading = false

    /// Догружается ли уже следующая страница (чтобы не слать запросы пачками).
    private(set) var isLoadingMore = false

    /// Включает догрузку следующих страниц. Экраны с пагинацией ставят
    /// `paginationEnabled = true` в своём `viewDidLoad`.
    var paginationEnabled = false

    // MARK: - Жизненный цикл

    override func viewDidLoad() {
        super.viewDidLoad()
        Theme.decorate(self)

        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 76
        table.separatorInset = UIEdgeInsets(top: 0, left: 64, bottom: 0, right: 0)
        table.tableFooterView = UIView()
        table.backgroundColor = Theme.background
        table.register(MemberCell.self, forCellReuseIdentifier: MemberCell.reuseId)
        table.register(ConversationCell.self, forCellReuseIdentifier: ConversationCell.reuseId)
        table.register(PostCell.self, forCellReuseIdentifier: PostCell.reuseId)
        refreshControl.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        table.refreshControl = refreshControl

        statusLabel.font = UIFont.systemFont(ofSize: 15)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 0
        statusLabel.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.isUserInteractionEnabled = true
        statusLabel.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(statusTapped)))

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true

        footerSpinner.translatesAutoresizingMaskIntoConstraints = false
        footerSpinner.hidesWhenStopped = true
        footerSpinner.frame = CGRect(x: 0, y: 0, width: 0, height: 44)

        // Кнопка «вниз» и счётчик непрочитанных: нужны только экрану чата,
        // но строятся здесь, чтобы переиспользовать таблицу и её safe area.
        scrollToBottomButton.setImage(UIFactory.icon("↓", size: 20), for: .normal)
        scrollToBottomButton.backgroundColor = Theme.card
        scrollToBottomButton.tintColor = Theme.accent
        scrollToBottomButton.layer.cornerRadius = 20
        scrollToBottomButton.layer.shadowOpacity = 0.15
        scrollToBottomButton.layer.shadowRadius = 4
        scrollToBottomButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        scrollToBottomButton.isHidden = true
        scrollToBottomButton.addTarget(self, action: #selector(scrollToBottomTapped), for: .touchUpInside)
        scrollToBottomButton.translatesAutoresizingMaskIntoConstraints = false

        unreadBadge.textAlignment = .center
        unreadBadge.backgroundColor = Theme.accent
        unreadBadge.textColor = .white
        unreadBadge.font = UIFont.systemFont(ofSize: 11, weight: .bold)
        unreadBadge.layer.cornerRadius = 9
        unreadBadge.clipsToBounds = true
        unreadBadge.isHidden = true
        unreadBadge.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(table)
        view.addSubview(statusLabel)
        view.addSubview(spinner)
        view.addSubview(scrollToBottomButton)
        view.addSubview(unreadBadge)

        let safe = view.safeAreaLayoutGuide
        tableTopConstraint = table.topAnchor.constraint(equalTo: safe.topAnchor)
        tableBottomConstraint = table.bottomAnchor.constraint(equalTo: safe.bottomAnchor)

        NSLayoutConstraint.activate([
            tableTopConstraint,
            table.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableBottomConstraint,

            statusLabel.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: safe.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            statusLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),

            spinner.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: safe.centerYAnchor)
        ])

        scrollToBottomBottom = scrollToBottomButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12)
        NSLayoutConstraint.activate([
            scrollToBottomBottom,
            scrollToBottomButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            scrollToBottomButton.widthAnchor.constraint(equalToConstant: 40),
            scrollToBottomButton.heightAnchor.constraint(equalToConstant: 40),

            unreadBadge.centerXAnchor.constraint(equalTo: scrollToBottomButton.centerXAnchor),
            unreadBadge.centerYAnchor.constraint(equalTo: scrollToBottomButton.topAnchor),
            unreadBadge.heightAnchor.constraint(equalToConstant: 18),
            unreadBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 18)
        ])

        applyTheme()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(themeDidChange),
                                               name: .openVKThemeDidChange,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Состояние экрана

    /// Количество элементов — нужно, чтобы решать: показывать ошибку внутри
    /// списка или показывать alert поверх уже загруженных данных.
    var itemsCount: Int { return 0 }

    func setLoading(_ value: Bool) {
        isLoading = value
        if value {
            showStatus(nil)
            spinner.startAnimating()
        } else {
            spinner.stopAnimating()
            refreshControl.endRefreshing()
        }
    }

    /// Показать/скрыть индикатор догрузки в подвале таблицы.
    func setLoadingMore(_ value: Bool) {
        isLoadingMore = value
        if value {
            footerSpinner.startAnimating()
            table.tableFooterView = footerSpinner
        } else {
            footerSpinner.stopAnimating()
            table.tableFooterView = UIView()
        }
    }

    /// `true`, когда список пуст и повторять загрузку имеет смысл.
    private var statusIsError = false

    func showStatus(_ text: String?, isError: Bool = false) {
        statusLabel.text = text
        statusLabel.textColor = isError ? Theme.error : Theme.textSecondary
        statusLabel.isHidden = (text?.isEmpty ?? true)
        statusIsError = isError
        // Подсказка «нажмите, чтобы повторить» показывается только при ошибке.
        if isError, let text = text, text.isEmpty == false {
            statusLabel.attributedText = nil
            statusLabel.text = text + "\n\nНажмите, чтобы повторить"
        }
    }

    func showError(_ error: Error) {
        let vkError = error.asVKError
        if itemsCount == 0 {
            showStatus(vkError.message, isError: true)
        } else {
            present(UIFactory.alert(title: "Ошибка", message: vkError.message), animated: true)
        }
    }

    @objc private func statusTapped() {
        guard statusIsError else { return }
        load()
    }

    @objc private func scrollToBottomTapped() {
        scrollToBottom(animated: true)
    }

    /// Прокрутка к последней строке. Базовая реализация не знает про чат,
    /// поэтому проверки «пользователь уже внизу» живут в ChatViewController.
    func scrollToBottom(animated: Bool) {
        guard table.numberOfRows(inSection: 0) > 0 else { return }
        let last = IndexPath(row: table.numberOfRows(inSection: 0) - 1, section: 0)
        table.scrollToRow(at: last, at: .bottom, animated: animated)
    }

    /// Сброс смещения пагинации при полной перезагрузке экрана.
    func resetPagination() {
        historyOffset = 0
        isLoadingFirstPage = true
        unreadCount = 0
    }

    @objc private func handleRefresh() {
        setLoading(false)
        load()
    }

    /// Загрузка данных (переопределяется).
    func load() {}

    /// Догрузка следующей страницы (переопределяется для пагинации).
    func loadMore() {}

    /// Применение данных к UI (переопределяется).
    func reload() {}

    func applyTheme() {
        Theme.decorate(self)
        table.backgroundColor = Theme.background
        statusLabel.textColor = statusIsError ? Theme.error : Theme.textSecondary
        spinner.color = Theme.textSecondary
        footerSpinner.color = Theme.textSecondary
        reload()
    }

    /// Переносит верх таблицы (например, под шапку профиля).
    func pinTableTop(to anchor: NSLayoutYAxisAnchor, constant: CGFloat = 0) {
        tableTopConstraint.isActive = false
        tableTopConstraint = table.topAnchor.constraint(equalTo: anchor, constant: constant)
        tableTopConstraint.isActive = true
    }

    /// Переносит низ таблицы (например, над композером в чате/профиле).
    func pinTableBottom(to anchor: NSLayoutYAxisAnchor, constant: CGFloat = 0) {
        tableBottomConstraint.isActive = false
        tableBottomConstraint = table.bottomAnchor.constraint(equalTo: anchor, constant: constant)
        tableBottomConstraint.isActive = true
    }

    @objc private func themeDidChange() {
        applyTheme()
    }

    // MARK: - Пагинация

    /// Доливает следующую страницу, когда пользователь долистал до конца.
    func tableView(_ tableView: UITableView,
                   willDisplay cell: UITableViewCell,
                   forRowAt indexPath: IndexPath) {
        guard paginationEnabled, isLoading == false, isLoadingMore == false else { return }
        let total = numberOfLoadedItems()
        guard total > 0 else { return }
        // Порог в 4 строки от края: срабатывает заранее, чтобы ленты не «дёргались».
        if indexPath.row >= total - 4 {
            loadMore()
            // Подвал со спиннером увеличивает contentSize, поэтому таблицу
            // нужно пересчитать — иначе willDisplay больше не придёт.
            table.layoutIfNeeded()
        }
    }

    /// Сколько всего строк в модели. Для экранов с секциями считаем сумму.
    func numberOfLoadedItems() -> Int {
        let sections = max(1, tableView(table, numberOfSections: 0))
        var total = 0
        for section in 0..<sections {
            total += tableView(table, numberOfRowsInSection: section)
        }
        return total
    }

    // MARK: - Заглушки таблицы (переопределяются наследниками)

    func tableView(_ tableView: UITableView, numberOfSections section: Int) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return UITableViewCell()
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {}
}

extension Array where Element: AnyObject {
    /// Индекс элемента по идентичности — для моделей, не наследующих Equatable.
    func identityIndex(of object: Element) -> Int? {
        return firstIndex(where: { $0 === object })
    }
}

extension UIViewController {
    /// Показать модальный алерт с заголовком и текстом.
    func presentAlert(title: String, message: String) {
        present(UIFactory.alert(title: title, message: message), animated: true)
    }
}