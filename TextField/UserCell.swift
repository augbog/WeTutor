//
//  UserCell.swift
//  FirebaseFriendRequest
//
//  Created by Kiran Kunigiri on 7/11/16.
//  Copyright © 2016 Kiran. All rights reserved.
//

import UIKit

class UserCell: UITableViewCell {
    
    
   
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var chatButton: UIButton!
    
    @IBOutlet weak var schoolLabel: UILabel!
    @IBOutlet weak var addFriendButton: UIButton!
    @IBOutlet weak var gradeLabel: UILabel!
    
    @IBOutlet weak var infoButton: UIButton!
    
    
    var addFriendFunc: (() -> (Void))!
    var chatFunc: (() -> (Void))!
    var moreInfoFunc: (() -> (Void))!
    
    @IBAction func addFriendTapped(_ sender: Any) {
        addFriendFunc()
    }
    
    @IBAction func chatTapped(_ sender: Any) {
        chatFunc()
    }
    
    @IBAction func moreInfoTapped(_ sender: Any) {
        moreInfoFunc()
    }
    func setAddFriendFunction(_ function: @escaping () -> Void) {
        self.addFriendFunc = function
        
    }
    func setChatFunction(_ function: @escaping () -> Void) {
        self.chatFunc = function
        
    }
    func setInfoFunction(_ function: @escaping () -> Void) {
        self.moreInfoFunc = function
        
    }
    
    
}
