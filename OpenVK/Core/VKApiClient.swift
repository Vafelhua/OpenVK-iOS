import Foundation

/// HTTP-клиент OpenVK API (VK-совместимый).
///
/// Запросы уходят POST'ом в `{инстанс}/method/{метод}` (form-url-encoded),
/// токен дублируется в форме, в query string и в заголовке `Authorization`:
/// разные версии OpenVK читают его по-разному.
final class VKApiClient {
    static let shared = VKApiClient()

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 120
        configuration.httpAdditionalHeaders = ["User-Agent": VKConstants.userAgent]
        configuration.httpShouldSetCookies = false
        return URLSession(configuration: configuration)
    }()

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
    @discardableResult
    func call(_ method: String,
              _ parameters: [String: String] = [:],
              completion: @escaping (Result<Any, VKError>) -> Void) -> Bool {
        guard let baseURL = buildURL(method) else {
            completion(.failure(VKError(code: 0, message: "Некорректный адрес метода")))
            return false
        }

        let token = LocalSettings.shared.token ?? ""
        var form = parameters
        if token.isEmpty == false {
            form["access_token"] = token
        }
        form["v"] = VKConstants.apiVersion
        form["client_id"] = VKConstants.clientID

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        var query = components?.queryItems ?? []
        query.append(URLQueryItem(name: "access_token", value: token))
        components?.queryItems = query

        guard let url = components?.url else {
            completion(.failure(VKError(code: 0, message: "Некорректный адрес метода")))
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

        session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(VKError(code: 0, message: "Нет связи с сервером: \(error.localizedDescription)")))
                return
            }
            guard let data = data, data.isEmpty == false else {
                completion(.failure(VKError(code: 0, message: "Пустой ответ сервера")))
                return
            }
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [.allowFragments])
                completion(.success(try self.parse(json, method: method)))
            } catch let error as VKError {
                completion(.failure(error))
            } catch {
                completion(.failure(VKError(code: 0, message: "Некорректный ответ сервера (метод \(method))")))
            }
        }.resume()
        return true
    }

    /// Короткая обёртка: сразу отдаёт словарь (для методов с «response»-объектом).
    func callDict(_ method: String,
                  _ parameters: [String: String] = [:],
                  completion: @escaping (Result<[String: Any], VKError>) -> Void) {
        call(method, parameters) { result in
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
            completion(.failure(VKError(code: 0, message: "Нет адреса загрузки")))
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

        session.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(VKError(code: 0, message: "Не удалось загрузить файл: \(error.localizedDescription)")))
                return
            }
            guard let data = data,
                let json = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]),
                let dict = J.dict(json) else {
                    completion(.failure(VKError(code: 0, message: "Некорректный ответ при загрузке файла")))
                    return
            }
            completion(.success(dict))
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