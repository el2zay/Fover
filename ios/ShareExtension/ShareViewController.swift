//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Elie on 19/08/2026.
//

import receive_sharing_intent

class ShareViewController: RSIShareViewController {
    override func shouldAutoRedirect() -> Bool {
        return true
    }
}