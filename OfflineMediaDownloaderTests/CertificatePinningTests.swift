import Foundation
import NetworkSecurity
import Testing

// The trust decision for every server-trust challenge. PinningURLSessionDelegate passes its
// inputs to CertificatePinning.disposition and hands the result to URLSession, so these cases
// pin the branch that decides between a pinned connection and a cancelled one.

struct DispositionCase: CustomTestStringConvertible {
  let trustValid: Bool
  let outcome: CertificatePinning.Outcome?
  let enforcesPinning: Bool
  let expected: URLSession.AuthChallengeDisposition

  var testDescription: String {
    "trustValid=\(trustValid) outcome=\(outcome.map { "\($0)" } ?? "nil") enforced=\(enforcesPinning)"
  }
}

private let dispositionCases: [DispositionCase] = [
  // System trust failed: always cancel, whatever the pin state and enforcement.
  DispositionCase(trustValid: false, outcome: nil, enforcesPinning: true, expected: .cancelAuthenticationChallenge),
  DispositionCase(trustValid: false, outcome: nil, enforcesPinning: false, expected: .cancelAuthenticationChallenge),
  DispositionCase(trustValid: false, outcome: .matched, enforcesPinning: true, expected: .cancelAuthenticationChallenge),
  DispositionCase(trustValid: false, outcome: .matched, enforcesPinning: false, expected: .cancelAuthenticationChallenge),
  // Trusted and pinned: proceed.
  DispositionCase(trustValid: true, outcome: .matched, enforcesPinning: true, expected: .useCredential),
  DispositionCase(trustValid: true, outcome: .matched, enforcesPinning: false, expected: .useCredential),
  // Trusted but not pinned: cancel under enforcement, proceed without it.
  DispositionCase(trustValid: true, outcome: .noMatchingKey, enforcesPinning: true, expected: .cancelAuthenticationChallenge),
  DispositionCase(trustValid: true, outcome: .unreadableChain, enforcesPinning: true, expected: .cancelAuthenticationChallenge),
  DispositionCase(trustValid: true, outcome: .noMatchingKey, enforcesPinning: false, expected: .useCredential),
  DispositionCase(trustValid: true, outcome: .unreadableChain, enforcesPinning: false, expected: .useCredential),
  // Trusted with no pin result is treated as a failure, never as a pass.
  DispositionCase(trustValid: true, outcome: nil, enforcesPinning: true, expected: .cancelAuthenticationChallenge),
  DispositionCase(trustValid: true, outcome: nil, enforcesPinning: false, expected: .cancelAuthenticationChallenge),
]

@Suite("Certificate pinning trust decision")
struct CertificatePinningTests {
  @Test("Every trust, pin and enforcement combination maps to the expected disposition", arguments: dispositionCases)
  func dispositionMatchesTable(_ testCase: DispositionCase) {
    let disposition = CertificatePinning.disposition(
      trustValid: testCase.trustValid,
      outcome: testCase.outcome,
      enforcesPinning: testCase.enforcesPinning
    )
    #expect(disposition == testCase.expected)
  }

  @Test("The table covers every outcome under both enforcement settings")
  func tableCoversEveryCombination() {
    let outcomes: [CertificatePinning.Outcome?] = [nil, .matched, .noMatchingKey, .unreadableChain]
    for trustValid in [true, false] {
      for enforcesPinning in [true, false] {
        for outcome in outcomes where trustValid || outcome == nil || outcome == .matched {
          #expect(dispositionCases.contains {
            $0.trustValid == trustValid && $0.outcome == outcome && $0.enforcesPinning == enforcesPinning
          }, "missing trustValid=\(trustValid) outcome=\(String(describing: outcome)) enforced=\(enforcesPinning)")
        }
      }
    }
  }
}
