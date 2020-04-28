//
//  BankDetailViewController.swift
//  Wildfire1.1
//
//  Created by Thomas Pitts on 18/02/2020.
//  Copyright © 2020 Wildfire. All rights reserved.
//

import UIKit
import FirebaseFunctions

class BankDetailViewController: UIViewController {
    
    lazy var functions = Functions.functions(region:"europe-west1")
    
    var bankAccount: BankAccount?
    
    let KYCVerified = UserDefaults.standard.bool(forKey: "KYCVerified")
    let KYCPending = UserDefaults.standard.bool(forKey: "KYCPending")
    let KYCRefused = UserDefaults.standard.bool(forKey: "KYCRefused")

    @IBOutlet weak var KYCPendingView: UIView!
    @IBOutlet weak var KYCPendingImage: UIImageView!
    @IBOutlet weak var KYCPendingButton: UIButton!
    
    @IBOutlet weak var accountOwnerLabel: UILabel!
    @IBOutlet weak var IBANLabel: UILabel!
    @IBOutlet weak var swiftLabel: UILabel!
    @IBOutlet weak var accountNumberLabel: UILabel!
    @IBOutlet weak var countryLabel: UILabel!
    
    @IBOutlet weak var IBANStack: UIStackView!
    @IBOutlet weak var swiftStack: UIStackView!
    @IBOutlet weak var accountNumberStack: UIStackView!
    @IBOutlet weak var countryStack: UIStackView!
    
    @IBOutlet weak var makeDepositButton: UIButton!
    @IBOutlet weak var deleteButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        displayBankInfo()
        
        KYCPendingView.clipsToBounds = true
        KYCPendingView.layer.borderWidth = 2 //Or some other value
        KYCPendingView.layer.borderColor = UIColor(hexString: "#39C3C6").cgColor

        Utilities.styleHollowButton(makeDepositButton)
        Utilities.styleHollowButtonRED(deleteButton)
        
        KYCPendingView.isHidden = true
        
        // TODO - TAKE THIS OUT! FOR TESTING ONLY

//        UserDefaults.standard.set(false, forKey: "KYCPending")
//        UserDefaults.standard.set(false, forKey: "KYCVerified")
//        UserDefaults.standard.set(true, forKey: "KYCRefused")
        
        if KYCPending == true {
            KYCPendingView.isHidden = false
        } else if KYCRefused == true {
            KYCPendingImage.image = UIImage(named: "icons8-identification-documents-error-100")
            KYCPendingButton.setTitle("ID was refused - please try again", for: .normal)
            KYCPendingView.isHidden = false
        }
    }
    @IBAction func KYCPendingButtonTapped(_ sender: Any) {
        
        if KYCPending == true {
            performSegue(withIdentifier: "showPendingView", sender: self)
        } else if KYCRefused == true {
                performSegue(withIdentifier: "showKYCRefused", sender: self)
        }
    }
    
    @IBAction func makeDepositTapped(_ sender: Any) {
        
        if KYCPending == true {
            performSegue(withIdentifier: "showPendingView", sender: self)
        } else if KYCRefused == true {
            performSegue(withIdentifier: "showKYCRefused", sender: self)
        } else {
            if KYCVerified == true {
                performSegue(withIdentifier: "showDepositAmountView", sender: self)
            } else {
                performSegue(withIdentifier: "showKYCView", sender: self)
            }
        }
    }
    
    
    @IBAction func deleteBankAccount(_ sender: Any) {
        let title = "Delete Account Details"
        let message = "Are you sure you want to delete this account information? This cannot be undone."
        let segueID = "unwindToPrevious"
        
        showAlert(title: title, message: message, segueIdentifier: segueID)
    }
    
    
    func showAlert(title: String, message: String?, segueIdentifier: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            
            self.deleteBankAccountInfo() {
                self.performSegue(withIdentifier: segueIdentifier, sender: self)
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (action: UIAlertAction!) in
        }))
        
        self.present(alert, animated: true)
    }
    
    
    func deleteBankAccountInfo(completion: @escaping ()->()) {
        
        self.functions.httpsCallable("deleteBankAccount").call() { (result, error) in
            // update credit cards list
            let appDelegate = AppDelegate()
            appDelegate.fetchBankAccountsListFromMangopay() {
                completion()
            }
        }
        
        if let id = self.bankAccount?.accountID {
            UserDefaults.standard.removeObject(forKey: "bankAccount\(id)")
            let count = UserDefaults.standard.integer(forKey: "numberOfBankAccounts")
            if count > 0 {
                let newCount = count - 1
                UserDefaults.standard.set(newCount, forKey: "numberOfBankAccounts")
            }
        }
    }
    
    func displayBankInfo() {
        if let bnk = bankAccount {
            accountOwnerLabel.text = bnk.accountHolderName
            IBANLabel.text = bnk.IBAN
            swiftLabel.text = bnk.SWIFTBIC
            accountNumberLabel.text = bnk.accountNumber
            countryLabel.text = bnk.country
            
            if bnk.type == "IBAN" {
                swiftStack.isHidden = true
                accountNumberStack.isHidden = true
                countryStack.isHidden = true
            } else if bnk.type == "OTHER" {
                IBANStack.isHidden = true
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {

        if let dVC = segue.destination as? DepositViewController {
            
            dVC.bankAccount = self.bankAccount
        }
    }
    
    @IBAction func unwindToPrevious(_ unwindSegue: UIStoryboardSegue) {
        //        let sourceViewController = unwindSegue.source
        // Use data from the view controller which initiated the unwind segue
    }
}
