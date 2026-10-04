import UIKit

/// Собственный профиль: шапка, стена, публикация записей с фото (и треком).
final class ProfileViewController: WallScreenController, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UITextViewDelegate {
    private var me: VKUser?

    private let composer = UIView()
    private let input = UITextView()
    private let placeholder = UIFactory.label("Что у вас нового?", size: 15, color: Theme.textSecondary)
    private let publishButton = UIButton(type: .system)
    private let photoButton = UIButton(type: .system)
    private let audioButton = UIButton(type: .system)
    private let previewStack = UIStackView()
    private let composeButton = UIButton(type: .system)
    private var composerBottom: NSLayoutConstraint!
    private var previewHeight: NSLayoutConstraint!
    private var isComposerVisible = true

    private var attachments: [String] = []
    private var pendingImages: [Data] = []
    private var pendingAudioTitle: String?

    override var wallOwnerId: Int { return LocalSettings.shared.userId }
    override var wallCount: String { return "10" }

    override func buildHeader() {
        title = "Профиль"
        let parts = addHeaderParts(avatarSize: 64)
        parts.title.text = "Моя страница"
        parts.subtitle.text = "id\(LocalSettings.shared.userId)"

        let infoItem = UIBarButtonItem(title: "Инфо", style: .plain, target: self, action: #selector(openInfo))
        navigationItem.rightBarButtonItems = [infoItem, navigationItem.rightBarButtonItem].compactMap { $0 }

        loadMe(into: parts)
        buildComposer()
    }

    @objc private func openInfo() {
        navigationController?.pushViewController(UserInfoViewController(userId: LocalSettings.shared.userId,
                                                                       name: me?.name ?? "Моя страница"),
                                                animated: true)
    }

    private func loadMe(into parts: HeaderParts) {
        VKApiClient.shared.call("users.get", ["user_ids": String(LocalSettings.shared.userId),
                                              "fields": "photo_50,photo_100,photo_200,status,online,counters"]) { [weak self] result in
            guard let self = self else { return }
            guard case .success(let value) = result else { return }
            let dict = J.items(value).first as? [String: Any] ?? J.dict(value) ?? [:]
            guard let user = VKUser(dict: dict) else { return }
            self.me = user
            DispatchQueue.main.async {
                parts.title.text = user.name
                parts.subtitle.text = user.subtitle
                parts.counters.text = user.countersText
                parts.avatar.setRemote(user.photoMax)
                self.addCover(user.photoMax)
                self.title = user.name
            }
        }
    }

    // MARK: - Композер

    private func buildComposer() {
        composer.translatesAutoresizingMaskIntoConstraints = false
        composer.backgroundColor = Theme.composerBackground

        let topLine = UIView()
        topLine.backgroundColor = Theme.divider
        topLine.translatesAutoresizingMaskIntoConstraints = false

        input.translatesAutoresizingMaskIntoConstraints = false
        input.font = UIFont.systemFont(ofSize: 16)
        input.textColor = Theme.textPrimary
        input.backgroundColor = Theme.card
        input.layer.cornerRadius = 12
        input.layer.masksToBounds = true
        input.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        input.isScrollEnabled = true
        input.delegate = self

        publishButton.setTitle("Опубликовать", for: .normal)
        publishButton.setTitleColor(Theme.accent, for: .normal)
        publishButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
        publishButton.addTarget(self, action: #selector(publishTapped), for: .touchUpInside)

        photoButton.setTitle("Фото", for: .normal)
        photoButton.setTitleColor(Theme.accent, for: .normal)
        photoButton.addTarget(self, action: #selector(attachPhoto), for: .touchUpInside)

        audioButton.setTitle("Трек", for: .normal)
        audioButton.setTitleColor(Theme.accent, for: .normal)
        audioButton.addTarget(self, action: #selector(attachAudio), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [photoButton, audioButton, publishButton])
        buttons.axis = .horizontal
        buttons.distribution = .equalSpacing
        buttons.translatesAutoresizingMaskIntoConstraints = false

        previewStack.axis = .horizontal
        previewStack.spacing = 8
        previewStack.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(composer)
        composer.addSubview(topLine)
        composer.addSubview(input)
        composer.addSubview(placeholder)
        composer.addSubview(previewStack)
        composer.addSubview(buttons)

        composerBottom = composer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        composer.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 0,
                                                                     leading: 12,
                                                                     bottom: 0,
                                                                     trailing: 12)
        previewHeight = previewStack.heightAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            composerBottom,
            composer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            composer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            composer.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 120),

            topLine.topAnchor.constraint(equalTo: composer.topAnchor),
            topLine.leadingAnchor.constraint(equalTo: composer.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: composer.trailingAnchor),
            topLine.heightAnchor.constraint(equalToConstant: 1 / UIScreen.main.scale),

            input.topAnchor.constraint(equalTo: composer.topAnchor, constant: 8),
            input.leadingAnchor.constraint(equalTo: composer.layoutMarginsGuide.leadingAnchor),
            input.trailingAnchor.constraint(equalTo: composer.layoutMarginsGuide.trailingAnchor),
            input.heightAnchor.constraint(greaterThanOrEqualToConstant: 40),
            input.heightAnchor.constraint(lessThanOrEqualToConstant: 120),

            placeholder.leadingAnchor.constraint(equalTo: input.leadingAnchor, constant: 8),
            placeholder.topAnchor.constraint(equalTo: input.topAnchor, constant: 8),

            previewStack.topAnchor.constraint(equalTo: input.bottomAnchor, constant: 6),
            previewStack.leadingAnchor.constraint(equalTo: composer.layoutMarginsGuide.leadingAnchor),
            previewStack.trailingAnchor.constraint(lessThanOrEqualTo: composer.layoutMarginsGuide.trailingAnchor),
            previewHeight,

            buttons.topAnchor.constraint(equalTo: previewStack.bottomAnchor, constant: 4),
            buttons.leadingAnchor.constraint(equalTo: composer.layoutMarginsGuide.leadingAnchor),
            buttons.trailingAnchor.constraint(equalTo: composer.layoutMarginsGuide.trailingAnchor),
            buttons.bottomAnchor.constraint(equalTo: composer.bottomAnchor, constant: -10),
            buttons.heightAnchor.constraint(equalToConstant: 30)
        ])

        pinTableBottom(to: composer.topAnchor)
        table.separatorInset = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)

