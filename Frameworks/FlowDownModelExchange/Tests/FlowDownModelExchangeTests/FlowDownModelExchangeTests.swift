@testable import FlowDownModelExchange
import Foundation
import Testing

@Test func publicKeyRoundTrip() throws {
    let keyPair = ModelExchangeKeyPair()
    let encoded = keyPair.encodedPublicKey
    #expect(ModelExchangePublicKey(encoded: encoded) != nil)
    let restored = ModelExchangePublicKey(encoded: encoded)!
    #expect(restored.signing == keyPair.publicKey.signing)
    #expect(restored.agreement == keyPair.publicKey.agreement)
}

@Test func signedRequestVerifies() throws {
    let keyPair = ModelExchangeKeyPair()
    let builder = ModelExchangeRequestBuilder(callbackScheme: "thirdparty", keyPair: keyPair)
    let request = try builder.makeExchangeURL(
        session: "session-1",
        appName: "Tester",
        reason: "Need a model",
        capabilities: [.audio, .developerRole],
        multipleSelection: false,
        timestamp: Date(timeIntervalSince1970: 1_700_000_000),
    )

    var components = URLComponents(url: request.url, resolvingAgainstBaseURL: false)!
    components.queryItems = components.queryItems?.filter { $0.name != "sig" }
    let path = ModelExchangeAPI.canonicalPath(from: components.url!)
    let signature = request.headers[ModelExchangeAPI.signatureHeader]
    #expect(signature != nil)
    let pub = keyPair.publicKey.signingKey
    #expect(pub != nil)
    #expect(ModelExchangeAPI.verify(path: path, signature: signature!, publicKey: pub!))
}

@Test func encryptDecryptRoundTrip() throws {
    let requester = ModelExchangeKeyPair()
    let peer = requester.publicKey
    let plain = Data("super-secret-model".utf8)
    let payload = try ModelExchangeCrypto.encrypt(plain, for: peer, session: "session-abc")
    let recovered = try ModelExchangeCrypto.decrypt(payload, with: requester)
    #expect(recovered == plain)
}
