import Inject
import Peripheral
import Combine
import Logging

import struct Foundation.UUID

class PairedFlipper: PairedDevice, ObservableObject {
    @Inject var storage: DeviceStorage
    @Inject var connector: BluetoothConnector
    private var disposeBag: DisposeBag = .init()

    private var bluetoothStatus: BluetoothStatus = .notReady(.preparing) {
        didSet { didUpdateBluetoothStatus() }
    }

    var session: Session = ClosedSession.shared

    var flipper: SafePublisher<Flipper?> { _flipper.eraseToAnyPublisher() }
    private var _flipper: SafeValueSubject<Flipper?> = .init(nil)

    private var infoBag: AnyCancellable?
    private var bluetoothPeripheral: BluetoothPeripheral? {
        didSet {
            guard let peripheral = bluetoothPeripheral else {
                session = ClosedSession.shared
                return
            }
            if oldValue == nil {
                restartSession(with: peripheral)
            }

            peripheralDidChange()
        }
    }

    init() {
        _flipper.value = storage.flipper

        connector.status
            .assign(to: \.bluetoothStatus, on: self)
            .store(in: &disposeBag)

        connector.connected
            .map { $0.first }
            .assign(to: \.bluetoothPeripheral, on: self)
            .store(in: &disposeBag)
    }

    func didUpdateBluetoothStatus() {
        if bluetoothStatus == .ready {
            connect()
        }
    }

    func peripheralDidChange() {
        peripheralDidUpdate()
        subscribeToUpdates()
    }

    func peripheralDidUpdate() {
        if let peripheral = bluetoothPeripheral {
            _flipper.value = _init(peripheral)
            storage.flipper = _init(peripheral)
        }
    }

    func restartSession(with peripheral: BluetoothPeripheral) {
        let backup = session
        session = FlipperSession(peripheral: peripheral)
        session.onScreenFrame = backup.onScreenFrame
        session.onAppStateChanged = backup.onAppStateChanged
    }

    func subscribeToUpdates() {
        infoBag = bluetoothPeripheral?.info
            .sink { [weak self] in
                self?.peripheralDidUpdate()
            }
    }

    func connect() {
        if let flipper = _flipper.value {
            connector.connect(to: flipper.id)
        }
    }

    func disconnect() {
        if let peripheral = bluetoothPeripheral {
            connector.disconnect(from: peripheral.id)
        }
    }

    func forget() {
        disconnect()
        _flipper.value = nil
        storage.flipper = nil
        bluetoothPeripheral = nil
    }
}

extension PairedFlipper {
    public func updateStorageInfo(_ storageInfo: Flipper.StorageInfo) {
        _flipper.value?.storage = storageInfo
        storage.flipper = _flipper.value
    }
}

fileprivate extension PairedFlipper {
    // TODO: Move to factory, store all discovered services
    func _init(_ bluetoothPeripheral: BluetoothPeripheral) -> Flipper {
        // we don't have color on connect
        // so we have to copy initial value
        var flipper = Flipper(bluetoothPeripheral)
        if let color = _flipper.value?.color {
            flipper.color = color
        }
        if let storage = _flipper.value?.storage {
            flipper.storage = storage
        }
        return flipper
    }
}
