//
//  MainWindowController.swift
//  IAPDemo
//
//  Created by Jason Zheng on 8/24/16.
//  Copyright © 2016 Jason Zheng. All rights reserved.
//

import Cocoa
import StoreKit

class MainWindowController: NSWindowController {
  
  dynamic var accountTypeList = [AccountType]()
  dynamic var selectedAccountType: AccountType?
  dynamic var isWorking = false
  dynamic var resultString = ""
  
  // MARK: Lifecycle
  
  override var windowNibName: String? {
    return "MainWindowController"
  }
  
  override func windowDidLoad() {
    super.windowDidLoad()
  }
  
  // MARK: Action
  
  @IBAction func getProductList(_ sender: NSButton!) {
    isWorking = true
    accountTypeList.removeAll()
    
    var productIdentifiers = Set<ProductIdentifier>()
    productIdentifiers.insert(AccountType.Plus1Y.productIdentifier)
    productIdentifiers.insert(AccountType.Pro1Y.productIdentifier)
    
    IAP.requestProducts(productIdentifiers) { (response, error) in
      if let products = response?.products, !products.isEmpty {
        for product in products {
          if let accountType = AccountType.getAccountType(product.productIdentifier) {
            self.accountTypeList.append(accountType)
          }
        }
        
        self.selectedAccountType = self.accountTypeList.first
        self.resultString = ""
        
      } else if let invalidProductIdentifiers = response?.invalidProductIdentifiers {
        self.resultString = "Invalid product identifiers: " + invalidProductIdentifiers.description
        
      } else if let error = error as? NSError {
        if error.code == SKError.Code.paymentCancelled.rawValue {
          self.resultString = ""
          
        } else {
          self.resultString = error.localizedDescription
        }
      }
      
      OperationQueue.main.addOperation({ 
        self.isWorking = false
      })
    }
  }
  
  @IBAction func purchase(_ sender: NSButton!) {
    if let productIdentifier = selectedAccountType?.productIdentifier {
      isWorking = true
      
      IAP.purchaseProduct(productIdentifier, handler: { (productIdentifier, error) in
        if let identifier = productIdentifier {
          self.resultString = identifier
          
        } else if let error = error as? NSError {
          if error.code == SKError.Code.paymentCancelled.rawValue {
            self.resultString = ""
            
          } else {
            self.resultString = error.localizedDescription
          }
        }
        
        OperationQueue.main.addOperation({
          self.isWorking = false
        })
      })
    }
  }
  
  @IBAction func restore(_ sender: NSButton!) {
    isWorking = true
    
    IAP.restorePurchases { (productIdentifiers, error) in
      if !productIdentifiers.isEmpty {
        self.resultString = productIdentifiers.description
        
      } else if let error = error as? NSError {
        if error.code == SKError.Code.paymentCancelled.rawValue {
          self.resultString = ""
          
        } else {
          self.resultString = error.localizedDescription
        }
        
      } else {
        self.resultString = "No purchased product found."
      }
      
      OperationQueue.main.addOperation({
        self.isWorking = false
      })
    }
  }
  
  @IBAction func validate(_ sender: NSButton!) {
    isWorking = true
    
    IAP.validateReceipt(Constants.IAPSharedSecret) { (statusCode, products, json) in
      if statusCode == ReceiptStatus.noRecipt.rawValue {
        self.resultString = "No Receipt."
      } else {
        var productString = ""
        if let products = products {
          for (productID, _) in products {
            productString += productID + " "
          }
        }
        self.resultString = "\(statusCode ?? -999): \(productString)"
      }
      
      OperationQueue.main.addOperation({
        self.isWorking = false
      })
    }
  }
}
