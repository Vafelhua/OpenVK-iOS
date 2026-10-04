import Foundation

/// Вход по логину/паролю: `POST https://{инстанс}/token` (grant_type=password).
enum AuthService {
    static func login(username: String,
                      password: String,
                      completion: @escaping (Result<Void, VKError>) -> Void) {
        let endpoint = LocalSettings.shared.tokenURL
        guard let url = URL(string: endpoint) else {
            completion(.failure(VKError(code: 0, message: "Некорректный адрес сервера авторизации")))
            return
        }

        let form: [String: String] = [
            "grant_type": "password",
            "client_id": VKConstants.clientID,
            "client_name": VKConstants.clientName,
            "username": username,
            "password": password
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8",
                         forHTTPHeaderField: "Content-Type")
        request.setValue(VKConstants.userAgent, forHTTPHeaderField: "User-Agent")
        let body = form
            .sorted { $0.key < $1.key }
            .map { escape($0.key) + "=" + escape($0.value) }
            .joined(separator: "&")
        request.httpBody = body.data(using: .utf8)

let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: configuration)

        session.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(VKError(code: 0, message: "Нет связи с сервером: \(error.localizedDescription)")))
                return
            }
            // Эндпоинт /token часто отдаёт 4xx с JSON-телом ошибки —
            // статус проверяем, но тело всё равно пробуем разобрать.
            let status = (response as? HTTPURLResponse)?.statusCode
            if let status = status, status >= 500 {
                completion(.failure(VKError(code: 0, message: "Сервер авторизации недоступен (HTTP \(status)).")))
                return
            }
            guard let data = data, data.isEmpty == false,
                let json = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]),
                let dict = J.dict(json) else {
                completion(.failure(VKError(code: 0, message: "Сервер вернул неожиданный ответ.")))
                return
            }

            if dict.keys.contains("error_code") {
                let raw = J.getString(dict, "error_msg", "Неверный логин или пароль")
                let code = J.getInt(dict, "error_code", 0)
                // OpenVK отдаёт код 4 «неверный пароль», 5 «не авторизован».
                let message = (code == 4 || code == 5)
                    ? "Неверный логин или пароль"
                    : raw
                completion(.failure(VKError(code: code, message: message)))
                return
            }
            if let inner = J.dict(dict["error"]) {
                let innerCode = J.getInt(inner, "error_code", 0)
                let raw = J.getString(inner, "error_msg", "Ошибка авторизации")
                let message = (innerCode == 4 || innerCode == 5)
                    ? "Неверный логин или пароль"
                    : raw
                completion(.failure(VKError(code: innerCode, message: message)))
                return
            }

            // Некоторые инстансы отдают токен плоским объектом, часть — в «response».
            let payload = J.getDict(dict, "response") ?? dict
            let token = J.getString(payload, "access_token", "")
            guard token.isEmpty == false else {
                completion(.failure(VKError(code: 0, message: "Не удалось получить токен.")))
                return
            }

            let userId = J.getInt(payload, "user_id", 0)
            if userId == 0 {
                completion(.failure(VKError(code: 0, message: "Сервер не вернул идентификатор пользователя.")))
                return
            }

            LocalSettings.shared.saveCredentials(token: token, userId: userId)
            completion(.success(()))
        }.resume()
    }

    private static func escape(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let escaped = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return escaped.replacingOccurrences(of: "%20", with: "+")
    }
}