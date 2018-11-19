//
//  Movie+CoreDataProperties.swift
//  MyDataManager
//
//  Created by Tung Nguyen on 11/18/18.
//  Copyright © 2018 Tung Nguyen. All rights reserved.
//
//

import Foundation
import CoreData


extension Movie {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Movie> {
        return NSFetchRequest<Movie>(entityName: "Movie")
    }

    @NSManaged public var title: String?
    @NSManaged public var des: String?
    @NSManaged public var link: String?
    @NSManaged public var category: Category?

}
