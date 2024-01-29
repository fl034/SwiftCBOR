import Foundation

public struct TaggedUtf8String: Codable {
    public let tag: UInt64
    public let value: String
    
    public init(tag: UInt64, value: String) {
        self.tag = tag
        self.value = value
    }
}

public struct TaggedByteString: Codable {
    public let tag: UInt64
    public let value: [UInt8]
    
    public init(tag: UInt64, value: [UInt8]) {
        self.tag = tag
        self.value = value
    }
}
