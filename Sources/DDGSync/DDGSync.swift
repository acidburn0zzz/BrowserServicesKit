//
//  DDGSync.swift
//
//  Copyright © 2022 DuckDuckGo. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import Foundation
import Combine
import DDGSyncCrypto
import Common
import os.log

public class DDGSync: DDGSyncing {

    public static let bundle = Bundle.module

    enum Constants {
        //#if DEBUG
        public static let baseUrl = URL(string: "https://dev-sync-use.duckduckgo.com")!
        //#else
        //        public static let baseUrl = URL(string: "https://sync.duckduckgo.com")!
        //#endif
    }

    @Published public private(set) var authState: SyncAuthState
    public var authStatePublisher: AnyPublisher<SyncAuthState, Never> {
        $authState.eraseToAnyPublisher()
    }

    public var account: SyncAccount? {
        try? dependencies.secureStore.account()
    }

    public var scheduler: Scheduling {
        dependencies.scheduler
    }

    public var isInProgressPublisher: AnyPublisher<Bool, Never> {
        isSyncInProgressSubject.eraseToAnyPublisher()
    }

    public weak var dataProvidersSource: DataProvidersSource?

    /// This is the constructor intended for use by app clients.
    public convenience init(dataProvidersSource: DataProvidersSource, errorEvents: EventMapping<SyncError>, log: @escaping @autoclosure () -> OSLog = .disabled) {
        let dependencies = ProductionDependencies(baseUrl: Constants.baseUrl, errorEvents: errorEvents, log: log())
        self.init(dataProvidersSource: dataProvidersSource, dependencies: dependencies)
    }

    public func createAccount(deviceName: String, deviceType: String) async throws {
        guard try dependencies.secureStore.account() == nil else {
            throw SyncError.accountAlreadyExists
        }

        let account = try await dependencies.account.createAccount(deviceName: deviceName, deviceType: deviceType)
        try updateAccount(account)
        scheduler.requestSyncImmediately()
    }

    public func login(_ recoveryKey: SyncCode.RecoveryKey, deviceName: String, deviceType: String) async throws -> [RegisteredDevice] {
        guard try dependencies.secureStore.account() == nil else {
            throw SyncError.accountAlreadyExists
        }

        let result = try await dependencies.account.login(recoveryKey, deviceName: deviceName, deviceType: deviceType)
        try updateAccount(result.account)
        scheduler.requestSyncImmediately()
        return result.devices
    }

    public func remoteConnect() throws -> RemoteConnecting {
        guard try dependencies.secureStore.account() == nil else {
            throw SyncError.accountAlreadyExists
        }
        let info = try dependencies.crypter.prepareForConnect()
        return try dependencies.createRemoteConnector(info)
    }

    public func transmitRecoveryKey(_ connectCode: SyncCode.ConnectCode) async throws {
        guard try dependencies.secureStore.account() != nil else {
            throw SyncError.accountNotFound
        }

        do {
            try await dependencies.createRecoveryKeyTransmitter().send(connectCode)
        } catch {
            try handleUnauthenticated(error)
        }
    }

    public func disconnect() async throws {
        guard let deviceId = try dependencies.secureStore.account()?.deviceId else {
            throw SyncError.accountNotFound
        }
        do {
            try await disconnect(deviceId: deviceId)
            try updateAccount(nil)
        } catch {
            try handleUnauthenticated(error)
        }
    }

    public func disconnect(deviceId: String) async throws {
        guard let token = try dependencies.secureStore.account()?.token else {
            throw SyncError.noToken
        }
        do {
            try await dependencies.account.logout(deviceId: deviceId, token: token)
        } catch {
            try handleUnauthenticated(error)
        }
    }

    public func fetchDevices() async throws -> [RegisteredDevice] {
        guard let account = try dependencies.secureStore.account() else {
            throw SyncError.accountNotFound
        }

        do {
            return try await dependencies.account.fetchDevicesForAccount(account)
        } catch {
            try handleUnauthenticated(error)
        }

        return []
    }

