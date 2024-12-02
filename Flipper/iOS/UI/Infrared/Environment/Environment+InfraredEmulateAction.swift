import Core
import SwiftUI

extension EnvironmentValues {
    @Entry var emulateAction: (
        InfraredKeyID,
        Emulate.EmulateType
    ) -> Void = { _, _ in }
}
