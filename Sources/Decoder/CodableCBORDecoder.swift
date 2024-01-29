import Foundation

final public class CodableCBORDecoder {
    public var useStringKeys: Bool = false
    public var dateStrategy: DateStrategy = .taggedAsEpochTimestamp

    struct _Options {
        let useStringKeys: Bool
        let dateStrategy: DateStrategy

        init(useStringKeys: Bool = false, dateStrategy: DateStrategy = .taggedAsEpochTimestamp) {
            self.useStringKeys = useStringKeys
            self.dateStrategy = dateStrategy
        }

        func toCBOROptions() -> CBOROptions {
            return CBOROptions(useStringKeys: self.useStringKeys, dateStrategy: self.dateStrategy)
        }
    }

    var options: _Options {
        return _Options(useStringKeys: self.useStringKeys, dateStrategy: self.dateStrategy)
    }

    public init() {}

    public var userInfo: [CodingUserInfoKey : Any] = [:]

    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        return try decode(type, from: ArraySlice([UInt8](data)))
    }

    public func decode<T: Decodable>(_ type: T.Type, from data: ArraySlice<UInt8>) throws -> T {
        let decoder = _CBORDecoder(data: data, options: self.options)
        decoder.userInfo = self.userInfo
        if type == Date.self {
            guard let cbor = try? CBORDecoder(input: [UInt8](data), options: self.options.toCBOROptions()).decodeItem(),
                case .date(let date) = cbor
            else {
                let context = DecodingError.Context(codingPath: [], debugDescription: "Unable to decode data for Date")
                throw DecodingError.dataCorrupted(context)
            }
            return date as! T
        } else if type == Data.self {
            guard let cbor = try? CBORDecoder(input: [UInt8](data), options: self.options.toCBOROptions()).decodeItem(),
                case .byteString(let data) = cbor
            else {
                let context = DecodingError.Context(codingPath: [], debugDescription: "Unable to decode data for Data")
                throw DecodingError.dataCorrupted(context)
            }
            return Data(data) as! T
        }
        
        // Tagged
        if let cbor = try? CBORDecoder(input: [UInt8](data), options: self.options.toCBOROptions()).decodeItem(),
           case let .tagged(tag, innerCbor) = cbor {
            switch innerCbor {
            case .unsignedInt(let uInt64):
                break
            case .negativeInt(let uInt64):
                break
            case .byteString(let array):
                return try unwrap(
                    TaggedByteString(tag: tag.rawValue, value: array) as? T,
                    orThrow: DecodingError.typeMismatch(type, .init(codingPath: [],  debugDescription: "Wrong type"))
                )
            case .utf8String(let string):
                return try unwrap(
                    TaggedUtf8String(tag: tag.rawValue, value: string) as? T,
                    orThrow: DecodingError.typeMismatch(type, .init(codingPath: [],  debugDescription: "Wrong type"))
                )
            case .array(let array):
                break
            case .map(let dictionary):
                break
            case.tagged(let tag, let cBOR):
                break
            case .simple(let uInt8):
                break
            case .boolean(let bool):
                break
            case .null:
                break
            case .undefined:
                break
            case .half(let float32):
                break
            case .float(let float32):
                break
            case .double(let float64):
                break
            case .break:
                break
            case .date(let date):
                break
            }
        }
        
        return try T(from: decoder)
    }

    func setOptions(_ newOptions: _Options) {
        self.useStringKeys = newOptions.useStringKeys
        self.dateStrategy = newOptions.dateStrategy
    }
}

final class _CBORDecoder {
    var codingPath: [CodingKey] = []

    var userInfo: [CodingUserInfoKey : Any] = [:]

    var container: CBORDecodingContainer?
    fileprivate var data: ArraySlice<UInt8>

    let options: CodableCBORDecoder._Options

    init(data: ArraySlice<UInt8>, options: CodableCBORDecoder._Options) {
        self.data = data
        self.options = options
    }
}

extension _CBORDecoder: Decoder {
    func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        try ensureMap(self.data.first, keyType: Key.self)

