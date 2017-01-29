/*
 * Copyright (C) 2017, Zoe Sheill.
 * All rights reserved.
 *
 */


import UIKit
import SCLAlertView

class RequestViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet weak var tableView: UITableView!
    
    func displayAlert(title: String, message: String) {
        SCLAlertView().showInfo(title, subTitle: message)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        
        print(FriendSystem.system.requestList)

        FriendSystem.system.addRequestObserver {
            print(FriendSystem.system.requestList)
            self.tableView.reloadData()
        }
    }

    class func instantiateFromStoryboard() -> RequestViewController {
        let storyboard = UIStoryboard(name: "MenuViewController", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: String(describing: self)) as! RequestViewController
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return FriendSystem.system.requestList.count
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 161.0
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Create cell
        /*var cell = tableView.dequeueReusableCell(withIdentifier: "UserCell")
         if cell == nil {
         tableView.register(UINib(nibName: "UserCell", bundle: nil), forCellReuseIdentifier: "UserCell")
         cell = tableView.dequeueReusableCell(withIdentifier: "UserCell") as? UserCell
         }
         
         // Modify cell
         cell!.button.setTitle("Accept", for: UIControlState())
         cell!.emailLabel.text = FriendSystem.system.requestList[indexPath.row].email
         
         cell!.setFunction {
         let id = FriendSystem.system.requestList[indexPath.row].id
         FriendSystem.system.acceptFriendRequest(id!)
         }
         
         // Return cell
         return cell!*/
        var cell = tableView.dequeueReusableCell(withIdentifier: "UserCell") as? UserCell
        if cell == nil {
            tableView.register(UINib(nibName: "UserCell", bundle: nil), forCellReuseIdentifier: "UserCell")
            cell = tableView.dequeueReusableCell(withIdentifier: "UserCell") as? UserCell
        }
        print(FriendSystem.system.userList[indexPath.row].name)
        // Modify cell
        cell!.nameLabel.text = "Name: \(FriendSystem.system.userList[indexPath.row].name)"
        cell!.schoolLabel.text = "School: \(FriendSystem.system.userList[indexPath.row].school)"
        cell!.gradeLabel.text = "Grade: \(FriendSystem.system.userList[indexPath.row].grade)"
        cell!.chatButton.removeFromSuperview()
        cell!.setAddFriendFunction {
            let id = FriendSystem.system.requestList[indexPath.row].uid
            FriendSystem.system.acceptFriendRequest(id)
            self.displayAlert(title: "Success!", message: "Friend Request Accepted")
        }
        /*cell!.setChatFunction {
         self.createChannel()
         }*/
        
        // Return cell
        return cell!
        
    }
}

/*extension RequestViewController: UITableViewDataSource {
    

    
    
    
}*/