    public func updateDeviceName(_ name: String) async throws -> [RegisteredDevice] {
        guard let account = try dependencies.secureStore.account() else {
            throw SyncError.accountNotFound
        }

        do {
            let result = try await dependencies.account.refreshToken(account, deviceName: name)
            try dependencies.secureStore.persistAccount(result.account)
            return result.devices
        } catch {
            try handleUnauthenticated(error)
        }

        return []
    }

    public func deleteAccount() async throws {
        guard let account = try dependencies.secureStore.account() else {
            throw SyncError.accountNotFound
        }

        do {
            try await dependencies.account.deleteAccount(account)
            try updateAccount(nil)
        } catch {
            try handleUnauthenticated(error)
        }
    }

    // MARK: -

    let dependencies: SyncDependencies

    init(dataProvidersSource: DataProvidersSource, dependencies: SyncDependencies) {
        self.dataProvidersSource = dataProvidersSource
        self.dependencies = dependencies

        let account = try? dependencies.secureStore.account()
        self.authState = account?.state ?? .inactive
        try? updateAccount(account)
    }

    private func updateAccount(_ account: SyncAccount? = nil) throws {
        guard let account, account.state != .inactive else {
            dependencies.scheduler.isEnabled = false
            startSyncCancellable?.cancel()
            syncQueueCancellable?.cancel()
            syncQueue = nil
            authState = .inactive
            try dependencies.secureStore.removeAccount()
            return
        }

        assert(syncQueue == nil, "Sync queue is not nil")

        let providers = dataProvidersSource?.makeDataProviders() ?? []
        let syncQueue = SyncQueue(dataProviders: providers, dependencies: dependencies)

        let previousState = try dependencies.secureStore.account()?.state
        if previousState == nil || previousState ==  .inactive {
            try syncQueue.prepareForFirstSync()
        }
        try dependencies.secureStore.persistAccount(account)
        authState = account.state

        syncQueueCancellable = syncQueue.isSyncInProgressPublisher
            .sink(receiveCompletion: { [weak self] _ in
                self?.isSyncInProgressSubject.send(false)
            }, receiveValue: { [weak self] isInProgress in
                self?.isSyncInProgressSubject.send(isInProgress)
            })

        startSyncCancellable = dependencies.scheduler.startSyncPublisher
            .flatMap(maxPublishers: .max(1)) { [weak self] in
                guard let self else {
                    return Future<Void, Never> { promise in
                        promise(.success(()))
                    }
                }
                return self.startSync()
            }
            .sink {}

        dependencies.scheduler.isEnabled = true
        self.syncQueue = syncQueue
    }

    private func startSync() -> Future<Void, Never> {
        Future { promise in
            Task { [weak self] in
                defer { promise(.success(())) }
                guard let self else {
                    return
                }

                if self.authState == .active {
                    await self.syncQueue?.startSync()
                } else {
                    await self.syncQueue?.startFirstSync()
                    if let account = try? self.dependencies.secureStore.account()?.updatingState(.active) {
                        try? self.dependencies.secureStore.persistAccount(account)
                        self.authState = .active
                    }
                    await self.syncQueue?.startSync()
                }
            }
        }
    }

    private func handleUnauthenticated(_ error: Error) throws {
        guard let syncError = error as? SyncError,
              case .unexpectedStatusCode(let statusCode) = syncError,
              statusCode == 401 else {
            throw error
        }

        do {
            try updateAccount(nil)
            dependencies.errorEvents.fire(syncError)
        } catch {
            os_log(.error, log: dependencies.log, "Failed to delete account upon unauthenticated server response: %{public}s", error.localizedDescription)
            if let syncError = error as? SyncError {
                dependencies.errorEvents.fire(syncError)
            }
        }
    }

    private var startSyncCancellable: AnyCancellable?

    private var syncQueue: SyncQueueProtocol?
    private var syncQueueCancellable: AnyCancellable?
    private var isSyncInProgressSubject = PassthroughSubject<Bool, Never>()
}
