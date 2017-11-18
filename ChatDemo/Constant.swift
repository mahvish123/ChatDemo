//
//  Constant.swift
//  ChatDemo
//
//  Created by Mahvish Syed on 13/11/17.
//  Copyright © 2017 Mahvish Syed. All rights reserved.
//

import Firebase

struct Constants
{
    struct refs
    {
        static let databaseRoot = Database.database().reference()
        static let databaseChats = databaseRoot.child("chats")
    }
}
