//
//  MasterViewController.swift
//  savings-assistant
//
//  Created by Chris Amanse on 7/27/15.
//  Copyright (c) 2015 Joe Christopher Paul Amanse. All rights reserved.
//

import UIKit
import Async
import RealmSwift

class MasterViewController: UITableViewController {

    var detailViewController: DetailViewController? = nil
    
    private var _accounts: Results<Account>?
    var accounts: Results<Account> {
        if _accounts == nil {
            _accounts = Realm().objects(Account).sorted("name", ascending: true)
        }
        return _accounts!
    }
    
    var didFirstAppear = false
    
    // For formatting to currency
    let numberFormatter: NSNumberFormatter = {
        let formatter = NSNumberFormatter()
        formatter.numberStyle = .CurrencyStyle
        
        return formatter
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        if UIDevice.currentDevice().userInterfaceIdiom == .Pad {
            self.clearsSelectionOnViewWillAppear = false
            self.preferredContentSize = CGSize(width: 320.0, height: 600.0)
        }
    }
    
    private var realmNotificationToken: NotificationToken?
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Reload data on appear
        tableView.reloadData()
        
        // Add realm notification
        println("Master: Adding realm notification")
        realmNotificationToken = Realm().addNotificationBlock({ (notification, realm) -> Void in
            println("Master: RealmNotification received")
            self.tableView.reloadData()
//            self.tableView.reloadSections(NSIndexSet(index: 0), withRowAnimation: UITableViewRowAnimation.Automatic)
        })
        
        if !didFirstAppear {
            RateAppStack.sharedInstance().incrementAppLaunches()
        }
        
        didFirstAppear = true
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Clear realm notification
        println("Master: Removing realm notification")
        if let notificationToken = realmNotificationToken {
            Realm().removeNotification(notificationToken)
        }
        realmNotificationToken = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // For split view controller
        if let split = self.splitViewController {
            let controllers = split.viewControllers
            detailViewController = controllers[controllers.count-1].topViewController as? DetailViewController
        }
        
        // Load AccountTableViewCell
        let accountNib = UINib(nibName: "AccountTableViewCell", bundle: NSBundle.mainBundle())
        tableView.registerNib(accountNib, forCellReuseIdentifier: "AccountCell")
        
        // Self-sizing cell
        tableView.estimatedRowHeight = AccountTableViewCell.estimatedRowHeight
        tableView.rowHeight = UITableViewAutomaticDimension
        tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Segues
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showDetail" {
            if let indexPath = self.tableView.indexPathForSelectedRow() {
                let selectedAccount = accounts[indexPath.row]
                
                
                if let destinationVC = (segue.destinationViewController as? UINavigationController)?.topViewController as? DetailViewController {
                    destinationVC.account = selectedAccount
                    
                    // Show master view controller in iPad (Regular Width)
                    destinationVC.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem()
                    // To show back button on iPhone (Compact Width)
                    destinationVC.navigationItem.leftItemsSupplementBackButton = true
                }
            }
        }
    }

    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("AccountCell", forIndexPath: indexPath) as! AccountTableViewCell
        
        let currentAccount = accounts[indexPath.row]
        let totalAmount = currentAccount.totalAmount
        
        // Update text
        cell.textLabel?.text = currentAccount.name
        cell.detailTextLabel?.text = numberFormatter.stringFromNumber(NSNumber(double: totalAmount))
        
        // Update text color for amount
        cell.updateAmountLabelTextColorForAmount(totalAmount)
        
        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let account = accounts[indexPath.row]
            let realm = Realm()
            realm.write({ () -> Void in
                realm.delete(account.transactions)
                realm.delete(account)
            })
            
            // Make sure to delete transactions without an account linked to them. Delete in background
            Async.background({ () -> Void in
                let bgRealm = Realm()
                let danglingTransactions = bgRealm.objects(Transaction).filter("account = nil")
                
                if danglingTransactions.count > 0 {
                    println("! Found dangling transactions. Deleting...")
                    bgRealm.write({ () -> Void in
                        bgRealm.delete(danglingTransactions)
                        println("! Deleted dangling transactions.")
                    })
                }
            })
            
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        performSegueWithIdentifier("showDetail", sender: nil)
    }
}

