import UIKit

/// Настройки: тема, адрес инстанса, выход, сведения о приложении.
final class SettingsViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stack = UIStackView()

    private let themeSwitch = UISwitch()
    private let serverField = UIFactory.textField(placeholder: "https://api.openvk.org/method/")
    private let saveServerButton = UIButton(type: .system)
    private let logoutButton = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Настройки"
        Theme.decorate(self)
        setupScroll()
        buildContent()
        loadValues()
    }

    private func setupScroll() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: safe.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
    }

    private func buildContent() {

        // Тема
        let themeRow = makeRow(title: "Тёмная тема")
        themeRow.addSubview(themeSwitch)
        themeSwitch.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            themeSwitch.trailingAnchor.constraint(equalTo: themeRow.trailingAnchor, constant: -16),
            themeSwitch.centerYAnchor.constraint(equalTo: themeRow.centerYAnchor),
            themeRow.heightAnchor.constraint(greaterThanOrEqualToConstant: 52)
        ])
        themeSwitch.addTarget(self, action: #selector(themeChanged), for: .valueChanged)
        stack.addArrangedSubview(themeRow)
        stack.addArrangedSubview(makeSeparator())

        // Сервер
        stack.addArrangedSubview(makeSectionTitle("Адрес сервера OpenVK"))
        let serverRow = UIView()
        serverRow.backgroundColor = Theme.card
        serverField.addTarget(self, action: #selector(saveServer), for: .editingDidEnd)

        saveServerButton.setTitle("Сохранить", for: .normal)
        saveServerButton.setTitleColor(Theme.accent, for: .normal)
        saveServerButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        saveServerButton.addTarget(self, action: #selector(saveServer), for: .touchUpInside)
        saveServerButton.translatesAutoresizingMaskIntoConstraints = false

        serverRow.addSubview(serverField)
        serverRow.addSubview(saveServerButton)
        NSLayoutConstraint.activate([
            serverField.leadingAnchor.constraint(equalTo: serverRow.leadingAnchor, constant: 12),
            serverField.topAnchor.constraint(equalTo: serverRow.topAnchor, constant: 10),
            serverField.bottomAnchor.constraint(equalTo: serverRow.bottomAnchor, constant: -10),
            serverField.heightAnchor.constraint(equalToConstant: 44),

            saveServerButton.leadingAnchor.constraint(equalTo: serverField.trailingAnchor, constant: 10),
            saveServerButton.trailingAnchor.constraint(equalTo: serverRow.trailingAnchor, constant: -14),
            saveServerButton.centerYAnchor.constraint(equalTo: serverField.centerYAnchor)
        ])
        stack.addArrangedSubview(serverRow)
        stack.addArrangedSubview(makeSeparator())

        let hint = UIFactory.label("Токен и id хранятся в Keychain. После смены сервера выполните вход заново.",
                                   size: 12,
                                   color: Theme.textSecondary)
        hint.numberOfLines = 0
        let hintContainer = UIView()
        hintContainer.backgroundColor = Theme.background
        hintContainer.addSubview(hint)
        hint.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hint.leadingAnchor.constraint(equalTo: hintContainer.leadingAnchor, constant: 16),
            hint.trailingAnchor.constraint(equalTo: hintContainer.trailingAnchor, constant: -16),
            hint.topAnchor.constraint(equalTo: hintContainer.topAnchor, constant: 10),
            hint.bottomAnchor.constraint(equalTo: hintContainer.bottomAnchor, constant: -10)
        ])
        stack.addArrangedSubview(hintContainer)
        stack.addArrangedSubview(makeSeparator(inset: 0))

        // Переходы к экранам, убранным из таб-бара ради лимита в 5 вкладок.
        stack.addArrangedSubview(makeSectionTitle("Разделы"))
        stack.addArrangedSubview(makeNavigationRow(title: "Друзья", glyph: "☺",
                                                   action: #selector(openFriends)))
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeNavigationRow(title: "Группы", glyph: "☷",
                                                   action: #selector(openGroups)))
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeNavigationRow(title: "Музыка", glyph: "♪",
                                                   action: #selector(openMusic)))
        stack.addArrangedSubview(makeSeparator(inset: 0))

        // Выход
        logoutButton.setTitle("Выйти из аккаунта", for: .normal)
        logoutButton.setTitleColor(Theme.logout, for: .normal)
        logoutButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        logoutButton.addTarget(self, action: #selector(logout), for: .touchUpInside)
        let logoutRow = makeRow(title: nil)
        logoutRow.addSubview(logoutButton)
        logoutButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logoutButton.leadingAnchor.constraint(equalTo: logoutRow.leadingAnchor, constant: 16),
            logoutButton.topAnchor.constraint(equalTo: logoutRow.topAnchor, constant: 14),
            logoutButton.bottomAnchor.constraint(equalTo: logoutRow.bottomAnchor, constant: -14)
        ])
        stack.addArrangedSubview(logoutRow)
        stack.addArrangedSubview(makeSeparator())

        // О приложении
        stack.addArrangedSubview(makeSectionTitle("О приложении"))
        let about = UIFactory.label("\(VKConstants.bundleName) — клиент социальной сети OpenVK.\n"
                                    + "API: \(LocalSettings.shared.instanceBaseURL)\n"
                                    + "Версия API: \(VKConstants.apiVersion)\n"
                                    + "Идентификатор клиента: \(VKConstants.clientID)\n"
                                    + "Минимальная версия iOS: 12.0 (только 64-битные устройства)",
                                    size: 13,
                                    color: Theme.textSecondary)
        about.numberOfLines = 0
        let aboutContainer = UIView()
        aboutContainer.backgroundColor = Theme.card
        aboutContainer.addSubview(about)
        about.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            about.leadingAnchor.constraint(equalTo: aboutContainer.leadingAnchor, constant: 16),
            about.trailingAnchor.constraint(equalTo: aboutContainer.trailingAnchor, constant: -16),
            about.topAnchor.constraint(equalTo: aboutContainer.topAnchor, constant: 12),
            about.bottomAnchor.constraint(equalTo: aboutContainer.bottomAnchor, constant: -12)
        ])
        stack.addArrangedSubview(aboutContainer)
    }

    private func loadValues() {
        themeSwitch.isOn = LocalSettings.shared.isDarkTheme
        serverField.text = LocalSettings.shared.instanceBaseURL
    }

    // MARK: - Элементы

    /// Строка-переход к экрану, который не поместился в таб-бар.
    private func makeNavigationRow(title: String, glyph: String, action: Selector) -> UIView {
        let row = makeRow(title: nil)
        let button = UIButton(type: .system)
        button.setTitle(" \(glyph)   \(title)", for: .normal)
        button.setTitleColor(Theme.textPrimary, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.contentHorizontalAlignment = .left
        button.addTarget(self, action: action, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            button.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            button.topAnchor.constraint(equalTo: row.topAnchor),
            button.bottomAnchor.constraint(equalTo: row.bottomAnchor),
            row.heightAnchor.constraint(equalToConstant: 52)
        ])
        return row
    }

    private func makeRow(title: String?) -> UIView {
        let row = UIView()
        row.backgroundColor = Theme.card
        if let title = title {
            let label = UIFactory.label(title, size: 16)
            label.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
                label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
                label.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
                row.heightAnchor.constraint(equalToConstant: 52)
            ])
        }
        return row
    }

    private func makeSectionTitle(_ text: String) -> UIView {
        let label = UIFactory.label(text.uppercased(), size: 12, weight: .semibold, color: Theme.textSecondary)
        label.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView()
        container.backgroundColor = Theme.background
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            label.topAnchor.constraint(equalTo: container.topAnchor, constant: 16),
            label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -6)
        ])
        return container
    }

    private func makeSeparator(inset: CGFloat = 72) -> UIView {
        let line = UIView()
        line.backgroundColor = Theme.divider
        line.translatesAutoresizingMaskIntoConstraints = false
        let container = UIView()
        container.backgroundColor = Theme.card
        container.addSubview(line)
        NSLayoutConstraint.activate([
            line.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: inset),
            line.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            line.topAnchor.constraint(equalTo: container.topAnchor),
            line.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            line.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale)
        ])
        return container
    }

    // MARK: - Действия

    @objc private func themeChanged() {
        LocalSettings.shared.isDarkTheme = themeSwitch.isOn
        Theme.applyGlobalAppearance()

        stack.arrangedSubviews.forEach {
            stack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        buildContent()
        loadValues()
        Theme.reloadAppearance()
    }

    @objc private func saveServer() {
        view.endEditing(true)
        let value = (serverField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else {
            serverField.text = LocalSettings.shared.instanceBaseURL
            return
        }
        LocalSettings.shared.instanceBaseURL = value
        let alert = UIAlertController(title: "Сохранено",
                                      message: "Сервер изменён на \(value). Выполните вход заново.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "ОК", style: .default) { _ in
            AppDelegate.shared.signOut()
        })
        present(alert, animated: true, completion: nil)
    }

    /// Обёртка раздела в навигационный контроллер с теми же стилями, что у вкладок.
    private func push(_ controller: UIViewController, title: String) {
        controller.title = title
        let navigation = UINavigationController(rootViewController: controller)
        navigation.navigationBar.isTranslucent = false
        Theme.styleNavigationBar(navigation.navigationBar)
        navigationController?.pushViewController(navigation, animated: true)
    }

    @objc private func openFriends() {
        push(FriendsViewController(), title: "Друзья")
    }

    @objc private func openGroups() {
        push(GroupsViewController(), title: "Группы")
    }

    @objc private func openMusic() {
        push(MusicViewController(), title: "Музыка")
    }

    @objc private func logout() {
        let alert = UIAlertController(title: "Выйти?",
                                      message: "Токен будет удалён из Keychain.",
                                      preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Выйти", style: .destructive) { _ in
            AppDelegate.shared.signOut()
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = logoutButton
            popover.sourceRect = logoutButton.bounds
        }
        present(alert, animated: true, completion: nil)
    }
}