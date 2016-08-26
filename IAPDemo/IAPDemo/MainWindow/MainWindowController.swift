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
  
  @IBAction func getProductList(sender: NSButton!) {
    isWorking = true
    accountTypeList.removeAll()
    
    var productIdentifiers = Set<ProductIdentifier>()
    productIdentifiers.insert(AccountType.Plus1Y.productIdentifier)
    productIdentifiers.insert(AccountType.Pro1Y.productIdentifier)
    
    IAP.requestProducts(productIdentifiers) { (response, error) in
      if let products = response?.products where !products.isEmpty {
        for product in products {
          if let identifier = product.productIdentifier, accountType = AccountType.getAccountType(identifier) {
            self.accountTypeList.append(accountType)
          }
        }
        
        self.selectedAccountType = self.accountTypeList.first
        self.resultString = ""
        
      } else if let invalidProductIdentifiers = response?.invalidProductIdentifiers {
        self.resultString = "Invalid product identifiers: " + invalidProductIdentifiers.description
        
      } else if error?.code == SKErrorPaymentCancelled {
        self.resultString = ""
        
      } else {
        self.resultString = error?.localizedDescription ?? "Failed to get product list."
      }
      
      NSOperationQueue.mainQueue().addOperationWithBlock({ 
        self.isWorking = false
      })
    }
  }
  
  @IBAction func purchase(sender: NSButton!) {
    if let productIdentifier = selectedAccountType?.productIdentifier {
      isWorking = true
      
      IAP.purchaseProduct(productIdentifier, handler: { (productIdentifier, error) in
        if let identifier = productIdentifier {
          self.resultString = identifier
          
        } else if error?.code == SKErrorPaymentCancelled {
          self.resultString = ""
          
        } else {
          self.resultString = error?.localizedDescription ?? "Failed to purchase."
        }
        
        NSOperationQueue.mainQueue().addOperationWithBlock({
          self.isWorking = false
        })
      })
    }
  }
  
  @IBAction func restore(sender: NSButton!) {
    isWorking = true
    
    IAP.restorePurchases { (productIdentifiers, error) in
      if !productIdentifiers.isEmpty {
        self.resultString = productIdentifiers.description
        
      } else if error?.code == SKErrorUnknown {
        // NOTE: if no product ever purchased, will return this error.
        self.resultString = "No purchased product found."
        
      } else if error?.code == SKErrorPaymentCancelled {
        self.resultString = ""
        
      } else {
        self.resultString = error?.localizedDescription ?? "Failed to restore."
      }
      
      NSOperationQueue.mainQueue().addOperationWithBlock({
        self.isWorking = false
      })
    }
  }
  
  @IBAction func validate(sender: NSButton!) {
    isWorking = true
    
    IAP.validateReceipt(Constants.IAPSharedSecret) { (statusCode, products) in
      if statusCode == ReceiptStatus.NoRecipt.rawValue {
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
      
      NSOperationQueue.mainQueue().addOperationWithBlock({
        self.isWorking = false
      })
    }
  }
}