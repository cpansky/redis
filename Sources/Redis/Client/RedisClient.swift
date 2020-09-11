import NIO

/// A Redis client.
public final class RedisClient: DatabaseConnection, BasicWorker {
    public typealias Database = RedisDatabase
    
    /// See `BasicWorker`.
    public var eventLoop: EventLoop {
        return channel.eventLoop
    }

    /// See `DatabaseConnection`.
    public var isClosed: Bool

    /// See `Extendable`.
    public var extend: Extend
    
    /// Handles queued redis commands and responses
    internal let queue: RedisCommandHandler

    /// The channel
    private let channel: Channel

    /// Creates a new Redis client on the provided data source and sink.
    init(queue: RedisCommandHandler, channel: Channel) {
        self.queue = queue
        self.channel = channel
        self.extend = [:]
        self.isClosed = false
        channel.closeFuture.always {
            self.isClosed = true
        }
    }

    /// Runs a Value as a command
    ///
    /// [Learn More →](https://docs.vapor.codes/3.0/redis/custom-commands/#usage)
    public func command(_ command: String, _ arguments: [RedisData] = []) -> Future<RedisData> {
        return send(.array([.bulkString(command)] + arguments)).map(to: RedisData.self) { res in
            // convert redis errors to a Future error
            switch res.storage {
            case .error(let error): throw error
            default: return res
            }
        }
    }

    /// Sends `RedisData` to the server.
    public func send(_ message: RedisData) -> Future<RedisData> {
        // ensure the connection is not closed
        guard !isClosed else {
            return eventLoop.newFailedFuture(error: closeError)
        }
        
        // create a new promise to fulfill later
        let promise = eventLoop.newPromise(RedisData.self)
        
        // write the message and the promise to the channel, which the `RequestResponseHandler` will capture
        return self.channel.writeAndFlush((message, promise))
            .flatMap { return promise.futureResult }
    }

    /// Closes this client.
    public func close() {
        self.isClosed = true
        channel.close(promise: nil)
    }
}

private let closeError = RedisError(identifier: "closed", reason: "Connection is closed.")

/// MARK: Config

/// Config options for a `RedisClient.
public struct RedisClientConfig: Codable {
    
    public enum SSLMode: String, Codable {
        case enabled
        case insecure
        case disabled
    }

    /// The Redis server's ssl enabled
    public var ssl: SSLMode

    /// The Redis server's hostname.
    public var hostname: String

    /// The Redis server's port.
    public var port: Int

    /// The Redis server's optional password.
    public var password: String?

    /// The database to connect to automatically.
    /// If nil, the connection will use the default 0.
    public var database: Int?

    /// Create a new `RedisClientConfig`
    public init(url: URL) {
        self.ssl = (url.scheme == "https" || url.scheme == "rediss") ? .enabled : .disabled
        self.hostname = url.host ?? "localhost"
        self.port = url.port ?? 6379
        self.password = url.password
        self.database = Int(url.path)
    }

    /// Creates a new, default `RedisClientConfig`.
    public init() {
        self.ssl = .disabled
        self.hostname = "localhost"
        self.port = 6379
    }

    internal func toURL() throws -> URL {
        let urlString: String
        let databaseSuffix: String

        if let database = database {
            databaseSuffix = "/\(database)"
        } else {
            databaseSuffix = ""
        }

        switch (password, ssl) {
            case let (pass?, .enabled), let (pass?, .insecure):
                urlString = "rediss://:\(pass)@\(hostname)\(databaseSuffix):\(port)"
            case let (pass?, .disabled):
                urlString = "redis://:\(pass)@\(hostname)\(databaseSuffix):\(port)"
            case (.none, .enabled), (.none, .insecure):
                urlString = "rediss://\(hostname)\(databaseSuffix):\(port)"
            case (.none, .disabled):
                urlString = "redis://\(hostname)\(databaseSuffix):\(port)"
        }

        guard let url = URL(string: urlString) else {
            throw RedisError(
                identifier: "URL creation",
                reason: "Redis client config could not be transformed to url.")
        }

        return url
    }
}
