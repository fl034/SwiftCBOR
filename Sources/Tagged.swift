import Foundation

struct TaggedUtf8String: Codable {
    let tag: UInt64
    let value: String
}

struct TaggedByteString: Codable {
    let tag: UInt64
    let value: [UInt8]
}
