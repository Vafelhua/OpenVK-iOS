import UIKit

/// Загрузка картинок: кэш в памяти + на диске, дедупликация одинаковых запросов.
final class ImageLoader {
    static let shared = ImageLoader()

    private let memory = NSCache<NSURL, UIImage>()
    private let lock = NSLock()
    private var callbacks: [String: [(UIImage?) -> Void]] = [:]

    /// Отдельная очередь: чтение и запись диск-кэша не должны блокировать UI.
    private let ioQueue = DispatchQueue(label: "org.openvk.images", qos: .utility, attributes: .concurrent)

    private lazy var session = VKApiClient.sharedSession

    private init() {
        memory.countLimit = 300
        memory.totalCostLimit = 64 * 1024 * 1024
        ioQueue.async { self.pruneDiskCacheIfNeeded() }
    }

    // MARK: - Загрузка

    /// Освобождает память по сигналу UIApplication.didReceiveMemoryWarningNotification.
    func purgeMemory() {
        memory.removeAllObjects()
    }

    func load(_ urlString: String?, completion: @escaping (UIImage?) -> Void) {
        guard let raw = urlString, raw.isEmpty == false, let url = URL(string: raw) else {
            DispatchQueue.main.async { completion(nil) }
            return
        }

        // 1. Память — синхронно, это дешёвый NSCache.
        if let cached = memory.object(forKey: url as NSURL) {
            DispatchQueue.main.async { completion(cached) }
            return
        }

        // 2. Регистрируем обработчик. Если такой URL уже грузится или лежит
        //    в очереди на диск-чтение — просто добавимся в список ожидания.
        lock.lock()
        let isFirst = (callbacks[raw] == nil)
        callbacks[raw, default: []].append(completion)
        lock.unlock()
        guard isFirst else { return }

        // 3. Диск-кэш читаем в фоне, раньше результата не показываем ничего.
        ioQueue.async { [weak self] in
            guard let self = self else { return }
            let cached = self.readFromDisk(url: url)
            if let image = cached {
                self.memory.setObject(image, forKey: url as NSURL, cost: self.imageCost(image))
                self.finish(raw: raw, image: image)
                return
            }
            self.startNetwork(url: url, raw: raw)
        }
    }

    private func startNetwork(url: URL, raw: String) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        if let token = LocalSettings.shared.token, token.isEmpty == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        session.dataTask(with: request) { [weak self] data, response, _ in
            guard let self = self else { return }

            // Страница ошибки (HTML 404/500) не является картинкой — в кэш её не кладём.
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                self.finish(raw: raw, image: nil)
                return
            }
            guard let data = data, data.isEmpty == false, let image = UIImage(data: data) else {
                self.finish(raw: raw, image: nil)
                return
            }

            self.memory.setObject(image, forKey: url as NSURL, cost: self.imageCost(image))
            self.writeToDisk(data: data, for: url)
            self.finish(raw: raw, image: image)
        }.resume()
    }

    private func finish(raw: String, image: UIImage?) {
        lock.lock()
        let handlers = callbacks[raw] ?? []
        callbacks.removeValue(forKey: raw)
        lock.unlock()
        DispatchQueue.main.async {
            handlers.forEach { $0(image) }
        }
    }

    // MARK: - Диск

    private var cacheDirectory: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = base.appendingPathComponent("OpenVKImages", isDirectory: true)
        if FileManager.default.fileExists(atPath: directory.path) == false {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }()

    private func cachePath(for url: URL) -> String {
        return cacheDirectory.appendingPathComponent(ImageLoader.stableHash(url.absoluteString)).path
    }

    /// Стабильный между запусками хэш строки (FNV-1a) — `hashValue` в Swift
    /// меняется при каждом запуске и ломает дисковый кэш.
    private static func stableHash(_ text: String) -> String {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return String(hash, radix: 16)
    }

    private func readFromDisk(url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: cachePath(for: url))) else {
            return nil
        }
        return UIImage(data: data)
    }

    private func writeToDisk(data: Data?, for url: URL) {
        guard let data = data, data.count < 4 * 1024 * 1024 else { return }
        try? data.write(to: URL(fileURLWithPath: cachePath(for: url)), options: .atomic)
    }

    /// Без предела дисковый кэш растёт до конца свободного места. Раз в запуск
    /// подрезаем его до 64 МБ, удаляя самые старые файлы.
    private func pruneDiskCacheIfNeeded() {
        let limit: UInt64 = 64 * 1024 * 1024
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: keys,
            options: .skipsHiddenFiles
        ) else { return }

        var entries: [(url: URL, size: UInt64, date: Date)] = []
        var total: UInt64 = 0
        for file in files {
            guard let values = try? file.resourceValues(forKeys: Set(keys)) else { continue }
            let size = UInt64(values.fileSize ?? 0)
            total += size
            entries.append((file, size, values.contentModificationDate ?? .distantPast))
        }

        guard total > limit else { return }
        entries.sort { $0.date < $1.date }
        var freed: UInt64 = 0
        for entry in entries {
            if total - freed <= limit { break }
            try? FileManager.default.removeItem(at: entry.url)
            freed += entry.size
        }
    }

    private func imageCost(_ image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 1 }
        return cg.bytesPerRow * cg.height
    }
}

