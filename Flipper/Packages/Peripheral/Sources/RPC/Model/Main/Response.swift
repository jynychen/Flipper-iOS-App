import Foundation
import SwiftProtobuf

// swiftlint:disable nesting

public enum Response: Equatable {
    case ok
    case error(String)
    case system(System)
    case storage(Storage)

    public enum System: Equatable {
        case ping([UInt8])
        case info(String, String)
        case dateTime(Date)
        case update(Update)

        public enum Update: Equatable {
            case ok
            case manifestPathInvalid
            case manifestFolderNotFound
            case manifestInvalid
            case stageMissing
            case stageIntegrityError
            case manifestPointerError
            case targetMismatch
            case unknown(Int)
        }
    }

    public enum Storage: Equatable {
        case info(StorageSpace)
        case list([Element])
        case stat(Int)
        case file([UInt8])
        case hash(String)
    }
}

extension Response {
    init(decoding main: PB_Main) throws {
        guard main.commandStatus == .ok else {
            throw Error(main.commandStatus)
        }

        guard case let .some(content) = main.content else {
            self = .ok
            return
        }

        self.init(decoding: content)
    }
}

extension Response {
    // swiftlint:disable cyclomatic_complexity
    init(decoding content: PB_Main.OneOf_Content) {
        switch content {
        // Empty
        case .empty(let response):
            self.init(decoding: response)
        // System
        case .systemPingResponse(let response):
            self.init(decoding: response)
        case .systemDeviceInfoResponse(let response):
            self.init(decoding: response)
        case .systemGetDatetimeResponse(let response):
            self.init(decoding: response)
        case .systemUpdateResponse(let response):
            self.init(decoding: response)
        // Storage
        case .storageInfoResponse(let response):
            self.init(decoding: response)
        case .storageListResponse(let response):
            self.init(decoding: response)
        case .storageStatResponse(let response):
            self.init(decoding: response)
        case .storageReadResponse(let response):
            self.init(decoding: response)
        case .storageMd5SumResponse(let response):
            self.init(decoding: response)
        // Not implemented
        default:
            fatalError("unhandled response")
        }
    }

    init(decoding response: PB_Empty) {
        self = .ok
    }

    init(decoding response: PBSystem_PingResponse) {
        self = .system(.ping(.init(response.data)))
    }

    init(decoding response: PBSystem_DeviceInfoResponse) {
        self = .system(.info(response.key, response.value))
    }

    init(decoding response: PBSystem_GetDateTimeResponse) {
        self = .system(.dateTime(.init(response.datetime)))
    }

    init(decoding response: PBSystem_UpdateResponse) {
        self = .system(.update(.init(response.code)))
    }

    init(decoding response: PBStorage_InfoResponse) {
        self = .storage(.info(.init(response)))
    }

    init(decoding response: PBStorage_ListResponse) {
        self = .storage(.list(.init(response.file.map(Element.init))))
    }

    init(decoding response: PBStorage_StatResponse) {
        self = .storage(.stat(Int(response.file.size)))
    }

    init(decoding response: PBStorage_ReadResponse) {
        self = .storage(.file(.init(response.file.data)))
    }

    init(decoding response: PBStorage_Md5sumResponse) {
        self = .storage(.hash(response.md5Sum))
    }
}

extension Response.System.Update {
    init(_ code: PBSystem_UpdateResponse.UpdateResultCode) {
        switch code {
        case .ok: self = .ok
        case .manifestPathInvalid: self = .manifestPathInvalid
        case .manifestFolderNotFound: self = .manifestFolderNotFound
        case .manifestInvalid: self = .manifestInvalid
        case .stageMissing: self = .stageMissing
        case .stageIntegrityError: self = .stageIntegrityError
        case .manifestPointerError: self = .manifestPointerError
        case .targetMismatch: self = .targetMismatch
        case .UNRECOGNIZED(let code): self = .unknown(code)
        }
    }
}

extension Response: CustomStringConvertible {
    public var description: String {
        switch self {
        case .ok: return "ok"
        case .error(let error): return "error(\(error))"
        case .system(let system): return "system(\(system))"
        case .storage(let storage): return "storage(\(storage))"
        }
    }
}

extension Response.System: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .ping(bytes): return "ping(\(bytes.count) bytes)"
        case let .info(key, value): return "info(\(key): \(value))"
        case let .dateTime(date): return "dateTime(\(date))"
        case let .update(update): return "update(\(update))"
        }
    }
}

extension Response.Storage: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .info(space): return "info(\(space))"
        case let .list(element): return "list(\(element))"
        case let .stat(size): return "stat(\(size))"
        case let .file(bytes): return "file(\(bytes.count) bytes)"
        case let .hash(hash): return "hash(\(hash))"
        }
    }
}
