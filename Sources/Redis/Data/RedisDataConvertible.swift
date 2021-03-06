import Foundation

/// Capable of converting to / from `RedisData`.
public protocol RedisDataConvertible {
    /// Create an instance of `Self` from `RedisData`.
    static func convertFromRedisData(_ data: RedisData) throws -> Self
    
    /// Convert self to `RedisData`.
    func convertToRedisData() throws -> RedisData
}

extension RedisData: RedisDataConvertible {
    /// See `RedisDataConvertible`.
    public func convertToRedisData() throws -> RedisData {
        return self
    }

    /// See `RedisDataConvertible`.
    public static func convertFromRedisData(_ data: RedisData) throws -> RedisData {
        return data
    }
}

extension String: RedisDataConvertible {
    /// See `RedisDataConvertible`.
    public static func convertFromRedisData(_ data: RedisData) throws -> String {
        guard let string = data.string else {
            throw RedisError(identifier: "string", reason: "Could not convert to string: \(data).")
        }
        return string
    }

    /// See `RedisDataConvertible`.
    public func convertToRedisData() throws -> RedisData {
        return .bulkString(Data(self.utf8))
    }
}

extension FixedWidthInteger {
    /// See `RedisDataConvertible`.
    public static func convertFromRedisData(_ data: RedisData) throws -> Self {
        guard let int = data.int else {
            guard let string = data.string else {
                throw RedisError(identifier: "string", reason: "Could not convert to string: \(data)")
            }

            guard let int = Self(string) else {
                throw RedisError(identifier: "int", reason: "Could not convert to int: \(data)")
            }

            return int
        }

        return Self(int)
    }

    /// See `RedisDataConvertible`.
    public func convertToRedisData() throws -> RedisData {
        return .bulkString(Data(self.description.utf8))
    }
}

extension Int: RedisDataConvertible {}
extension Int8: RedisDataConvertible {}
extension Int16: RedisDataConvertible {}
extension Int32: RedisDataConvertible {}
extension Int64: RedisDataConvertible {}
extension UInt: RedisDataConvertible {}
extension UInt8: RedisDataConvertible {}
extension UInt16: RedisDataConvertible {}
extension UInt32: RedisDataConvertible {}
extension UInt64: RedisDataConvertible {}

extension Double: RedisDataConvertible {
    /// See `RedisDataConvertible`.
    public static func convertFromRedisData(_ data: RedisData) throws -> Double {
        guard let string = data.string else {
            throw RedisError(identifier: "string", reason: "Could not convert to string: \(data).")
        }

        guard let float = Double(string) else {
            throw RedisError(identifier: "dobule", reason: "Could not convert to double: \(data).")
        }

        return float
    }

    /// See `RedisDataConvertible`.
    public func convertToRedisData() throws -> RedisData {
        return .bulkString(Data(self.description.utf8))
    }
}

extension Float: RedisDataConvertible {
    /// See `RedisDataConvertible`.
    public static func convertFromRedisData(_ data: RedisData) throws -> Float {
        guard let string = data.string else {
            throw RedisError(identifier: "string", reason: "Could not convert to string: \(data).")
        }

        guard let float = Float(string) else {
            throw RedisError(identifier: "float", reason: "Could not convert to float: \(data).")
        }

        return float
    }

    /// See `RedisDataConvertible`.
    public func convertToRedisData() throws -> RedisData {
        return .bulkString(Data(self.description.utf8))
    }
}

extension Data: RedisDataConvertible {
    /// See `RedisDataConvertible`.
    public static func convertFromRedisData(_ data: RedisData) throws -> Data {
        guard let theData = data.data else {
            throw RedisError(identifier: "data", reason: "Could not convert to data: \(data).")
        }
        return theData
    }

    /// See `RedisDataConvertible`.
    public func convertToRedisData() throws -> RedisData {
        return .bulkString(self)
    }
}

extension Array: RedisDataConvertible where Element: RedisDataConvertible {
    /// See `RedisDataConvertible`.
    public static func convertFromRedisData(_ data: RedisData) throws -> Array<Element> {
        guard let array = data.array else {
            throw RedisError(identifier: "array", reason: "Could not convert to array: \(data).")
        }
        return try array.map { try Element.convertFromRedisData($0) }
    }

    /// See `RedisDataConvertible`.
    public func convertToRedisData() throws -> RedisData {
        let dataArray = try map { try $0.convertToRedisData() }
        return RedisData.array(dataArray)
    }
}
