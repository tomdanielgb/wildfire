//
//  BankDetails2TableViewController.swift
//  Wildfire1.1
//
//  Created by Thomas Pitts on 12/02/2020.
//  Copyright © 2020 Wildfire. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import FirebaseAnalytics

class BankDetails2TableViewController: UITableViewController, UITextFieldDelegate {
    
    var name = ""
    var sortCode = ""
    var accountNumber = ""
    
    var line1 = ""
    var line2 = ""
    var cityName = ""
    var region = ""
    var postcode = ""
    var country = ""

    lazy var functions = Functions.functions(region:"europe-west1")
    
    
    var countries: [String] = []
    
    @IBOutlet weak var line1TextField: UITextField!
    @IBOutlet weak var line2TextField: UITextField!
    @IBOutlet weak var cityTextField: UITextField!
    @IBOutlet weak var regionTextField: UITextField!
    @IBOutlet weak var postcodeTextField: UITextField!
    @IBOutlet weak var countryTextField: UITextField!
    
    @IBOutlet weak var submitButton: UIButton!
    
    @IBOutlet weak var errorLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.tableFooterView = UIView()
        tableView.backgroundColor = .groupTableViewBackground
        
        errorLabel.isHidden = true
        Utilities.styleTextField(line1TextField)
        Utilities.styleTextField(line2TextField)
        Utilities.styleTextField(cityTextField)
        Utilities.styleTextField(regionTextField)
        Utilities.styleTextField(postcodeTextField)
        Utilities.styleTextField(countryTextField)
        Utilities.styleFilledButton(submitButton)
        
        // prefill text fields
        line1TextField.text = line1
        line2TextField.text = line2
        cityTextField.text = cityName
        regionTextField.text = region
        postcodeTextField.text = postcode
        // prefill country name (it arrives from the db as a country code, so needs to be converted)
        countryTextField.text = Utilities.countryName(from: self.country)
        
        line1TextField.delegate = self
        line2TextField.delegate = self
        cityTextField.delegate = self
        regionTextField.delegate = self
        postcodeTextField.delegate = self
        countryTextField.delegate = self
        
