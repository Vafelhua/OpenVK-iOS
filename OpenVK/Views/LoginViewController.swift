import UIKit

/// Экран входа по логину/паролю (grant_type=password).
final class LoginViewController: UIViewController, UITextFieldDelegate {
    private let logoView = UILabel()
    private let captionLabel = UIFactory.label("OpenVK", size: 30, weight: .bold)
    private let subtitleLabel = UIFactory.label("Клиент социальной сети OpenVK",
                                                size: 14,
                                                color: Theme.textSecondary)
    private let loginField = UIFactory.textField(placeholder: "Логин или e-mail")
    private let passwordField = UIFactory.textField(placeholder: "Пароль", secure: true)
    private let errorLabel = UIFactory.label("", size: 14, color: Theme.error)
    private let loginButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .gray)
    private let serverButton = UIFactory.flatButton("", color: Theme.textSecondary)

    private var isBusy = false {
        didSet {
            loginButton.isEnabled = isBusy == false
            loginButton.alpha = isBusy ? 0.5 : 1
            isBusy ? spinner.startAnimating() : spinner.stopAnimating()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        Theme.decorate(self)

        logoView.text = "OpenVK"
        logoView.font = UIFont.systemFont(ofSize: 54, weight: .bold)
        logoView.textColor = Theme.accent
        logoView.textAlignment = .center

        loginButton.setTitle("Войти", for: .normal)
        loginButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        loginButton.backgroundColor = Theme.accent
        loginButton.setTitleColor(.white, for: .normal)
        loginButton.addTarget(self, action: #selector(loginTapped), for: .touchUpInside)

        spinner.hidesWhenStopped = true

        loginField.delegate = self
        passwordField.delegate = self
        loginField.returnKeyType = .next
        passwordField.returnKeyType = .go
        loginField.autocapitalizationType = .none
        loginField.autocorrectionType = .no

        serverButton.titleLabel?.font = UIFont.systemFont(ofSize: 13)
        serverButton.addTarget(self, action: #selector(serverTapped), for: .touchUpInside)
        updateServerTitle()

        let stack = UIStackView(arrangedSubviews: [
            logoView, captionLabel, subtitleLabel, loginField, passwordField, errorLabel, loginButton
        ])
        stack.axis = .vertical
        stack.spacing = 14
        stack.setCustomSpacing(24, after: subtitleLabel)
        stack.setCustomSpacing(6, after: errorLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(stack)
        view.addSubview(spinner)
        view.addSubview(serverButton)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: safe.centerYAnchor, constant: -20),
            stack.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -32),

            logoView.heightAnchor.constraint(equalToConstant: 64),
            captionLabel.heightAnchor.constraint(equalToConstant: 34),
            loginField.heightAnchor.constraint(equalToConstant: 48),
            passwordField.heightAnchor.constraint(equalToConstant: 48),
            loginButton.heightAnchor.constraint(equalToConstant: 50),

            spinner.centerXAnchor.constraint(equalTo: loginButton.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: loginButton.centerYAnchor),

            serverButton.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            serverButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            serverButton.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -16)
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if loginField.text?.isEmpty != false { loginField.becomeFirstResponder() }
    }

    // MARK: - Действия

    @objc private func loginTapped() {
        view.endEditing(true)
        let login = (loginField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let password = passwordField.text ?? ""

        guard login.isEmpty == false else { return showError("Введите логин или e-mail") }
        guard password.isEmpty == false else { return showError("Введите пароль") }

        errorLabel.text = nil
        isBusy = true

        AuthService.login(username: login, password: password) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isBusy = false
                switch result {
                case .success:
                    AppDelegate.shared.signIn()
                case .failure(let error):
                    self.showError(error.message)
                }
            }
        }
    }

    @objc private func serverTapped() {
        let alert = UIAlertController(title: "Адрес сервера",
                                      message: "Например: https://api.openvk.org/method/",
                                      preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "https://api.openvk.org/method/"
            field.text = LocalSettings.shared.instanceBaseURL
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
            field.keyboardType = .URL
        }
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Сохранить", style: .default) { [weak self] _ in
            let value = (alert.textFields?.first?.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard value.isEmpty == false else { return }
            LocalSettings.shared.instanceBaseURL = value
            self?.updateServerTitle()
        })
        present(alert, animated: true)
    }

    private func updateServerTitle() {
        let host = URL(string: LocalSettings.shared.instanceBaseURL)?.host ?? LocalSettings.shared.instanceBaseURL
        serverButton.setTitle("Сервер: \(host)", for: .normal)
    }

    private func showError(_ message: String) {
        errorLabel.text = message
        UIView.animate(withDuration: 0.2) {
            self.errorLabel.alpha = 1
        }
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === loginField {
            passwordField.becomeFirstResponder()
        } else {
            loginTapped()
        }
        return true
    }
}