import Catalog
import Peripheral

import Logging
import Combine
import Foundation

@MainActor
public class Applications: ObservableObject {
    public typealias Category = Catalog.Category
    public typealias Application = Catalog.Application
    public typealias ApplicationInfo = Catalog.ApplicationInfo

    private var categories: [Category] = []
    @Published public var manifests: [Application.ID: Manifest] = [:]
    @Published public var statuses: [Application.ID: ApplicationStatus] = [:]

    public var outdatedCount: Int {
        statuses
            .map { $0.value }
            .filter { $0 == .outdated }
            .count
    }

    public enum SortOption: String, CaseIterable {
        case newUpdates = "New Updates"
        case newReleases = "New Releases"
        case oldUpdates = "Old Updates"
        case oldReleases = "Old Releases"

        public static var `default`: SortOption { .newUpdates }
    }

    public enum APIError: Swift.Error {
        case noInternet
    }

    public enum Error: Swift.Error {
        case unknownSDK
    }

    private var rpc: RPC { pairedDevice.session }
    @Published private var flipper: Flipper?
    private var cancellables = [AnyCancellable]()


    private let catalog: CatalogService
    private let pairedDevice: PairedDevice

    public init(catalog: CatalogService, pairedDevice: PairedDevice) {
        self.catalog = catalog
        self.pairedDevice = pairedDevice

        subscribeToPublishers()
    }

