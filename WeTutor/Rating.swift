//
//  Rating.swift
//  WeTutor
//
//  Created by Zoe on 4/14/17.
//  Copyright © 2017 CosmicMind. All rights reserved.
//

import UIKit

struct Rating {
    var rating: Double
    var comment: String 

    init(rating: Double,  comment: String) {
        self.rating = rating
        self.comment = comment
    }
    
    /*init(ratings: [String: Any]) {
        
    }*/
}
