import Foundation

/// Real-time доставка новых сообщений.
///
/// Основной путь — Long Poll (`messages.getLongPollServer` + `act=a_check`).
/// Если инстанс не поддерживает Long Poll, клиент деградирует до периодического
/// `onUpdate`-сигнала (экран сам перезапрашивает `messages.getHistory`).
final class LongPollClient {
    /// Новые сообщения (или просто «пора обновить список»).
    var onUpdate: (() -> Void)?
    /// Long Poll недоступен — клиент перешёл на опрос по таймеру.
    var onFallback: (() -> Void)?

    private let api = VKApiClient.shared
    private var server: String?
    private var key: String?
    private var ts: String?
    private var peerId: Int = 0
    private var isRunning = false
    private var isFallback = false
    private var session = URLSession(configuration: .default)
    private var timer: Timer?

    private let fallbackInterval: TimeInterval = 8

    // MARK: - Запуск

    func start(peerId: Int) {
        stop()
        self.peerId = peerId
        isRunning = true
        isFallback = false

        api.call("messages.getLongPollServer", ["need_pts": "1", "lp_version": "3"]) { [weak self] result in
            guard let self = self, self.isRunning else { return }
            switch result {
            case .success(let value):
                let server = J.getString(value, "server", "")
                let key = J.getString(value, "key", "")
                let ts = J.getString(value, "ts", "")
                if server.isEmpty == false {
                    self.server = server
                    self.key = key
                    self.ts = ts.isEmpty ? "1" : ts
                    self.loop()
                } else {
                    self.startFallback()
                }
            case .failure:
                self.startFallback()
            }
        }
    }

    func stop() {
        isRunning = false
        isFallback = false
        server = nil
        key = nil
        ts = nil
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Long Poll

    private func loop() {
        guard isRunning, isFallback == false,
            let server = server, let key = key, let ts = ts else { return }

        var components = URLComponents(string: "https://\(server)")
        var items = [
            URLQueryItem(name: "act", value: "a_check"),
            URLQueryItem(name: "key", value: key),
            URLQueryItem(name: "ts", value: ts),
            URLQueryItem(name: "wait", value: "25")
        ]
        if let token = LocalSettings.shared.token, token.isEmpty == false {
            items.append(URLQueryItem(name: "access_token", value: token))
        }
        components?.queryItems = items
        guard let url = components?.url else {
            startFallback()
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue(VKConstants.userAgent, forHTTPHeaderField: "User-Agent")

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            guard self.isRunning else { return }

            if error != nil {
                // Обрыв связи: переподключаемся с небольшой паузой.
                self.scheduleRetry(after: 3)
                return
            }
            if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                self.startFallback()
                return
            }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]),
                let answer = json as? [Any] else {
                self.scheduleRetry(after: 3)
                return
            }

            if let first = answer.first {
                let newTS = String(describing: first)
                if newTS.isEmpty == false && newTS != "0" {
                    self.ts = newTS
                }
            }

            if self.hasUpdates(answer) {
                DispatchQueue.main.async { self.onUpdate?() }
            }
            self.loop()
        }
        task.resume()
    }

    /// Формат ответа: [ts, pts, [[flags, pts, peer_id, …], …]].
    private func hasUpdates(_ answer: [Any]) -> Bool {
        guard answer.count > 2, let events = answer[2] as? [Any] else { return false }
        for event in events {
            guard let fields = event as? [Any], fields.count > 2 else { continue }
            let flags = J.toInt(fields[0]) ?? 0
            let eventPeer = J.toInt(fields[2]) ?? 0
            if peerId != 0, eventPeer != peerId { continue }
            // 4 — новое сообщение, 1..3 / 5..7 — правки, чата, входы/выходы.
            if flags & 4 != 0 { return true }
            if flags & 1 != 0 || flags & 2 != 0 || flags & 8 != 0 || flags & 64 != 0 { return true }
        }
        return false
    }

    private func scheduleRetry(after seconds: TimeInterval) {
        schedule(seconds)
    }

    private func schedule(_ seconds: TimeInterval) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self = self, self.isRunning, self.isFallback == false else { return }
            self.loop()
        }
    }

    // MARK: - Fallback (опрос по таймеру)

    private func startFallback() {
        guard isRunning, isFallback == false else { return }
        isFallback = true
        server = nil
        key = nil
        ts = nil

        DispatchQueue.main.async { self.onFallback?() }

        timer?.invalidate()
        // Именно `Timer(timeInterval:)`, а не `scheduledTimer`: созданный
        // scheduledTimer уже висит в default mode, и добавление в .common
        // заставляло таймер срабатывать дважды за тик (двойной onUpdate).
        let created = Timer(timeInterval: fallbackInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
            self.onUpdate?()
        }
        RunLoop.main.add(created, forMode: .common)
        timer = created
    }
}