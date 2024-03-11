import Foundation
import RealmSwift

class BaseModel: Object {
    @Persisted(primaryKey: true) var id: String = UUID().uuidString
    @Persisted var data: String?
    @Persisted var keepCached: Bool = false
    @Persisted var createdOn = Date()
    @Persisted var version: Int?

    var sizeRange: ClosedRange<Int> {
        500...1000
    }

    @discardableResult
    func populate<T>(random: inout T) -> Self where T : RandomNumberGenerator {
        createdOn = Date(timeIntervalSince1970: TimeInterval.random(in: 43.years ... 44.years, using: &random))
        version = Int.random(in: 1...7, using: &random)
        data = String.random(length: Int.random(in: sizeRange, using: &random), using: &random)
        return self
    }

    @discardableResult
    func cache() -> Self {
        keepCached = true
        return self
    }
}

class SmallThing1: BaseModel {
}

class SmallThing2: BaseModel {
    @Persisted var smallThing1ID: String?

    @discardableResult
    func link(_ smallThing1: SmallThing1) -> Self {
        smallThing1ID = smallThing1.id
        return self
    }
}

class MediumThing: BaseModel {
    override var sizeRange: ClosedRange<Int> {
        4000...10000
    }
}

class LargeThing: BaseModel {
    @Persisted var mediumThingID: String?
    override var sizeRange: ClosedRange<Int> {
        16000...256000
    }

    @discardableResult
    func link(_ thing: MediumThing) -> Self {
        mediumThingID = thing.id
        return self
    }
}

class HugeThing: BaseModel {
    @Persisted var smallThing1ID: String?
    @Persisted var smallThing2ID: String?
    @Persisted var mediumThingID: String?
    @Persisted var largeThingID: String?

    override var sizeRange: ClosedRange<Int> {
        750000...2000000
    }

    @discardableResult
    func link(smallThing1: SmallThing1, smallThing2: SmallThing2, mediumThing: MediumThing, largeThing: LargeThing) -> Self {
        smallThing1ID = smallThing1.id
        smallThing2ID = smallThing2.id
        mediumThingID = mediumThing.id
        largeThingID = largeThing.id
        return self
    }
}

extension Int {
    var years: TimeInterval {
        TimeInterval(self) * 60 * 60 * 24 * 7 * 365
    }
}

extension String {
    static func random<T>(length: Int, using: inout T) -> String where T : RandomNumberGenerator {
        let alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-.[]#{}()'\"!@$%^&*+="
        return String(repeating: alphabet.randomElement(using: &using)!, count: length)
    }
}

public extension Realm {
    static var smallDbObjectTypes: [Object.Type] {
        [SmallThing1.self, SmallThing2.self]
    }
    static var largeDbObjectTypes: [Object.Type] {
        [SmallThing1.self, MediumThing.self, LargeThing.self, HugeThing.self]
    }
}
