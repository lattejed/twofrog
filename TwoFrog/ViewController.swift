//
//  ViewController.swift
//  TwoFrog
//
//  Created by Matthew Smith on 4/13/16.
//  Copyright © 2016 Matthew Smith. All rights reserved.
//

import Cocoa
import RNCryptor
import Alamofire

let GIST_ID_KEY = "GIST_ID_KEY"

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var masterKeyField: NSTextField!
    @IBOutlet weak var gistIdField: NSTextField!
    @IBOutlet weak var tokenField: NSTextField!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!

    var data = [[AnyObject]]()

    override func viewDidLoad() {
        super.viewDidLoad()
        gistIdField.stringValue = NSUserDefaults.standardUserDefaults().stringForKey(GIST_ID_KEY) ?? ""
        tableView.setDelegate(self)
        tableView.setDataSource(self)
    }
    
    override func viewWillDisappear() {
        super.viewWillDisappear()
        NSUserDefaults.standardUserDefaults().setObject(gistIdField.stringValue, forKey: GIST_ID_KEY)
        NSUserDefaults.standardUserDefaults().synchronize()
    }
    
    
    // MARK:
    
    private func showError(error: Any) {
        if !(error is NSError) {
            let err = NSError(domain: "twofrog", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "\(error)"
            ])
            NSAlert(error: err).runModal()
        } else {
            NSAlert(error: error as! NSError).runModal()
        }
    }
    
    private func masterKey() -> String {
        let cs = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        return self.masterKeyField.stringValue.stringByTrimmingCharactersInSet(cs)
    }
    
    private func token() -> String {
        let cs = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        return self.tokenField.stringValue.stringByTrimmingCharactersInSet(cs)
    }
    
    private func gistId() -> String {
        let cs = NSCharacterSet.whitespaceAndNewlineCharacterSet()
        return self.gistIdField.stringValue.stringByTrimmingCharactersInSet(cs)
    }
    
    private func getGist(url: String, cb: (String?, String?) -> Void) {
        progressIndicator.startAnimation(nil)
        Alamofire.request(.GET, url).responseJSON { response in
            self.progressIndicator.stopAnimation(nil)
            if !response.result.isSuccess {
                cb(nil, "\(response.result.error)")
            } else if let json = response.result.value as? [String: AnyObject],
                files = json["files"] as? [String: AnyObject],
                file = files["file1.txt"] as? [String: AnyObject],
                content = file["content"] as? String {
                cb(content, nil)
            } else {
                cb(nil, "Unknown error")
            }
        }
    }
    
    private func patchGist(url: String, content: String, token: String, cb: (String?) -> Void) {
        let params = [
            "description": "gist",
            "public": true,
            "files": ["file1.txt": ["content": content]]
        ]
        let headers = ["Authorization": "token \(token)"]
        progressIndicator.startAnimation(nil)
        Alamofire.request(.PATCH, url, parameters: params, encoding: .JSON, headers: headers).responseJSON { response in
            self.progressIndicator.stopAnimation(nil)
            if !response.result.isSuccess {
                cb("\(response.result.error)")
            } else {
                cb(nil)
            }
        }
    }
    
    
    // MARK:
    
    @IBAction func refreshButtonPressed(sender: NSButton) {
        if masterKey().characters.count < 1 { return }
        getGist("https://api.github.com/gists/\(gistId())") { (content, error) in
            if error != nil {
                self.showError(error!)
            } else {
                do {
                    let encrypted = NSData(base64EncodedString: content!, options: [.IgnoreUnknownCharacters])!
                    let data = try RNCryptor.decryptData(encrypted, password: self.masterKey())
                    let json = try NSJSONSerialization.JSONObjectWithData(data, options: .MutableContainers)
                    self.data = json as! [[AnyObject]]
                    self.tableView.reloadData()
                } catch {
                    self.showError(error)
                }
            }
        }
    }
    
    @IBAction func addRowButtonPressed(sender: NSButton) {
        let row = [AnyObject](count: 6, repeatedValue: NSNull())
        data.append(row)
        tableView.reloadData()
    }
    
    @IBAction func uploadButtonPressed(sender: NSButton) {
        if masterKey().characters.count < 1 { return }
        do {
            let data = try NSJSONSerialization.dataWithJSONObject(self.data, options: .PrettyPrinted)
            let encrypted = RNCryptor.encryptData(data, password: self.masterKey())
            let b64 = encrypted.base64EncodedStringWithOptions([.Encoding64CharacterLineLength])
            patchGist("https://api.github.com/gists/\(gistId())", content: b64, token: token(), cb: { (error) in
                if error != nil {
                    self.showError(error)
                }
            })
        } catch {
            self.showError(error)
        }
    }
    

    // MARK: NSTableViewDelegate, NSTableViewDataSource
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return data.count
    }
    
    func tableView(tableView: NSTableView, viewForTableColumn tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = tableView.makeViewWithIdentifier("cell", owner:self) as? NSTableCellView
        let col = tableView.tableColumns.indexOf(tableColumn!)!
        cell?.textField?.stringValue = data[row][col] as? String ?? "none"
        cell?.textField?.editable = true
        cell?.textField?.delegate = self
        cell?.textField?.tag = col
        return cell
    }
    
    override func controlTextDidEndEditing(obj: NSNotification) {
        if let textField = obj.object as? NSTextField where tableView.selectedRow > -1 {
            let col = textField.tag
            let row = tableView.selectedRow
            self.data[row][col] = textField.stringValue
        }
    }

}

