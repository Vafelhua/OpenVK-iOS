import Foundation

/// Токен OpenVK недействителен — приложение должно вернуться на экран входа.
extension Notification.Name {
    static let openVKAuthExpired = Notification.Name("OpenVKAuthExpired")
}

/// HTTP-клиент OpenVK API (VK-совместимый).
///
/// Запросы уходят POST'ом в `{инстанс}/method/{метод}` (form-url-encoded),
/// токен дублируется в форме, в query string и в заголовке `Authorization`:
/// разные версии OpenVK читают его по-разному.
final class VKApiClient {
    static let shared = VKApiClient()

    /// Общая сессия: переиспользование соединения и пула сокетов.
    static let sharedSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.httpAdditionalHeaders = ["User-Agent": VKConstants.userAgent]
        configuration.httpShouldSetCookies = false
        configuration.requestCachePolicy = .useProtocolCachePolicy
        return URLSession(configuration: configuration)
    }()

    private lazy var session = VKApiClient.sharedSession
    private var tasks: [String: URLSessionDataTask] = [:]
    private let tasksLock = NSLock()

    private init() {}

    // MARK: - URL

    func buildURL(_ method: String) -> URL? {
        var base = LocalSettings.shared.instanceBaseURL
        if base.hasSuffix("/") == false { base += "/" }
        if base.contains("/method") == false && base.hasSuffix("method/") == false {
            base += "method/"
        }
        return URL(string: base + method)
    }

    // MARK: - Вызов метода

    /// Вызывает метод API. `Result` содержит «сырой» разобранный ответ:
    /// либо словарь, либо массив (как у `users.get`).
    ///
    /// - Parameter cancelKey: если задан, предыдущий запрос с тем же ключом
    ///   отменяется. Нужен для поиска, где каждый новый запрос вытесняет предыдущий.
    @discardableResult
    func call(_ method: String,
              _ parameters: [String: String] = [:],
              cancelKey: String? = nil,
              completion: @escaping (Result<Any, VKError>) -> Void) -> Bool {
        guard let baseURL = buildURL(method) else {
            deliver(.failure(VKError(code: 0, message: "Некорректный адрес метода")), completion: completion)
            return false
        }

        if let key = cancelKey { cancelPending(key) }

        let token = LocalSettings.shared.token ?? ""
        var form = parameters
        if token.isEmpty == false {
            form["access_token"] = token
        }
        form["v"] = VKConstants.apiVersion
        form["client_id"] = VKConstants.clientID

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var query = components?.queryItems ?? []
        if token.isEmpty == false {
            query.append(URLQueryItem(name: "access_token", value: token))
        }
        components?.queryItems = query

        guard let url = components?.url else {
            deliver(.failure(VKError(code: 0, message: "Некорректный адрес метода")), completion: completion)
            return false
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8",
                         forHTTPHeaderField: "Content-Type")
        if token.isEmpty == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = encodeForm(form).data(using: .utf8)

        let task = session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            self.forget(cancelKey: cancelKey)

            if let error = error {
                // Отменённый запрос — не ошибка, о нём уже сообщил вызывающий.
                if (error as NSError).code == NSURLErrorCancelled { return }
                self.deliver(.failure(VKError(code: 0,
                                              message: "Нет связи с сервером: \(error.localizedDescription)")),
                             completion: completion)
                return
            }

            // Прокси и some-инстансы отдают HTML-заглушку с кодом 200/5xx —
            // без проверки статуса JSON-парсер падал бы с невнятным сообщением.
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                let message = (400...499).contains(http.statusCode)
                    ? "Сервер отклонил запрос (HTTP \(http.statusCode)). Проверьте адрес в настройках."
                    : "Сервер недоступен (HTTP \(http.statusCode)). Попробуйте позже."
                self.deliver(.failure(VKError(code: 0, message: message)), completion: completion)
                return
            }

            guard let data = data, data.isEmpty == false else {
                self.deliver(.failure(VKError(code: 0, message: "Пустой ответ сервера")), completion: completion)
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
                self.deliver(.success(try self.parse(json, method: method)), completion: completion)
            } catch let error as VKError {
                self.deliver(.failure(error), completion: completion)
            } catch {
                self.deliver(.failure(VKError(code: 0,
                                              message: "Сервер вернул не-JSON ответ (метод \(method)). Проверьте адрес сервера в настройках.")),
                             completion: completion)
            }
        }

        register(cancelKey: cancelKey, task: task)
        task.resume()
        return true
    }

    /// Отменяет ранее отправленный запрос с тем же ключом.
    func cancel(_ cancelKey: String) {
        cancelPending(cancelKey)
    }

    /// Короткая обёртка: сразу отдаёт словарь (для методов с «response»-объектом).
    func callDict(_ method: String,
                  _ parameters: [String: String] = [:],
                  cancelKey: String? = nil,
                  completion: @escaping (Result<[String: Any], VKError>) -> Void) {
        call(method, parameters, cancelKey: cancelKey) { result in
            switch result {
            case .success(let value):
                if let dict = J.dict(value) {
                    completion(.success(dict))
                } else {
                    completion(.failure(VKError(code: 0, message: "Метод \(method) вернул не объект")))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    // MARK: - Загрузка файла

    /// Загрузка файла на upload_url (фото-сервер OpenVK).
    func upload(_ uploadURL: String,
                data: Data,
                fieldName: String,
                fileName: String,
                completion: @escaping (Result<[String: Any], VKError>) -> Void) {
        guard let url = URL(string: uploadURL) else {
            deliver(.failure(VKError(code: 0, message: "Нет адреса загрузки")), completion: completion)
            return
        }
        let boundary = "OpenVKBoundary" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = LocalSettings.shared.token, token.isEmpty == false {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = body

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            if let error = error {
                if (error as NSError).code == NSURLErrorCancelled { return }
                self.deliver(.failure(VKError(code: 0,
                                              message: "Не удалось загрузить файл: \(error.localizedDescription)")),
                             completion: completion)
                return
            }
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                self.deliver(.failure(VKError(code: 0,
                                              message: "Загрузка отклонена сервером (HTTP \(http.statusCode)).")),
                             completion: completion)
                return
            }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]),
                let dict = J.dict(json) else {
                self.deliver(.failure(VKError(code: 0, message: "Некорректный ответ при загрузке файла")),
                             completion: completion)
                return
            }
            self.deliver(.success(dict), completion: completion)
        }.resume()
    }

    // MARK: - Парсинг

    private func parse(_ json: Any, method: String) throws -> Any {
        if let array = json as? [Any] { return array }
        guard let root = json as? [String: Any] else {
            throw VKError(code: 0, message: "Некорректный ответ сервера (метод \(method))")
        }

        // OpenVK отдаёт ошибку плоским объектом, ВК — вложенным.
        if root.keys.contains("error_code") {
            throw VKError(code: J.getInt(root, "error_code", 0),
                          message: J.getString(root, "error_msg", "Неизвестная ошибка"))
        }
        if let inner = J.dict(root["error"]) {
            throw VKError(code: J.getInt(inner, "error_code", 0),
                          message: J.getString(inner, "error_msg", "Неизвестная ошибка"))
        }

        // Успешный результат оборачивается в «response».
        if let response = root["response"], let dict = response as? [String: Any] {
            return dict
        }
        return root
    }

    // MARK: - Доставка результата

    /// Результат всегда приходит в главный поток, а протухший токен один раз
    /// порождает уведомление для AppDelegate.
    private func deliver(_ result: Result<Any, VKError>, completion: @escaping (Result<Any, VKError>) -> Void) {
        if case .failure(let error) = result, error.isAuthExpired {
            notifyAuthExpiredOnce(error)
        }
        DispatchQueue.main.async { completion(result) }
    }

    private var authExpiredNotified = false

    private func notifyAuthExpiredOnce(_ error: VKError) {
        // Несколько параллельных запросов обычно падают одновременно —
        // показываем предупреждение пользователю только один раз.
        guard authExpiredNotified == false else { return }
        authExpiredNotified = true
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .openVKAuthExpired, object: error)
        }
    }

    /// Сбрасывает «уже показали предупреждение» — новый вход должен снова его получить.
    func resetAuthExpiredFlag() {
        authExpiredNotified = false
    }

    // MARK: - Отмена запросов

    private func register(cancelKey: String?, task: URLSessionDataTask) {
        guard let key = cancelKey else { return }
        tasksLock.lock()
        tasks[key] = task
        tasksLock.unlock()
    }

    private func forget(cancelKey: String?) {
        guard let key = cancelKey else { return }
        tasksLock.lock()
        tasks.removeValue(forKey: key)
        tasksLock.unlock()
    }

    private func cancelPending(_ key: String) {
        tasksLock.lock()
        let task = tasks.removeValue(forKey: key)
        tasksLock.unlock()
        task?.cancel()
    }

    // MARK: - Утилиты

    func escape(_ value: String) -> String {
        // Строгий набор для application/x-www-form-urlencoded: пробел → «+».
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let escaped = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return escaped.replacingOccurrences(of: "%20", with: "+")
    }

    private func encodeForm(_ form: [String: String]) -> String {
        return form
            .sorted { $0.key < $1.key }
            .map { escape($0.key) + "=" + escape($0.value) }
            .joined(separator: "&")
    }
}