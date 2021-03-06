//
//  TutorsTableViewController.swift
//  WeTutor
//
//  Created by Zoe on 12/22/16.
//  Copyright © 2017 Zoe Sheill. All rights reserved.
//

import UIKit
import FirebaseDatabase
import FirebaseAuth
import CoreLocation
import SCLAlertView
import DropDown
import TwicketSegmentedControl
import EventKit
import FirebaseAnalytics
import Instructions
import PullToRefresh

extension Array {
    func doesContain<T where T : Equatable>(obj: T) -> Bool {
        return self.filter({$0 as? T == obj}).count > 0
    }
}

class TutorTableViewCell: UITableViewCell {
    
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var schoolLabel: UILabel!
    @IBOutlet weak var gradeLabel: UILabel!
    
    @IBOutlet weak var contactButton: NSLayoutConstraint!
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}

struct CoachMarkInfo {
    var title: String
    var content: String
    init(title: String, content: String) {
        self.title = title
        self.content = content
    }
}




class TutorsTableViewController: UIViewController, DZNEmptyDataSetSource, DZNEmptyDataSetDelegate, TwicketSegmentedControlDelegate, UITableViewDelegate, UITableViewDataSource, CoachMarksControllerDataSource, CoachMarksControllerDelegate {

    var dbRef: DatabaseReference!
    var tutors = [User]()
    var userRef: DatabaseReference!
    var senderDisplayName: String?
    var newChannel: Channel?
    var destinationUser: User!
    var currentUser: User?
    
    var finalUserList = [User]()
    var friendUserUIDList = [String]()
    
    @IBOutlet weak var tableView: UITableView!
    
    @IBOutlet weak var dropdownButton: UIButton!
    
    @IBAction func pressedShowDropdown(_ sender: Any) {
        dropDown.show()
    }
    
    fileprivate var channelRefHandle: DatabaseHandle?
    fileprivate var channels: [Channel] = []
    var tutorName: String = "Chat"
    var tuteeName: String = "Chat"
    var UID: String = ""
    
    fileprivate lazy var channelRef: DatabaseReference = Database.database().reference().child("channels")
    
    deinit {
        if let refHandle = channelRefHandle {
            channelRef.removeObserver(withHandle: refHandle)
        }
    }

    func displayAlert(_ title: String, message: String) {
        SCLAlertView().showInfo(title, subTitle: message)
        
    }
    
    // Instantiates TutorsTableViewController
    class func instantiateFromStoryboard() -> TutorsTableViewController {
        let storyboard = UIStoryboard(name: "MenuViewController", bundle: nil)
        return storyboard.instantiateViewController(withIdentifier: String(describing: self)) as! TutorsTableViewController
    }
    
    var dropDown: DropDown = DropDown()
    var segmentIndexIsTutor  = 0
    var segmentItemSubject  = "All Subjects"
    
    let coachMarksController = CoachMarksController()
    
    // MARK: viewDidLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        userRef = Database.database().reference().child("users")
        
        setupDropDown()
        
        self.tableView.dataSource = self
        self.tableView.delegate = self
        tableView.emptyDataSetSource = self
        tableView.emptyDataSetDelegate = self
        self.tableView.isUserInteractionEnabled = true
        
        let refresher = PullToRefresh()
        tableView.addPullToRefresh(refresher) {
            let when = DispatchTime.now() + 1.2
            self.tableView.reloadData()
            DispatchQueue.main.asyncAfter(deadline: when) {
                self.tableView.endRefreshing(at: .top)
            }
        }
        let titles = ["Tutors", "Students"]
        let frame = CGRect(x: 5, y: 0, width: view.frame.width - 10, height: 40)
        
        self.tableView.backgroundColor = UIColor.clear
        
        FriendSystem.system.getCurrentUser { (user) in
            self.currentUser = user
        }
        
