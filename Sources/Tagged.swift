import Foundation

public struct TaggedUtf8String: Codable, Equatable, Hashable {
    public let tag: UInt64
    public let value: String
    
    public init(tag: UInt64, value: String) {
        self.tag = tag
        self.value = value
    }
    
//    public init(from decoder: Decoder) throws {
//        var container = try decoder.singleValueContainer()
//        self.tag = try container.decode(<#T##type: UInt64.Type##UInt64.Type#>)
//        self.value = try container.decodeIfPresent(String.self) ?? ""
//    }
}

public struct TaggedByteString: Codable, Equatable, Hashable {
    public let tag: UInt64
    public let value: [UInt8]
    
    public init(tag: UInt64, value: [UInt8]) {
        self.tag = tag
        self.value = value
    }
}
