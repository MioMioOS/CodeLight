import Testing
import Foundation
@testable import CodeLightSocket

@Test func testServerUpdateDecodable() throws {
    let json = """
    {"type":"new-message","sessionId":"sess-1","message":{"id":"msg-1","seq":1,"content":"encrypted","localId":"local-1"}}
    """
    let data = Data(json.utf8)
    let update = try JSONDecoder().decode(ServerUpdate.self, from: data)
    #expect(update.type == "new-message")
    #expect(update.sessionId == "sess-1")
    #expect(update.message?.seq == 1)
}