        for code in NSLocale.isoCountryCodes  {
            let id = NSLocale.localeIdentifier(fromComponents: [NSLocale.Key.countryCode.rawValue: code])
            let name = NSLocale(localeIdentifier: "en_UK").displayName(forKey: NSLocale.Key.identifier, value: id) ?? "Country not found for code: \(code)"
            self.countries.append(name)
        }
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(DismissKeyboard))
        view.addGestureRecognizer(tap)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        line1TextField.becomeFirstResponder()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    

    @IBAction func submitPressed(_ sender: Any) {
            
        // API guide https://docs.mangopay.com/endpoints/v2.01/cards#e177_the-card-registration-object
        
        // Validate the fields
        let error = validateFields()
        
        if let error = error {
            
            // This means there's something wrong with the fields, so show error message
            showError(error)
            return 
        } else {
            
            self.showSpinner(titleText: "Adding Account", messageText: nil)
            
            
            guard let line1 = self.line1TextField.text,
                let line2 = self.line2TextField.text,
                let cityName = self.cityTextField.text,
                let region = self.regionTextField.text,
                let postcode = self.postcodeTextField.text,
                let country = self.countryTextField.text else {
                    
                self.removeSpinnerWithCompletion() {
                    self.universalShowAlert(title: "Oops", message: "Please ensure all fields are filled in", segue: nil, cancel: false)
                }
                    
                return
            }
            
            // translate country back to code
            guard let countryCode = Utilities.localeFinder(for: country) else {
                self.removeSpinnerWithCompletion() {
                    self.universalShowAlert(title: "Oops", message: "Please re-enter the country in your address until autocorrect finishes it for you.", segue: nil, cancel: false)
                }
                return
            }
            
            var mangopayID = ""
            
            if let mpID = UserDefaults.standard.string(forKey: "mangopayID") {
                mangopayID = mpID
            }
            
            let bankAccountData: [String: String] = [
                "name": self.name,
                "country": countryCode,
                "sortCode": self.sortCode,
                "accountNumber": self.accountNumber,
                
                "line1": line1,
                "line2": line2,
                "city": cityName,
                "region": region,
                "postcode": postcode,
                "countryCode": countryCode,
                
                "mpID": mangopayID
            ]
            
            // fields have passed validation - so continue
            functions.httpsCallable("addBankAccount").call(bankAccountData) { (result, error) in
                
                if let error = error {
                    
                    self.removeSpinnerWithCompletion() {
                        
                        if error.localizedDescription != "" {
                            self.universalShowAlert(title: "Oops", message: error.localizedDescription, segue: nil, cancel: false)
                        } else {
                            self.universalShowAlert(title: "Oops", message: "Something went wrong. This is usually because the bank details are mistyped. Please check them and try again.", segue: nil, cancel: false)
                        }
                    }
                    
                } else {
                    
                    Analytics.logEvent(Event.bankAccountAdded.rawValue, parameters: nil)
                    
                    // takes a little longer but ensures the account shows up immediately
                    AppDelegate().fetchBankAccountsListFromMangopay() {
                        self.removeSpinnerWithCompletion() {
                            self.performSegue(withIdentifier: "showSuccessScreen", sender: self)
                        }
                    }
                }
            }
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        
        if textField == countryTextField {
            return !autoCompleteText(in: textField, using: string, suggestions: self.countries)
        } else {
            return true
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        
        switch textField {
            case line1TextField: line2TextField.becomeFirstResponder()
            case line2TextField: cityTextField.becomeFirstResponder()
            case cityTextField: regionTextField.becomeFirstResponder()
            case regionTextField: postcodeTextField.becomeFirstResponder()
            case postcodeTextField: countryTextField.becomeFirstResponder()
            case countryTextField: countryTextField.resignFirstResponder()
            default: textField.resignFirstResponder()
        }
        
        return false
    }
    
    func autoCompleteText(in textField: UITextField, using string: String, suggestions: [String]) -> Bool {
        if !string.isEmpty,
            let selectedTextRange = textField.selectedTextRange, selectedTextRange.end == textField.endOfDocument,
            let prefixRange = textField.textRange(from: textField.beginningOfDocument, to: selectedTextRange.start),
            let text = textField.text(in: prefixRange) {
            
            let prefix = text + string
            let lowercasePrefix = prefix.lowercased()
            
            var lowercasedCountries: [String] = []
            for country in suggestions  {
                let new = country.lowercased()
                lowercasedCountries.append(new)
            }
            
            let matches = lowercasedCountries.filter { $0.hasPrefix(lowercasePrefix) }
            
            var fixedCountries: [String] = []
            for country in matches  {
                let reverted = country.localizedCapitalized
                fixedCountries.append(reverted)
            }
            
            if (fixedCountries.count > 0) {
                textField.text = fixedCountries[0]
                
                if let start = textField.position(from: textField.beginningOfDocument, offset: prefix.count) {
                    textField.selectedTextRange = textField.textRange(from: start, to: textField.endOfDocument)
                    
                    return true
                }
            }
        }
        
        return false
    }
    
    func addAddressToCard(walletID: String, cardID: String, makeDefault: Bool) {
        if let uid = Auth.auth().currentUser?.uid {
            
            print("trying to add address")
            
            guard let line1 = self.line1TextField.text else { return }
            // N.B. line2 is not required - if nothing entered then pass empty string
            let line2 = self.line2TextField.text ?? ""
            // "city" not key value coding-compliant - renamed to "cityName"
            guard let cityName = self.cityTextField.text else { return }
            guard let region = self.regionTextField.text else { return }
            guard let postcode = self.postcodeTextField.text else { return }
            // TODO country needs to be converted to appropriate format
            guard let country = self.countryTextField.text else { return }
            
            let addressData : [String: [String: String]] = [
                "billingAddress": ["line1": line1, "line2": line2,"city": cityName, "region": region,"postcode": postcode,"country": country]
            ]
            // separate variable name because that's how it shows up in Firestore
            let defaultAddressData : [String: [String: String]] = [
                "defaultBillingAddress": ["line1": line1, "line2": line2,"city": cityName, "region": region,"postcode": postcode,"country": country]
            ]
            
            print("trying to add address2")
            print(addressData)
            
        Firestore.firestore().collection("users").document(uid).collection("wallets").document(walletID).collection("cards").document(cardID).setData(addressData
            // merge: true is IMPORTANT - prevents complete overwriting of a document if a user logs in for a second time, for example, which could wipe important data (including the balance..)
            , merge: true) { (error) in
                // print(result!.user.uid)
                if error != nil {
                    // Show error message
                    print("address adding failed1")
                } else {
                Firestore.firestore().collection("users").document(uid).setData(defaultAddressData
                   // merge: true is IMPORTANT - prevents complete overwriting of a document if a user logs in for a second time, for example, which could wipe important data (including the balance..)
                    , merge: true) { (error) in
                       // print(result!.user.uid)
                       if error != nil {
                           // Show error message
                        print("address adding failed2")
                       } else {
                           print("address should have been added")
                       }
                   }
                }
            }
        }
    }
    

    func validateFields() -> String? {
        
        let line1 = line1TextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        // N.B. line 2 is not required
        let cityName = cityTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let region = regionTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        let postcode = postcodeTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let country = Utilities.localeFinder(for: countryTextField.text!)
//        let country = countryTextField.text!.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check that all fields are filled in
        if line1 == "" ||
            // N.B. line 2 is not required
            cityName == "" ||
            region == "" ||
            postcode == "" ||
            country == ""
            {
            return "Please fill in all fields."
        }
        
        if country == nil {
            return "Please enter a valid Nationality"
        }
        
        return nil
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // without this line, the cell remains (visually) selected after end of tap
        tableView.deselectRow(at: indexPath, animated: true)
    }
            
    func showError(_ message:String) {
        
        errorLabel.text = message
        errorLabel.isHidden = false
    }

    @objc func DismissKeyboard(){
    //Causes the view to resign from the status of first responder.
    view.endEditing(true)
    }
}