        let container = KeyedContainer<Key>(data: self.data, codingPath: self.codingPath, userInfo: self.userInfo, options: self.options)
        self.container = container

        return KeyedDecodingContainer(container)
    }

    func unkeyedContainer() throws -> UnkeyedDecodingContainer {
        try ensureArray(self.data.first)

        let container = UnkeyedContainer(data: self.data, codingPath: self.codingPath, userInfo: self.userInfo, options: self.options)
        self.container = container

        return container
    }

    func singleValueContainer() throws -> SingleValueDecodingContainer {
        let container = SingleValueContainer(data: self.data, codingPath: self.codingPath, userInfo: self.userInfo, options: self.options)
        self.container = container

        return container
    }

    func ensureMap<Key: CodingKey>(_ initialByte: UInt8?, keyType: Key.Type) throws {
        switch initialByte {
        case .some(0xa0...0xbf):
            // all good, continue
            return
        case nil:
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Unexpected end of data"
            )
            throw DecodingError.dataCorrupted(context)
        default:
            let typeDescriptionOfByte = typeDescriptionFromByte(initialByte!) ?? "unknown"
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected map but found \(typeDescriptionOfByte)"
            )
            throw DecodingError.typeMismatch(keyType, context)
        }
    }

    func ensureArray(_ initialByte: UInt8?) throws {
        switch initialByte {
        case .some(0x80...0x9f):
            // all good, continue
            return
        case nil:
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Unexpected end of data"
            )
            throw DecodingError.dataCorrupted(context)
        default:
            let typeDescriptionOfByte = typeDescriptionFromByte(initialByte!) ?? "unknown"
            let context = DecodingError.Context(
                codingPath: self.codingPath,
                debugDescription: "Expected array but found \(typeDescriptionOfByte)"
            )
            throw DecodingError.typeMismatch(Array<Any?>.self, context)
        }
    }
}

protocol CBORDecodingContainer: AnyObject {
    var codingPath: [CodingKey] { get set }

    var userInfo: [CodingUserInfoKey : Any] { get }

    var data: ArraySlice<UInt8> { get set }
    var index: Data.Index { get set }
}

extension CBORDecodingContainer {
    func readByte() throws -> UInt8 {
        return try read(1).first!
    }

    func read(_ length: Int) throws -> Data {
        let nextIndex = self.index.advanced(by: length)
        guard nextIndex <= self.data.endIndex else {
            let context = DecodingError.Context(codingPath: self.codingPath, debugDescription: "Unexpected end of data")
            throw DecodingError.dataCorrupted(context)
        }
        defer { self.index = nextIndex }

        return Data(Array(self.data[self.index..<(nextIndex)]))
    }

    func peekByte() throws -> UInt8 {
        return try peek(1).first!
    }

    func peek(_ length: Int) throws -> ArraySlice<UInt8> {
        let nextIndex = self.index.advanced(by: length)
        guard nextIndex <= self.data.endIndex else {
            let context = DecodingError.Context(codingPath: self.codingPath, debugDescription: "Unexpected end of data")
            throw DecodingError.dataCorrupted(context)
        }

        return self.data[self.index..<(nextIndex)]
    }

    func read<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        let stride = MemoryLayout<T>.stride
        let bytes = [UInt8](try read(stride))
        return T(bytes: bytes)
    }
}

func typeDescriptionFromByte(_ byte: UInt8) -> String? {
    switch byte {
    case 0x00...0x1b, 0x20...0x3b: return "integer"
    case 0x40...0x5b, 0x5f: return "byte string"
    case 0x60...0x7b, 0x7f: return "string"
    case 0x80...0x9f: return "array"
    case 0xa0...0xbf: return "map"
    case 0xc0: return "text-based date/time"
    case 0xc1: return "epoch-based date/time"
    case 0xc2...0xdb: return "unspecified tagged value"
    case 0xf4, 0xf5: return "boolean"
    case 0xf6: return "null"
    case 0xf8...0xfb: return "float"
    default:
        return nil
    }
}

private func unwrap<T>(_ optional: T?, orThrow error: Error) throws -> T {
    if let optional {
        return optional
    }
    throw error
}
