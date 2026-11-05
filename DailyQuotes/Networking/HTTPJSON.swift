import Foundation

/// 名言源共用的 HTTP JSON 请求助手：绕过缓存、超时、状态码检查，解码失败返回 nil。
/// Общий помощник HTTP/JSON для источников цитат: обход кеша, таймаут, проверка статуса, nil при ошибке разбора.
enum HTTPJSON {
    static func get<T: Decodable>(
        _ type: T.Type,
        from url: URL,
        session: URLSession,
        timeout: TimeInterval = 15
    ) async -> T? {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // 名言接口缓存较激进，始终请求最新内容。
        // API цитат кешируют агрессивно, поэтому всегда запрашиваем свежее содержимое.
        request.cachePolicy = .reloadIgnoringLocalCacheData

        guard let (data, response) = try? await session.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
