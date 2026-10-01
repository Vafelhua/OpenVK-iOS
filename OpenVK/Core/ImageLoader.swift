import UIKit

/// Загрузка картинок с кэшем в памяти и на диске (URLCache) + токен/UA в запросе.
final class ImageLoader {
    static let shared = ImageLoader()

    private let memory = NSCache<NSURL, UIImage>()
    private let lock = NSLock()
    private var callbacks: [String: [(UIImage?) -> Void]] = [:]
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.httpAdditionalHeaders = ["User-Agent": VKConstants.userAgent]
        return URLSession(configuration: configuration)
    }()

    private init() {
        memory.countLimit = 300
        memory.totalCostLimit = 64 * 1024 * 1024
    }

    func load(_ urlString: String?, completion: @escaping (UIImage?) -> Void) {
        guard let raw = urlString, raw.isEmpty == false, let url = URL(string: raw) else {
            completion(nil)
            return
        }

        if let cached = memory.object(forKey: url as NSURL) {
            completion(cached)
            return
        }
        let path = cachePath(for: url)
        if let data = try? Data(contentsOf: URL(fileURLWithPath: path)), let cached = UIImage(data: data) {
            memory.setObject(cached, forKey: url as NSURL)
            completion(cached)
            return
        }

        lock.lock()
        let isFirst = (callbacks[raw] == nil)
        callbacks[raw, default: []].append(completion)
        lock.unlock()
        guard isFirst else { return }

        var request = URLRequest(url: url)
        if let token = LocalSettings.shared.token, token.isEmpty == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        session.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self else { return }
            let image = data.flatMap { UIImage(data: $0) }
            if let image = image {
                self.memory.setObject(image, forKey: url as NSURL, cost: imageCost(image))
                self.writeToDisk(data: data, for: url)
            }
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

    private func writeToDisk(data: Data?, for url: URL) {
        guard let data = data, data.count < 4 * 1024 * 1024 else { return }
        try? data.write(to: URL(fileURLWithPath: cachePath(for: url)))
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
        currentURL = urlString
        image = nil
        let color = placeholder ?? placeholderColor
        backgroundColor = (urlString?.isEmpty == false) ? color : .clear
        guard let raw = urlString, raw.isEmpty == false else { return }
        ImageLoader.shared.load(raw) { [weak self] image in
            guard let self = self, let image = image, self.currentURL == raw else { return }
            self.image = image
            self.backgroundColor = .clear
        }
    }

    func clear() {
        currentURL = nil
        image = nil
        backgroundColor = .clear
    }
}