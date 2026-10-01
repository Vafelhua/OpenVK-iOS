import UIKit

/// Базовый экран со списком: UITableView, индикатор загрузки, статус-строка,
/// pull-to-refresh и подписка на смену темы. Наследники переопределяют
/// `load()` / `reload()` / методы таблицы.
class TableScreenController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    let table = UITableView(frame: .zero, style: .plain)
    let refreshControl = UIRefreshControl()

    private let spinner = UIActivityIndicatorView(style: .gray)
    private let statusLabel = UILabel()

    /// Якорные ограничения таблицы — наследники переставляют их,
    /// если снизу/сверху появляется свой постоянный элемент (композер, шапка).
    private(set) var tableTopConstraint: NSLayoutConstraint!
    private(set) var tableBottomConstraint: NSLayoutConstraint!

    private(set) var isLoading = false

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

        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true

        view.addSubview(table)
        view.addSubview(statusLabel)
        view.addSubview(spinner)

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

    func showStatus(_ text: String?, isError: Bool = false) {
        statusLabel.text = text
        statusLabel.textColor = isError ? Theme.error : Theme.textSecondary
        statusLabel.isHidden = (text?.isEmpty ?? true)
    }

    func showError(_ error: Error) {
        let vkError = error.asVKError
        if itemsCount == 0 {
            showStatus(vkError.message, isError: true)
        } else {
            present(UIFactory.alert(title: "Ошибка", message: vkError.message), animated: true)
        }
    }

    func presentAlert(title: String, message: String) {
        present(UIFactory.alert(title: title, message: message), animated: true)
    }

    @objc private func handleRefresh() {
        setLoading(false)
        load()
    }

    /// Загрузка данных (переопределяется).
    func load() {}

    /// Применение данных к UI (переопределяется).
    func reload() {}

    func applyTheme() {
        Theme.decorate(self)
        table.backgroundColor = Theme.background
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

    // MARK: - Заглушки таблицы (переопределяются наследниками)

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