/// UIImageView, умеющий грузить картинку по URL без «гонок» при переиспользовании ячеек.
final class RemoteImageView: UIImageView {
    private var currentURL: String?
    private let placeholderColor: UIColor

    init(cornerRadius: CGFloat = 0, placeholderColor: UIColor = Theme.avatarPlaceholder) {
        self.placeholderColor = placeholderColor
        super.init(frame: .zero)
        contentMode = .scaleAspectFill
        clipsToBounds = true
        backgroundColor = placeholderColor
        layer.cornerRadius = cornerRadius
    }

    required init?(coder: NSCoder) {
        placeholderColor = Theme.avatarPlaceholder
        super.init(coder: coder)
        contentMode = .scaleAspectFill
        clipsToBounds = true
    }

    func setRemote(_ urlString: String?, placeholder: UIColor? = nil) {
        let hasURL = (urlString?.isEmpty == false)
        // Тот же URL — перезагрузка не нужна, иначе картинка мигает при
        // переиспользовании ячейки. Но если предыдущая загрузка провалилась,
        // картинки нет — тогда повторяем попытку.
        if currentURL == urlString, image != nil || hasURL == false {
            if hasURL { backgroundColor = .clear }
            return
        }
        currentURL = urlString
        image = nil
        let color = placeholder ?? placeholderColor
        backgroundColor = hasURL ? color : .clear
        guard let raw = urlString, raw.isEmpty == false else { return }
        ImageLoader.shared.load(raw) { [weak self] image in
            guard let self = self, let image = image, self.currentURL == raw else { return }
            self.image = image
            self.backgroundColor = .clear
        }
    }

    var remoteURL: String? { return currentURL }

    func clear() {
        currentURL = nil
        image = nil
        backgroundColor = .clear
    }
}

/// Просмотр фотографии во весь экран с зумом и pinch-to-zoom.
final class PhotoViewer: UIViewController {
    private let urlString: String
    private let imageView = UIScrollView()
    private let imageContent = UIImageView()
    private let closeButton = UIButton(type: .system)
    private let spinner = UIActivityIndicatorView(style: .gray)

    static func present(url: String) {
        let viewer = PhotoViewer(urlString: url)
        viewer.modalPresentationStyle = .overFullScreen
        viewer.modalPresentationCapturesStatusBarAppearance = true
        // Находим верхний контроллер: вызов может идти из ячейки глубоко в стеке.
        var top: UIViewController? = AppDelegate.shared.window?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        top?.present(viewer, animated: false)
    }

    init(urlString: String) {
        self.urlString = urlString
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black

        closeButton.setTitle("✕", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 30, weight: .light)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)

        imageContent.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.delegate = self
        imageView.minimumZoomScale = 1
        imageView.maximumZoomScale = 4
        imageView.showsHorizontalScrollIndicator = false
        imageView.showsVerticalScrollIndicator = false
        imageView.addSubview(imageContent)

        spinner.color = .white
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()

        view.addSubview(imageView)
        view.addSubview(spinner)
        view.addSubview(closeButton)

        let safe = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: safe.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: safe.bottomAnchor),

            imageContent.topAnchor.constraint(equalTo: imageView.topAnchor),
            imageContent.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            imageContent.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            imageContent.bottomAnchor.constraint(equalTo: imageView.bottomAnchor),
            imageContent.widthAnchor.constraint(equalTo: imageView.widthAnchor),
            imageContent.heightAnchor.constraint(equalTo: imageView.heightAnchor),

            spinner.centerXAnchor.constraint(equalTo: safe.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: safe.centerYAnchor),

            closeButton.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            closeButton.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16)
        ])

        // Тап по снимку закрывает просмотр; щипок — зум.
        let tap = UITapGestureRecognizer(target: self, action: #selector(closeTapped))
        imageView.addGestureRecognizer(tap)

        ImageLoader.shared.load(urlString) { [weak self] image in
            guard let self = self else { return }
            self.spinner.stopAnimating()
            guard let image = image else {
                self.presentAlert(title: "Не удалось открыть", message: "Фотография не загрузилась.")
                return
            }
            self.imageContent.image = image
        }
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }
}

extension PhotoViewer: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageContent
    }
}