        buildComposeButton()
        setComposerVisible(false, animated: false)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(keyboardWillChange),
                                               name: UIResponder.keyboardWillChangeFrameNotification,
                                               object: nil)
    }

    /// Круглая кнопка публикации вместо постоянной нижней строки.
    private func buildComposeButton() {
        composeButton.setImage(UIFactory.icon("✎", size: 24), for: .normal)
        composeButton.tintColor = .white
        composeButton.backgroundColor = Theme.accent
        // В стиле VK 6.56 кнопка почти прямоугольная, в современном — круглая.
        composeButton.layer.cornerRadius = Theme.isVK56 ? 4 : 28
        composeButton.layer.shadowOpacity = 0.2
        composeButton.layer.shadowRadius = 6
        composeButton.layer.shadowOffset = CGSize(width: 0, height: 3)
        composeButton.translatesAutoresizingMaskIntoConstraints = false
        composeButton.addTarget(self, action: #selector(toggleComposer), for: .touchUpInside)
        view.addSubview(composeButton)

        NSLayoutConstraint.activate([
            composeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            composeButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            composeButton.widthAnchor.constraint(equalToConstant: 56),
            composeButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    @objc private func toggleComposer() {
        setComposerVisible(isComposerVisible == false, animated: true)
    }

    private func setComposerVisible(_ visible: Bool, animated: Bool) {
        isComposerVisible = visible
        composer.isHidden = visible == false
        composeButton.isHidden = visible
        if visible {
            pinTableBottom(to: composer.topAnchor)
            composerBottom.constant = 0
            input.becomeFirstResponder()
        } else {
            input.resignFirstResponder()
            composerBottom.constant = 0
            pinTableBottom(to: view.safeAreaLayoutGuide.bottomAnchor)
        }
        if animated {
            UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
        } else {
            view.layoutIfNeeded()
        }
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

    // MARK: - Вложения

    @objc private func attachPhoto() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = self
        present(picker, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[.originalImage] as? UIImage else { return }
        guard let data = image.jpegData(compressionQuality: 0.8) else { return }
        // VK принимает не больше 10 вложений — дальше сервер всё равно откажет.
        guard pendingImages.count < 9 else {
            presentAlert(title: "Много фото", message: "К одной записи можно прикрепить не больше 10 фотографий.")
            return
        }

        pendingImages.append(data)
        previewStack.addArrangedSubview(makePreview(for: image))
        previewHeight.constant = 56
    }

    /// Миниатюра прикреплённого фото; тап убирает её из набора.
    private func makePreview(for image: UIImage) -> UIView {
        let view = RemoteImageView(cornerRadius: Theme.cardRadius)
        view.image = image
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: 56),
            view.heightAnchor.constraint(equalToConstant: 56)
        ])
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(previewTapped(_:))))
        return view
    }

    @objc private func previewTapped(_ recognizer: UITapGestureRecognizer) {
        guard let target = recognizer.view else { return }
        var index = 0
        for view in previewStack.arrangedSubviews {
            if view === target {
                if pendingImages.indices.contains(index) { pendingImages.remove(at: index) }
                previewStack.removeArrangedSubview(view)
                view.removeFromSuperview()
                previewHeight.constant = previewStack.arrangedSubviews.isEmpty ? 0 : 56
                return
            }
            index += 1
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }

    @objc private func attachAudio() {
        setLoading(true)
        VKApiClient.shared.call("audio.get", ["count": "100"]) { [weak self] result in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.setLoading(false)
                switch result {
                case .success(let value):
                    let tracks = VKAudio.readList(value)
                    guard tracks.isEmpty == false else {
                        self.presentAlert(title: "Пусто", message: "В вашей музыкальной библиотеке нет треков.")
                        return
                    }
                    self.showAudioPicker(tracks)
                case .failure(let error):
                    self.presentAlert(title: "Ошибка", message: error.message)
                }
            }
        }
    }

    private func showAudioPicker(_ tracks: [VKAudio]) {
        let sheet = UIAlertController(title: "Прикрепить трек", message: nil, preferredStyle: .actionSheet)
        for track in tracks.prefix(8) {
            sheet.addAction(UIAlertAction(title: track.displayName, style: .default) { [weak self] _ in
                guard let self = self else { return }
                self.attachments.append(track.attachmentValue)
                self.pendingAudioTitle = track.displayName
                self.placeholder.text = "Трек: " + track.displayName
                self.placeholder.textColor = Theme.textPrimary
            })
        }
        sheet.addAction(UIAlertAction(title: "Отмена", style: .cancel, handler: nil))
        if let popover = sheet.popoverPresentationController {
            popover.sourceView = audioButton
            popover.sourceRect = audioButton.bounds
        }
        present(sheet, animated: true, completion: nil)
    }

    // MARK: - Публикация

    @objc private func publishTapped() {
        let message = (input.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard message.isEmpty == false || attachments.isEmpty == false else {
            presentAlert(title: "Пусто", message: "Напишите текст или прикрепите фото.")
            return
        }

        publishButton.isEnabled = false
        uploadPendingPhotos { [weak self] didUpload in
            // completion вызывается и при ошибке загрузки — иначе кнопка
            // публикации навсегда оставалась disabled.
            guard let self = self else { return }
            guard didUpload else {
                self.publishButton.isEnabled = true
                return
            }
            var parameters = ["owner_id": String(LocalSettings.shared.userId),
                              "message": message]
            if self.attachments.isEmpty == false {
                parameters["attachments"] = self.attachments.joined(separator: ",")
            }
            VKApiClient.shared.call("wall.post", parameters) { result in
                DispatchQueue.main.async {
                    self.publishButton.isEnabled = true
                    switch result {
                    case .success:
                        self.clearComposer()
                        self.setComposerVisible(false, animated: true)
                        self.load()
                    case .failure(let error):
                        self.presentAlert(title: "Ошибка", message: error.message)
                    }
                }
            }
        }
    }

    /// Загружает все прикреплённые фото по очереди.
    /// `completion(true)` — всё загружено, можно публиковать;
    /// `completion(false)` — загрузка сорвалась, о выходе сообщено пользователю.
    private func uploadPendingPhotos(completion: @escaping (Bool) -> Void) {
        guard pendingImages.isEmpty == false else {
            completion(true)
            return
        }

        // Фото загружаются строго по одному: параллельные запросы к одному
        // upload-серверу на части инстансов отвечают ошибкой.
        func loadNext(_ index: Int) {
            guard index < pendingImages.count else {
                completion(true)
                return
            }
            uploadWallPhoto(pendingImages[index]) { success in
                guard success else {
                    completion(false)
                    return
                }
                loadNext(index + 1)
            }
        }
        loadNext(0)
    }

    /// photos.getWallUploadServer → upload → photos.saveWallPhoto.
    private func uploadWallPhoto(_ data: Data, completion: @escaping (Bool) -> Void) {
        VKApiClient.shared.callDict("photos.getWallUploadServer", [:]) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let value):
                let uploadURL = J.getString(value, "upload_url", "")
                guard uploadURL.isEmpty == false else {
                    self.presentAlert(title: "Ошибка", message: "Сервер не вернул адрес загрузки фото.")
                    completion(false)
                    return
                }
                VKApiClient.shared.upload(uploadURL, data: data, fieldName: "photo", fileName: "photo.jpg") { uploadResult in
                    switch uploadResult {
                    case .success(let payload):
                        self.saveWallPhoto(payload, completion: completion)
                    case .failure(let error):
                        self.presentAlert(title: "Ошибка", message: error.message)
                        completion(false)
                    }
                }
            case .failure(let error):
                self.presentAlert(title: "Ошибка", message: error.message)
                completion(false)
            }
        }
    }

    private func saveWallPhoto(_ uploadResult: [String: Any], completion: @escaping (Bool) -> Void) {
        let parameters = [
            "server": J.getString(uploadResult, "server", ""),
            "photo": J.getString(uploadResult, "photo", ""),
            "hash": J.getString(uploadResult, "hash", "")
        ]
        VKApiClient.shared.call("photos.saveWallPhoto", parameters) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let value):
                let photo = J.items(value).first as? [String: Any] ?? J.dict(value) ?? [:]
                let ownerId = J.getInt(photo, "owner_id", LocalSettings.shared.userId)
                let id = J.getInt(photo, "id", 0)
                if id != 0 {
                    self.attachments.append("photo\(ownerId)_\(id)")
                    completion(true)
                } else {
                    self.presentAlert(title: "Ошибка", message: "Сервер не вернул идентификатор фото.")
                    completion(false)
                }
            case .failure(let error):
                self.presentAlert(title: "Ошибка", message: error.message)
                completion(false)
            }
        }
    }

    private func clearComposer() {
        input.text = nil
        placeholder.text = "Что у вас нового?"
        placeholder.textColor = Theme.textSecondary
        attachments = []
        pendingImages = []
        pendingAudioTitle = nil
        clearPreview()
    }

    /// `removeFromSuperview` оставлял вьюхи в `arrangedSubviews` стека —
    /// следующее превью вставало поверх «мёртвых» подписок и ломалось.
    private func clearPreview() {
        for subview in previewStack.arrangedSubviews {
            previewStack.removeArrangedSubview(subview)
            subview.removeFromSuperview()
        }
        previewHeight.constant = 0
    }

    func textViewDidChange(_ textView: UITextView) {
        placeholder.isHidden = (textView.text?.isEmpty == false)
    }

    override func applyTheme() {
        super.applyTheme()
        composer.backgroundColor = Theme.composerBackground
        input.textColor = Theme.textPrimary
        input.backgroundColor = Theme.card
        input.layer.cornerRadius = Theme.isVK56 ? 2 : 12
        composeButton.backgroundColor = Theme.accent
        composeButton.layer.cornerRadius = Theme.isVK56 ? 4 : 28
    }
}