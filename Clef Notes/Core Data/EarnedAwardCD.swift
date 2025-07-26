import Foundation
import CoreData

@objc(EarnedAwardCD)
public class EarnedAwardCD: NSManagedObject {

}

extension EarnedAwardCD {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<EarnedAwardCD> {
        return NSFetchRequest<EarnedAwardCD>(entityName: "EarnedAwardCD")
    }

    @NSManaged public var awardRawValue: String?
    @NSManaged public var dateWon: Date?
    @NSManaged public var count: Int64 // Add this new attribute
    @NSManaged public var student: StudentCD?

    public var award: Award? {
        guard let rawValue = awardRawValue else { return nil }
        return Award(rawValue: rawValue)
    }
}

extension EarnedAwardCD : Identifiable {

}