    func subscribeToPublishers() {
        pairedDevice.flipper
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self else { return }
                let oldValue = self.flipper
                self.flipper = newValue
                self.onFlipperChanged(oldValue)
            }
            .store(in: &cancellables)
    }

    public struct DeviceInfo {
        let target: String
        let api: String
    }

    @Published public var deviceInfo: DeviceInfo?
    @Published public var isOutdatedDevice: Bool = false

    func onFlipperChanged(_ oldValue: Flipper?) {
        if oldValue?.state != .connected, flipper?.state == .connected {
            guard flipper?.hasAPIVersion == true else {
                isOutdatedDevice = true
                return
            }
            Task {
                manifests = try await _loadManifests()
                deviceInfo = try await getDeviceInfo()
            }
        } else if oldValue?.state == .connected, flipper?.state != .connected {
            isOutdatedDevice = false
            deviceInfo = nil
            manifests = [:]
            statuses = [:]
        }
    }

    private func getDeviceInfo() async throws -> DeviceInfo {
        let target = try await getFlipperTarget()
        let api = try await getFlipperAPI()
        return .init(target: target, api: api)
    }

    private func demoDelay() async {
        try? await Task.sleep(seconds: 1)
    }

    public func install(_ id: Application.ID) async {
        do {
            statuses[id] = .installing(0)
            try await _install(id) { progress in
                Task {
                    statuses[id] = .installing(progress)
                }
            }
            statuses[id] = .installed
        } catch {
            logger.error("install app: \(error)")
        }
    }

    public func update(_ id: Application.ID) async {
        do {
            statuses[id] = .updating(0)
            try await _install(id) { progress in
                Task {
                    statuses[id] = .updating(progress)
                }
            }
            statuses[id] = .installed
        } catch {
            logger.error("update app: \(error)")
        }
    }

    public func update(_ ids: [Application.ID]) async {
        for id in ids {
            statuses[id] = .updating(0)
        }
        for id in ids {
            await update(id)
        }
    }

    public func delete(_ id: Application.ID) async {
        do {
            try await _delete(id)
            statuses[id] = nil
        } catch {
            logger.error("delete app: \(error)")
        }
    }

    public func category(for application: Application) -> Category? {
        category(categoryID: application.categoryId)
    }


    public func category(for application: ApplicationInfo) -> Category? {
        application.categoryId.isEmpty
            ? category(installedID: application.id)
            : category(categoryID: application.categoryId)
    }

    private func category(categoryID id: String) -> Category? {
        return categories.first { $0.id == id }
    }

    private func category(installedID id: Application.ID) -> Category? {
        guard let manifest = manifests[id] else {
            return nil
        }
        let parts = manifest.path.split(separator: "/")
        guard parts.count == 4 else {
            return nil
        }
        let name = String(parts[2])
        if let category = categories.first(where: { $0.name == name }) {
            return category
        } else {
            return .init(
                id: "",
                priority: 0,
                name: name,
                color: "",
                icon: "https://null",
                applications: 0)
        }
    }

    private func getFlipperTarget() async throws -> String {
        var target: String = ""
        for try await property in rpc.property("devinfo.hardware.target") {
            target = property.value
        }
        return "f\(target)"
    }

    private func getFlipperAPI() async throws -> String {
        var major: String = "0"
        var minor: String = "0"
        for try await property in rpc.property("devinfo.firmware.api") {
            switch property.key {
            case "firmware.api.major": major = property.value
            case "firmware.api.minor": minor = property.value
            default: logger.error("unexpected api property")
            }
        }
        return "\(major).\(minor)"
    }

    private func handlingWebErrors<T>(
        _ body: () async throws -> T
    ) async rethrows -> T {
        do {
            return try await body()
        } catch let error as Catalog.CatalogError where error.isUnknownSDK {
            logger.error("unknown sdk")
            throw Error.unknownSDK
        } catch let error as URLError {
            logger.error("web: \(error)")
            throw APIError.noInternet
        } catch {
            logger.error("web: \(error)")
            throw error
        }
    }

    public func loadTopApp() async throws -> ApplicationInfo {
        try await handlingWebErrors {
            _ = try await loadCategories()
            guard let app = try await catalog.featured().get().first else {
                throw APIError.noInternet
            }
            return app
        }
    }

    private var categoriesTask: Task<[Category], Swift.Error>?

    public func loadCategories() async throws -> [Category] {
        if let task = categoriesTask {
            return try await task.value
        } else {
            let task = Task<[Category], Swift.Error> {
                categories = try await handlingWebErrors {
                    try await catalog
                        .categories()
                        .target(deviceInfo?.target)
                        .api(deviceInfo?.api)
                        .get()
                }
                categoriesTask = nil
                return categories
            }
            return try await task.value
        }
    }

    public func loadApplications(
        for category: Category? = nil,
        sort sortOption: SortOption = .newUpdates,
        skip: Int = 0,
        take: Int = 7
    ) async throws -> [ApplicationInfo] {
        try await handlingWebErrors {
            try await catalog
                .applications()
                .category(category?.id)
                .sort(by: .init(source: sortOption))
                .order(.init(source: sortOption))
                .target(deviceInfo?.target)
                .api(deviceInfo?.api)
                .skip(skip)
                .take(take)
                .get()
        }
    }

    public func loadApplication(id: String) async throws -> Application {
        try await handlingWebErrors {
            try await catalog
                .application(uid: id)
                .target(deviceInfo?.target)
                .api(deviceInfo?.api)
                .get()
        }
    }

    public func search(for string: String) async throws -> [ApplicationInfo] {
        try await handlingWebErrors {
            try await catalog
                .applications()
                .filter(string)
                .target(deviceInfo?.target)
                .api(deviceInfo?.api)
                .take(500)
                .get()
        }
    }

    public func loadInstalled() async throws -> [ApplicationInfo] {
        let installed = manifests.compactMap {
            ApplicationInfo($0.value)
        }
        guard let deviceInfo else {
            installed.forEach { statuses[$0.id] = .installed }
            return installed
        }
        do {
            var available: ApplicationsRequest.Result = []
            while available.count < installed.count {
                let slice = installed.dropFirst(available.count).prefix(42)

                let loaded = try await catalog
                    .applications()
                    .uids(slice.map { $0.id })
                    .target(deviceInfo.target)
                    .api(deviceInfo.api)
                    .take(slice.count)
                    .get()

                available.append(contentsOf: loaded)
            }

            for application in available {
                statuses[application.id] = status(for: application)
            }
        } catch {
            logger.error("load installed: \(error)")
        }
        return installed
    }

    public enum ApplicationStatus: Equatable {
        case installing(Double)
        case updating(Double)
        case notInstalled
        case installed
        case outdated
        case building
    }

    private func status(
        for application: ApplicationInfo
    ) -> ApplicationStatus {
        guard let manifest = manifests[application.id] else {
            return .notInstalled
        }
        guard
            manifest.versionUID == application.current.id,
            manifest.buildAPI == deviceInfo?.api
        else {
            return application.current.status == .ready
                ? .outdated
                : .building
        }
        return .installed
    }

    public func report(
        _ application: Application,
        description: String
    ) async throws {
        try await catalog.report(uid: application.id, description: description)
    }
}

extension Catalog.Category: Identifiable {}
extension Catalog.Application: Identifiable {}
extension Catalog.ApplicationInfo: Identifiable {}