        self.finalUserList.removeAll()
        // Creates list of user (either tutors or students) for the current user to view
        FriendSystem.system.addUserObserver { () in
            for user in FriendSystem.system.userList {
                var contains = false
                for finalUser in self.finalUserList {
                    if finalUser.uid == user.uid {
                        contains = true
                    }
                }
                if user.isTutor == true && contains == false{
                    self.finalUserList.append(user)
                }
            }
            for (index, user) in FriendSystem.system.userList.enumerated() {
                print("FriendSystem.system.userList \(index) \(user.uid)")
            }
                                       
            let userCoordinate = self.currentUser!.coordinate
            let currentUserUID = Auth.auth().currentUser?.uid
            
            // Adds user in Firebase snapshot to user list if they are near the current user
            self.userRef.observe(.value, with: { (snapshot: DataSnapshot) in
                var newUsers = [User]()
                for user in snapshot.children {
                    
                    var userObject = User(snapshot: user as! DataSnapshot)
                    let coordinate = CLLocation(latitude: userObject.latitude, longitude: userObject.longitude)
                    let isTutor = userObject.isTutor
                    userObject.coordinate = coordinate
                    
                    let distanceBetween = coordinate.distance(from: userCoordinate)
                    userObject.distanceFromUser = distanceBetween
                    if distanceBetween <= 50000  {
                        if (self.currentUser?.isTutor == true && isTutor == false) ||
                            (self.currentUser?.isTutor == false && isTutor == true) {
                            if userObject.uid != currentUserUID {
                                var doesContain = false
                                for user in newUsers {
                                    if user.uid == userObject.uid {
                                        doesContain = true
                                    }
                                }
                                if doesContain == false {
                                    newUsers.append(userObject)
                                }
                            }
                        }
                    }
                }
                
                self.finalUserList = newUsers
                self.tableView.reloadData()
            }) { (error: Error) in
                print(error)
            }

            self.tableView.reloadData()
        }
        
        // Stores information about the current user's friends for updating the user table
        FriendSystem.system.addFriendObserverTwo(friendListNumber: 2) {
            for friend in FriendSystem.system.friendListTwo {
                self.friendUserUIDList.append(friend.uid)
            }
        }

        self.view.addFlippedBackground()
        
        let segmentedControl = TwicketSegmentedControl(frame: frame)
        segmentedControl.setSegmentItems(titles)
  
        segmentedControl.delegate = self
        segmentedControl.sliderBackgroundColor = UIColor.sliderGreen()//UIColor.flatBlue
        segmentedControl.backgroundColor = UIColor.clear
        view.addSubview(segmentedControl)
       
