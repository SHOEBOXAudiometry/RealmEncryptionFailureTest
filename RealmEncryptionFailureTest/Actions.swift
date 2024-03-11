import Foundation
import RealmSwift

enum DBError: LocalizedError {
    case onlyCompactOnFirstOpen

    public var errorDescription: String? {
        "Must force-quit and restart the app to compact the database"
    }
}

class Actions {
    var seed: UInt64 = 0
    var openedDatabases = Set<URL>()

    public func createTestDatabases() throws {
        wipeDatabases()
        try runStressTest(failureScenario)
        try backupDatabases()
    }

    public func compactAndWrite() throws {
        var random = SeededRandom(seed: seed)
        let (smallDb, largeDb) = try openDbs(compact: true)
        try SmallThing1().populate(random: &random).save(smallDb)
        try SmallThing2().populate(random: &random).save(smallDb)
        try SmallThing1().populate(random: &random).save(largeDb)
        try MediumThing().populate(random: &random).save(largeDb)
        try LargeThing().populate(random: &random).save(largeDb)
        try HugeThing().populate(random: &random).save(largeDb)
    }

    public func databasesExist() -> Bool {
        FileManager.default.fileExists(atPath: smallURL.path(percentEncoded: false))
    }

    public func compactingPossible() -> Bool {
        !openedDatabases.contains(smallURL) && !openedDatabases.contains(largeURL)
    }

    public func wipeDatabases() {
        _ = try? FileManager.default.removeItem(at: smallURL)
        _ = try? FileManager.default.removeItem(at: largeURL)
        _ = try? FileManager.default.removeItem(at: smallBackupURL)
        _ = try? FileManager.default.removeItem(at: largeBackupURL)
    }

    public func backupDatabases() throws {
        _ = try? FileManager.default.removeItem(at: smallBackupURL)
        _ = try? FileManager.default.removeItem(at: largeBackupURL)
        try FileManager.default.copyItem(at: smallURL, to: smallBackupURL)
        try FileManager.default.copyItem(at: largeURL, to: largeBackupURL)
    }

    public func restoreDatabases() throws {
        _ = try? FileManager.default.removeItem(at: smallURL)
        _ = try? FileManager.default.removeItem(at: largeURL)
        try FileManager.default.copyItem(at: smallBackupURL, to: smallURL)
        try FileManager.default.copyItem(at: largeBackupURL, to: largeURL)
    }

    public func runStressTest(_ test: StressTester.Test) throws {
        let (smallDb, largeDb) = try openDbs(compact: false)
        let tester = StressTester(test: test, random: SeededRandom(seed: seed), smallDb: smallDb, largeDb: largeDb)
        try tester.runTest()
    }

    var failureScenario: StressTester.Test {
        .init(initialCachedData: 100...500,
              cacheUpdateSize: 10...100,
              newCachedDataLikelihood: 0.3,
              cacheDeletionLikelihood: 0.1,
              roundsOfOfflineWork: 3...5,
              daysPerOfflineRound: 2...6,
              itemsPerDay: 3...7,
              linkExistingItemLikelihood: 0.8)
    }

    var encryptionKey: Data {
        var random = SeededRandom(seed: 0)
        return Data(Range(0...63).map { _ in UInt8.random(in: UInt8.min..<UInt8.max, using: &random) })
    }
    var dbDir: URL {
        try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    }
    var smallURL: URL { dbDir.appending(path: "small.realm") }
    var largeURL: URL { dbDir.appending(path: "large.realm") }
    var smallBackupURL: URL { dbDir.appending(path: "small-backup.realm") }
    var largeBackupURL: URL { dbDir.appending(path: "large-backup.realm") }

    func openDbs(compact: Bool) throws -> (Realm, Realm) {
        (try openDb(smallURL, objectTypes: Realm.smallDbObjectTypes, compact: compact),
         try openDb(largeURL, objectTypes: Realm.largeDbObjectTypes, compact: compact))
    }

    func openDb(_ fileURL: URL, objectTypes: [Object.Type], compact: Bool) throws -> Realm {
        guard !compact || !openedDatabases.contains(fileURL) else {
            throw DBError.onlyCompactOnFirstOpen
        }
        openedDatabases.insert(fileURL)

        return try Realm(configuration: .init(
            fileURL: fileURL,
            encryptionKey: encryptionKey,
            schemaVersion: 1,
            deleteRealmIfMigrationNeeded: false,
            shouldCompactOnLaunch: { fileSize, dataSize in
                print("Opening \(fileURL), size: \(fileSize.fileSizeString), data: \(dataSize.fileSizeString), compacting: \(compact)")
                return compact
            },
            objectTypes: objectTypes
        ))
    }
}

extension Int {
    var fileSizeString: String {
        ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file)
    }
}
