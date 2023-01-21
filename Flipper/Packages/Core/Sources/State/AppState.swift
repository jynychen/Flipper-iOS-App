import Inject
import Analytics
import Peripheral
import Foundation
import Combine
import Logging

@MainActor
public class AppState: ObservableObject {
    @Published public var status: DeviceStatus = .noDevice

    @Published public var emulate: EmulateModel = .init()
    @Published public var readerAttack: ReaderAttackModel = .init()

    public init() {
        logger.info("app version: \(Bundle.fullVersion)")
        logger.info("log level: \(UserDefaultsStorage.shared.logLevel)")
    }
}