extension Catalog.SortBy {
    init(source: Applications.SortOption) {
        switch source {
        case .newUpdates, .oldUpdates: self = .updated
        case .newReleases, .oldReleases: self = .created
        }
    }
}

extension Catalog.SortOrder {
    init(source: Applications.SortOption) {
        switch source {
        case .newUpdates, .newReleases: self = .desc
        case .oldUpdates, .oldReleases: self = .asc
        }
    }
}

// MARK: MVP0 🙈

fileprivate extension Applications {
    var tempPath: Path { "/ext/.tmp" }
    var iosTempPath: Path { "\(tempPath)/ios" }

    var appsPath: Path { "/ext/apps" }
    var manifestsPath: Path { "/ext/apps_manifests" }

    func _install(
        _ id: Application.ID,
        progress: (Double) -> Void
    ) async throws {
        let application = try await loadApplication(id: id)

        guard let deviceInfo else {
            return
        }

        let data = try await catalog.build(forVersionID: application.current.id)
            .target(deviceInfo.target)
            .api(deviceInfo.api)
            .get()

        try? await rpc.createDirectory(at: tempPath)
        try? await rpc.createDirectory(at: iosTempPath)

        guard let category = category(categoryID: application.categoryId) else {
            return
        }
        let appCategoryPath: Path = "\(appsPath)/\(category.name)"

        try? await rpc.createDirectory(at: appsPath)
        try? await rpc.createDirectory(at: appCategoryPath)
        try? await rpc.createDirectory(at: manifestsPath)

        let appName = "\(application.alias).fap"
        let manifestName = "\(application.alias).fim"

        let appTempPath: Path = "\(iosTempPath)/\(appName)"
        let manifestTempPath: Path = "\(iosTempPath)/\(manifestName)"

        let appPath: Path = "\(appCategoryPath)/\(appName)"
        let manifestPath: Path = "\(manifestsPath)/\(manifestName)"

        try await rpc.writeFile(
            at: appTempPath,
            bytes: .init(data)
        ) { writeProgress in
            progress(writeProgress)
        }

        guard case .url(let iconURL) = application.current.icon else {
            return
        }
        let (icon, _) = try await URLSession.shared.data(from: iconURL)

        guard let build = application.current.build else {
            return
        }

        let manifest = Applications.Manifest(
            fullName: application.current.name,
            icon: icon,
            buildAPI: build.sdk.api,
            uid: application.id,
            versionUID: application.current.id,
            path: appPath.string)

        let manifestString = try FFFEncoder.encode(manifest)

        try await rpc.writeFile(
            at: manifestTempPath,
            string: manifestString
        ) { progress in
        }

        try await rpc.moveFile(from: appTempPath, to: appPath)
        try await rpc.moveFile(from: manifestTempPath, to: manifestPath)

        manifests[application.id] = manifest
    }

    func _delete(_ id: Application.ID) async throws {
        guard let manifest = manifests[id] else {
            return
        }
        guard let alias = manifest.alias else {
            return
        }

        let appPath: Path = .init(string: manifest.path)
        let manifestPath: Path = "\(manifestsPath)/\(alias).fim"

        try await rpc.deleteFile(at: appPath)
        try await rpc.deleteFile(at: manifestPath)

        manifests[id] = nil
    }
}

extension Applications.Manifest {
    var alias: String? {
        guard
            let name = path.split(separator: "/").last,
            let alias = name.split(separator: ".").first
        else {
            return nil
        }
        return .init(alias)
    }
}

extension Applications {
    func _loadManifests() async throws -> [Application.ID: Manifest] {
        var result: [Application.ID: Manifest] = [:]
        guard
            let listing = try? await rpc.listDirectory(at: manifestsPath)
        else {
            return result
        }
        for file in listing.files {
            do {
                let manifest = try await _loadManifest(file)
                result[manifest.uid] = manifest
            } catch {
                logger.error("load manifest: \(error)")
            }
        }
        return result
    }

    func _loadManifest(_ name: String) async throws -> Manifest {
        let data = try await rpc.readFile(at: "\(manifestsPath)/\(name)")
        let manifest = try FFFDecoder.decode(Manifest.self, from: data)
        return manifest
    }
}

extension Flipper {
    var hasAPIVersion: Bool {
        guard
            let protobuf = information?.protobufRevision,
            protobuf >= .v0_17
        else {
            return false
        }
        return true
    }
}
