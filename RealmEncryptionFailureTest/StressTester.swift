import Foundation
import GameKit
import RealmSwift

class StressTester {
    struct Test {
        let initialCachedData: ClosedRange<UInt>
        let cacheUpdateSize: ClosedRange<UInt>
        let newCachedDataLikelihood: Double
        let cacheDeletionLikelihood: Double
        let roundsOfOfflineWork: ClosedRange<UInt>
        let daysPerOfflineRound: ClosedRange<UInt>
        let itemsPerDay: ClosedRange<UInt>
        let linkExistingItemLikelihood: Double
    }

    let test: Test
    var random: SeededRandom
    let smallDb: Realm
    let largeDb: Realm

    init(test: Test, random: SeededRandom, smallDb: Realm, largeDb: Realm) {
        self.test = test
        self.random = random
        self.smallDb = smallDb
        self.largeDb = largeDb
    }

    func runTest() throws {
        try simulateInitialCache()

        let roundsOfOfflineWork = UInt.random(in: test.roundsOfOfflineWork, using: &random)
        for round in 1...roundsOfOfflineWork {
            print("Round \(round)/\(roundsOfOfflineWork)")
            try simulateRound()
        }
        print("Data creation is complete")
    }

    func simulateInitialCache() throws {
        let initialCachedDataCount = UInt.random(in: test.initialCachedData, using: &random)
        print("Caching \(initialCachedDataCount) MediumThings")
        for _ in 1...initialCachedDataCount {
            try MediumThing().populate(random: &random).cache().save(largeDb)
        }
    }

    func simulateRound() throws {
        try simulateOnlineWork()
        let days = UInt.random(in: test.daysPerOfflineRound, using: &random)
        for day in 1...days {
            print("Day \(day)/\(days)")
            try simulateOfflineDay()
        }
    }

    func simulateOnlineWork() throws {
        try simulateCacheUpdate()
        try simulateSync()
    }

    func simulateCacheUpdate() throws {
        for _ in 1...UInt.random(in: test.cacheUpdateSize) {
            if (random.decide(test.newCachedDataLikelihood)) {
                try MediumThing().populate(random: &random).cache().save(largeDb)
            } else if let thing = largeDb.objects(MediumThing.self).randomElement(using: &random) {

                try largeDb.write {
                    if (random.decide(test.cacheDeletionLikelihood)) {
                        largeDb.delete(thing)
                    } else {
                        largeDb.add(thing.populate(random: &random))
                    }
                }
            }
        }
    }

    func simulateSync() throws {
        try deleteAll(Realm.smallDbObjectTypes, inDb: smallDb)
        try deleteAll(Realm.largeDbObjectTypes, inDb: largeDb)
    }

    func deleteAll(_ types: [Object.Type], inDb db: Realm) throws {
        for type in types {
            for obj in db.objects(type) {
                if let model = obj as? BaseModel, model.keepCached {
                    continue
                }
                try db.write {
                    db.delete(obj)
                }
            }
        }
    }

    func simulateOfflineDay() throws {
        // start-of-day preparations
        try SmallThing1().populate(random: &random).save(smallDb)
        try SmallThing1().populate(random: &random).save(smallDb)
        let smallThing1 = try SmallThing1().populate(random: &random).save(smallDb)
        let smallThing2 = try SmallThing2().link(smallThing1).populate(random: &random).save(smallDb)

        let itemCount = UInt.random(in: test.itemsPerDay, using: &random)
        for itemIndex in 1...itemCount {
            print("Generating item \(itemIndex)/\(itemCount)")
            try simulateItemGeneration(smallThing1, smallThing2)
        }
    }

    func simulateItemGeneration(_ smallThing1: SmallThing1, _ smallThing2: SmallThing2) throws {
        try SmallThing1().populate(random: &random).save(largeDb)
        let medium = try getMediumThing()
        let large = try LargeThing().populate(random: &random).link(medium).save(largeDb)
        try HugeThing()
            .populate(random: &random)
            .link(smallThing1: smallThing1,
                  smallThing2: smallThing2,
                  mediumThing: medium,
                  largeThing: large)
            .save(largeDb)
    }

    func getMediumThing() throws -> MediumThing {
        if random.decide(test.linkExistingItemLikelihood),
            let thing = largeDb.objects(MediumThing.self).randomElement(using: &random) {
            return thing
        } else {
            return try MediumThing().populate(random: &random).save(largeDb)
        }
    }

}

extension BaseModel {
    @discardableResult
    func save(_ db: Realm) throws -> Self  {
        try db.write { db.add(self) }
        return self
    }
}

struct SeededRandom: RandomNumberGenerator {
    mutating func next() -> UInt64 {
        // GKRandom produces values in [INT32_MIN, INT32_MAX] range; hence we need two numbers to produce 64-bit value.
        let next1 = UInt64(bitPattern: Int64(gkrandom.nextInt()))
        let next2 = UInt64(bitPattern: Int64(gkrandom.nextInt()))
        return next1 ^ (next2 << 32)
    }

    init(seed: UInt64) {
        self.gkrandom = GKMersenneTwisterRandomSource(seed: seed)
    }

    private let gkrandom: GKRandom
}

extension RandomNumberGenerator {
    mutating func decide(_ likelihood: Double) -> Bool {
        Double.random(in: 0.0..<1.0, using: &self) < likelihood
    }
}