        self.tableView.reloadData()
    }
    
    var screenBounds = UIScreen.main.bounds
   
    // Programatically sets up UI for user cells
    func getColoredView() -> UIView{
        let width = screenBounds.size.width
        let height = screenBounds.size.height
        let cellHeight = 135
        let cornerRadius:CGFloat = 5
        let coloredRoundedView : UIView = UIView(frame: CGRect(x: 10, y: 8, width: 77, height: cellHeight))
        
        coloredRoundedView.layer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 1.0, 1.0])
        coloredRoundedView.layer.masksToBounds = false
        coloredRoundedView.layer.shadowOffset = CGSize(width: -1, height: 1)
        coloredRoundedView.layer.shadowOpacity = 0.2
        coloredRoundedView.tag = 10
        coloredRoundedView.backgroundColor = colors[colorsCount % 5]
        
        colorsCount += 1
        
        coloredRoundedView.roundCorners(corners: [.topLeft, .bottomLeft], radius: cornerRadius)

        return coloredRoundedView
    }
    
    // Sets up filter for selecting subjects
    func setupDropDown() {
        // The view to which the drop down will appear on
        dropdownButton.width = self.view.frame.width - 10
        dropdownButton.layer.cornerRadius = 16
        dropdownButton.layer.width = view.frame.width - 10
        dropdownButton.layer.backgroundColor = UIColor.sliderGreen().cgColor
        dropDown.anchorView = dropdownButton // UIView or UIBarButtonItem
        dropDown.bottomOffset = CGPoint(x: 0, y: 20)
        dropDown.customCellConfiguration = { (index: Index, item: String, cell: DropDownCell) -> Void in
            guard let cell = cell as? SubjectCell else { return }
            
            // Setup custom UI components
            let currentSubject = subjectNames[index]
            cell.subjectLabel.text = currentSubject
            if let imageName: String = subjectImageNames[currentSubject] {
                cell.subjectImage.image = UIImage(named: "\(imageName)")
            }
        }
        dropDown.dataSource = subjectNames
        dropDown.cellNib = UINib(nibName: "SubjectCell", bundle: nil)
        dropDown.selectionAction = { [unowned self] (index, item) in
            self.dropdownButton.setTitle(item, for: .normal)
            
            self.filterBySubject(item)
        }
    }
    
    // Begin tutorial if user has not yet completed it
    override func viewDidAppear(_ animated: Bool) {
        tableView.reloadData()
        if currentUser?.completedTutorial == false {
            self.coachMarksController.start(on: self)
            self.userRef.child((currentUser?.uid)!).child("completedTutorial").setValue(true)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.coachMarksController.stop(immediately: true)
    }
    
    // Tutor/student filter
    func didSelect(_ segmentIndex: Int) {
        self.segmentIndexIsTutor = segmentIndex
        finalFilter(segmentIndexIsTutor: self.segmentIndexIsTutor, segmentItemSubject: self.segmentItemSubject)
    }
    
    func filterBySubject(_ segmentItem: String) {
        self.segmentItemSubject = segmentItem
        finalFilter(segmentIndexIsTutor: self.segmentIndexIsTutor, segmentItemSubject: self.segmentItemSubject)
    }
    
    // Universal filter for students/tutors/school subjects
    func finalFilter(segmentIndexIsTutor: Int, segmentItemSubject: String) {
            finalUserList = [User]()
            for user in FriendSystem.system.userList {
                for subject in user.preferredSubjects {
                    if (subject == segmentItemSubject || segmentItemSubject == "All Subjects")  && ((segmentIndexIsTutor == 0 && user.isTutor == true) || (segmentIndexIsTutor == 1 && user.isTutor == false)){
                        var elementInArray = false
                        for lastUser in finalUserList {
                            if lastUser.uid == user.uid {
                                elementInArray = true
                            }
                        }
                        if elementInArray == false {
                            finalUserList.append(user)
                        }
                    }
                }
            }
            tableView.reloadData()
    }
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return finalUserList.count
    }
    
    
    let coachMarkArray = [CoachMark]()
    
    let coachMark1 = CoachMarkInfo(title: "Add a Friend", content: "Click this button to add this person to your contact list")
    let coachMark2 = CoachMarkInfo(title: "Added Friend", content: "This circle will turn green if you have already added this person as a friend. ")
    
    func numberOfCoachMarks(for coachMarksController: CoachMarksController) -> Int {
        return 1
    }
    
    func coachMarksController(_ coachMarksController: CoachMarksController, coachMarkAt index: Int) -> CoachMark {
        return coachMarksController.helper.makeCoachMark(for: self.dropdownButton)
    }
    
    
    func coachMarksController(_ coachMarksController: CoachMarksController, coachMarkViewsAt index: Int, madeFrom coachMark: CoachMark) -> (bodyView: CoachMarkBodyView, arrowView: CoachMarkArrowView?) {
        let coachViews = coachMarksController.helper.makeDefaultCoachViews(withArrow: true, arrowOrientation: coachMark.arrowOrientation)
        
        coachViews.bodyView.hintLabel.text = "Hello! I'm a Coach Mark!"
        coachViews.bodyView.nextLabel.text = "Ok!"
        
        return (bodyView: coachViews.bodyView, arrowView: coachViews.arrowView)
    }
    
    // Begin a new chat with another user
    @IBAction func createNewChat(_ sender: Any) {
        let userID = Auth.auth().currentUser?.uid
        var finishedObserve = false
        
        if let uid = (sender as AnyObject).accessibilityIdentifier {
            print(uid)
            channelRef.observe(DataEventType.value, with: { (snapshot) in
                let value = snapshot.value as? [String : AnyObject] ?? [:]
                if let tuteeName = value["tuteeName"] as? String,
                    let tutorName = value["tutorName"] as? String {
                    if (userID == tuteeName  && uid == tutorName) ||
                        (userID == tutorName && uid == tuteeName) {
                        self.newChannel = Channel(id: snapshot.key, name: "Chat", tutorName: tutorName, tuteeName: tuteeName)
                        let userDefaults = UserDefaults.standard
                         finishedObserve = true
                        if let userName = userDefaults.value(forKey: "name") as? String {                 
                            self.senderDisplayName = userID
                        } else {
                            self.senderDisplayName = Auth.auth().currentUser?.email
                        }
                        self.performSegue(withIdentifier: "toChatVC", sender: self.newChannel)
                        
                    }
                }
                
            })
        }
    }
    
    // Create a chat channel with another user
    func createChannel(_ otherUser: User) {
        let userDefaults = UserDefaults.standard
        let isTutor = FriendSystem.system.currentUser?.isTutor
        
        if let userID = Auth.auth().currentUser?.uid {
            
            if isTutor == true {
                tutorName = userID
                tuteeName = otherUser.uid
            } else {
                tutorName = otherUser.uid
                tuteeName = userID
            }
        } else {
            tutorName = "Chat"
            tuteeName = "Chat"
        }

        let channelItem = [
            "tutorName": tutorName,
            "tuteeName": tuteeName,
        ]
        
        let userID = Auth.auth().currentUser?.uid
        let uuid = UUID().uuidString
        self.newChannel = Channel(id: uuid, name: channelItem["tutorName"]!, tutorName: tutorName, tuteeName: tuteeName)
        if let userName = userDefaults.value(forKey: "name") as? String {
        
            self.senderDisplayName = userID
        } else {
            self.senderDisplayName = Auth.auth().currentUser?.email
        }
        
        let userChannelRef = userRef.child(userID!).child("channels")
        let newChannelRef = channelRef.child(uuid)
        newChannelRef.setValue(channelItem)
        
        //This sets the channel item in the child "channels"
        userChannelRef.child(uuid).child("tutorName").setValue(tutorName)
        userChannelRef.child(uuid).child("tuteeName").setValue(tuteeName)
        
        //This adds the other user as a "friend" child to the current user ref and vice versa
        FriendSystem.system.acceptFriendRequest(otherUser.uid)
    }
    
    //This function creates a new calendar identifier to add to a newly created channel
 
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 150
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let userAtRow = finalUserList[indexPath.row]
        
        let tutor = userAtRow
        self.UID = tutor.uid
        self.destinationUser = tutor
        self.performSegue(withIdentifier: "toMoreInfoVC", sender: self)
    }
    
    // Register user cell for row
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        tableView.register(UINib(nibName: "UserCellThree", bundle: nil), forCellReuseIdentifier: "TutorCell")
        var cell = tableView.dequeueReusableCell(withIdentifier: "TutorCell") as? UserCellThree
        
        tableView.register(UINib(nibName: "TuteeUserCell", bundle: nil), forCellReuseIdentifier: "TuteeCell")
        var tuteeCell = tableView.dequeueReusableCell(withIdentifier: "TuteeCell") as? TuteeUserCell
        
        cell?.selectionStyle = UITableViewCellSelectionStyle.none
        tuteeCell?.selectionStyle = UITableViewCellSelectionStyle.none
        
        var ref: DatabaseReference!
        
        ref = Database.database().reference()
        
        let userAtRow = finalUserList[indexPath.row]
        let userID = Auth.auth().currentUser?.uid
        cell?.contentView.backgroundColor = UIColor.clear
        
        if userAtRow.isTutor == true {
            let friendInArray = friendUserUIDList.doesContain(obj: userAtRow.uid)
            if friendInArray == true {
                cell!.friendIndicatorView.image = UIImage(named: "Ok-50") //UIColor.green
            } else {
                cell!.friendIndicatorView.image = nil
            }
            
            cell!.nameLabel.text = "\(userAtRow.name)"
            cell!.schoolLabel.text = "\(userAtRow.school)"
            cell!.gradeLabel.text = "\(userAtRow.grade)"
            if let userAverageRating = userAtRow.averageRating {
                cell!.ratingView.rating = userAverageRating
            } else {
                cell!.ratingView.rating = 0
            }
            
            cell!.colorView = getColoredView()
            
            let numberOfRatings = userAtRow.numberOfRatings
            var numberOfRatingsString = "\(String(describing: numberOfRatings)) ratings"
            if numberOfRatings == 1 {
                numberOfRatingsString = "\(String(describing: numberOfRatings)) rating"
            }
            cell!.numberOfRatingsLabel.text = numberOfRatingsString
            
            if userAtRow.gpa != nil && userAtRow.gpa > 0 {
                let gpaString = String(format: "%.1f", userAtRow.gpa)
                cell!.gpaLabel.text = gpaString
            } else {
                cell!.gpaLabel.text = ""
            }
            if userAtRow.hourlyPrice != nil && userAtRow.hourlyPrice > 0 {
                let hourlyPriceString = String(format: "%.0f", userAtRow.hourlyPrice)
                cell!.hourlyPriceLabel.text = "$" + hourlyPriceString
            }
            
            let subjectsString = userAtRow.preferredSubjects.joined(separator: ", ")
            
            if subjectsString != nil && cell!.subjectLabel != nil{
                cell!.subjectLabel.text = "\(subjectsString)"
            }
            
            if cell!.nameLabel.isTruncated() {
                var delimiter = " "
                var newstr = cell!.nameLabel.text
                var truncatedName = newstr?.components(separatedBy: delimiter)
                print ("Truncated Name \(truncatedName?[0])")
                cell!.nameLabel.text = truncatedName?[0]
            }
         
            cell!.infoButton.contentMode = .scaleAspectFit
            cell!.addFriendButton.contentMode = .scaleAspectFit
            cell!.setAddFriendFunction {
                let id = userAtRow.uid
                FriendSystem.system.acceptFriendRequest(id)
                self.createChannel(userAtRow)
                self.displayAlert("Success!", message: "Contact Added")
                FriendSystem.system.addFriendObserver(friendListNumber: 1) {
                    print("FriendSystem.system.friendListOne  \(FriendSystem.system.friendListOne.count)")
                }
            }
         
            cell!.setInfoFunction {
                let tutor = userAtRow
                self.UID = tutor.uid
                self.destinationUser = tutor
                self.performSegue(withIdentifier: "toMoreInfoVC", sender: self)
            }
        
        // Return cell
        } else {
            let friendInArray = friendUserUIDList.doesContain(obj: userAtRow.uid)
            if friendInArray == true {
                tuteeCell!.friendIndicatorView.image = UIImage(named: "Ok-50") //UIColor.green
            } else {
                tuteeCell!.friendIndicatorView.image = nil
            }
            cell!.colorView = getColoredView()
            
            tuteeCell!.nameLabel.text = "\(userAtRow.name)"
            tuteeCell!.schoolLabel.text = "\(userAtRow.school)"
            tuteeCell!.gradeLabel.text = "\(userAtRow.grade)"
            
            let numberOfRatings = userAtRow.numberOfRatings
            var numberOfRatingsString = "\(String(describing: numberOfRatings)) ratings"
            if numberOfRatings == 1 {
                numberOfRatingsString = "\(String(describing: numberOfRatings)) rating"
            }
            
            if let userAverageRating = userAtRow.averageRating {
                cell!.ratingView.rating = userAverageRating
            } else {
                cell!.ratingView.rating = 0
            }
            
            cell!.numberOfRatingsLabel.text = numberOfRatingsString
            
            let subjectsString = userAtRow.preferredSubjects.joined(separator: ", ")
            
            if subjectsString != nil && tuteeCell!.subjectLabel != nil{
                tuteeCell!.subjectLabel.text = "\(subjectsString)"
            }
            print("Name: \(userAtRow.name)")
            print(tuteeCell!.nameLabel.text)
            tuteeCell!.infoButton.contentMode = .scaleAspectFit
            tuteeCell!.addFriendButton.contentMode = .scaleAspectFit
            
            tuteeCell!.setAddFriendFunction {
                print(userAtRow)
                let id = userAtRow.uid
                print("userAtRow.uid \(id)")
                FriendSystem.system.acceptFriendRequest(id)
                self.createChannel(userAtRow)
                self.displayAlert("Success!", message: "Contact Added")
            }
            
            tuteeCell!.setInfoFunction {
                let tutor = userAtRow
                self.UID = tutor.uid
                self.destinationUser = tutor
                self.performSegue(withIdentifier: "toMoreInfoVC", sender: self)
            }
        }
        if userAtRow.isTutor == true {
            return cell!
        }
        return tuteeCell!
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "toChatVC" {
                    if let channel = sender as? Channel {
                        let chatVc = segue.destination as! ChatViewController

                        chatVc.senderDisplayName = senderDisplayName
                        chatVc.channel = channel
                        chatVc.channelRef = channelRef.child(channel.id)
                    }
           } else if segue.identifier == "toMoreInfoVC" {
            let moreInfoVC = segue.destination as! MoreInfoViewController

            moreInfoVC.UID = UID
            moreInfoVC.destUser = destinationUser
         }
    }
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.backgroundColor = UIColor(white: 1, alpha: 0.0)
    }
    
    fileprivate func observeChannels() {
        // We can use the observe method to listen for new
        // channels being written to the Firebase DB
        var tutorOrTutee = "tutorName"
        channelRefHandle = channelRef.observe(.childAdded, with: { (snapshot) -> Void in
            if let channelData = snapshot.value as? Dictionary<String, AnyObject> {
                let id = snapshot.key
                var ref: DatabaseReference!
                let userID = Auth.auth().currentUser?.uid
                ref = Database.database().reference()
                ref.child("users").child(userID!).observeSingleEvent(of: .value, with: { (snapshot) in
                    // Get user value
                    let userObject = User(snapshot: snapshot )
                    
                    let value = snapshot.value as? NSDictionary
                    let isTutor = userObject.isTutor
                    
                    if isTutor != nil {
                        if isTutor == true {
                            tutorOrTutee = "tuteeName"
                        } else {
                            tutorOrTutee = "tutorName"
                        }
                    }
                    
                    if let name = channelData[tutorOrTutee] as! String!, name.characters.count > 0 {
                        self.channels.append(Channel(id: id, name: "Chat", tutorName: channelData["tutorName"] as! String, tuteeName: channelData["tuteeName"] as! String))
                        self.tableView.reloadData()
                    } else {
                        print("Error! Could not decode channel data")
                    }
                })
            }
                
        })
    }
    
    //If the user scrolls to the bottom of the tableView
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let height = scrollView.frame.size.height
        let contentYoffset = scrollView.contentOffset.y
        let distanceFromBottom = scrollView.contentSize.height - contentYoffset
        if distanceFromBottom < height {
            //log if the user scrolls to bottom
            if currentUser != nil {
                print("logged scroll to bottom")
            Analytics.logEvent("scrolled_to_bottom", parameters: [
                "current_user": currentUser!.uid as NSObject,
                "current_user_is_tutor": currentUser!.isTutor as NSObject
                ])
            }
        }
    }
    
    func title(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let str = "No Users to Display"
        let attrs = [NSFontAttributeName: UIFont.preferredFont(forTextStyle: UIFontTextStyle.headline),NSForegroundColorAttributeName : UIColor.white ]
        return NSAttributedString(string: str, attributes: attrs)
    }
    
    func description(forEmptyDataSet scrollView: UIScrollView) -> NSAttributedString? {
        let str = "There are no nearby users at this time.  Please try again later."
        let attrs = [NSFontAttributeName: UIFont.preferredFont(forTextStyle: UIFontTextStyle.body), NSForegroundColorAttributeName : UIColor.white]
        return NSAttributedString(string: str, attributes: attrs)
    }
    
    func image(forEmptyDataSet scrollView: UIScrollView) -> UIImage? {
        return UIImage(named: "placeholder_kickstarter")
    }
    
    
    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return true
    }
}
