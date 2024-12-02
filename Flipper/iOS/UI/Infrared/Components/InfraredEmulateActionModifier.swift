import Core
import SwiftUI

private struct EmulateActionModifier: ViewModifier {
    @EnvironmentObject private var emulate: Emulate
    @EnvironmentObject private var device: Device

    @Environment(\.emulateAction) private var action

    @State private var isPressed = false
    let keyID: InfraredKeyID

    func onTap() {
        guard let flipper = device.flipper else { return }

        if flipper.hasSingleEmulateSupport {
            action(keyID, Emulate.EmulateType.single)
        } else {
            onPress()
            onRelease()
        }
    }

    func onPress() {
        action(keyID, Emulate.EmulateType.continuous)
    }

    func onRelease() {
        emulate.stopEmulate()
    }

    func body(content: Content) -> some View {
        content
            .onTapGesture {
                onTap()
            }
            .gesture(
                LongPressGesture()
                    .onEnded { _ in
                        onPress()
                    }.sequenced(before: DragGesture(minimumDistance: 0)
                        .onEnded { _ in
                            onRelease()
                        }
                    )
            )
    }
}

extension View {
    func emulatable(keyID: InfraredKeyID) -> some View {
        self.modifier(EmulateActionModifier(keyID: keyID))
    }
}
