//
//  ViewController.swift
//  ChatDemo
//
//  Created by Mahvish Syed on 13/11/17.
//  Copyright © 2017 Mahvish Syed. All rights reserved.
//

import UIKit
import JSQMessagesViewController
import Photos
import FirebaseStorage
import FirebaseDatabase
import FirebaseAuth

class ChatViewController: JSQMessagesViewController {

    //message array.
    var messages = [JSQMessage]()
    
    //images
    lazy var storageRef: StorageReference = Storage.storage().reference(forURL: "gs://chatdemo-a697c.appspot.com/")
    private var updatedMessageRefHandle: DatabaseHandle!
    private let imageURLNotSetKey = "NOTSET"
    fileprivate var photoMessageMap = [String: JSQPhotoMediaItem]()
    
    //setting color for outgoing and incoming message.
    lazy var outgoingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.outgoingMessagesBubbleImage(with: UIColor.jsq_messageBubbleBlue())
    }()
    
    lazy var incomingBubble: JSQMessagesBubbleImage = {
        return JSQMessagesBubbleImageFactory()!.incomingMessagesBubbleImage(with: UIColor.jsq_messageBubbleLightGray())
    }()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        //handling of display chat name.
        let defaults = UserDefaults.standard
        if  let id = defaults.string(forKey: "jsq_id"),
            let name = defaults.string(forKey: "jsq_name"){
            senderId = id
            senderDisplayName = name
        }
        else{
            senderId = String(arc4random_uniform(999999))
            senderDisplayName = ""
            defaults.set(senderId, forKey: "jsq_id")
            defaults.synchronize()
            showDisplayNameDialog()
        }
        
        title = "Chat: \(senderDisplayName!)"
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(showDisplayNameDialog))
        tapGesture.numberOfTapsRequired = 1
        navigationController?.navigationBar.addGestureRecognizer(tapGesture)
        
        collectionView.collectionViewLayout.incomingAvatarViewSize = CGSize.zero
        collectionView.collectionViewLayout.outgoingAvatarViewSize = CGSize.zero
        
        let query = Constants.refs.databaseChats.queryLimited(toLast: 10)
         _ = query.observe(.childAdded, with: { [weak self] snapshot in
            
            if  let data        = snapshot.value as? [String: String],
                let id          = data["sender_id"],
                let name        = data["name"],
                let text        = data["text"],
                !text.isEmpty{
                if let message = JSQMessage(senderId: id, displayName: name, text: text){
                    self?.messages.append(message)
                    self?.finishReceivingMessage()
                }
            }else if let data = snapshot.value as? [String: String],
               let id = data["senderId"] as String!,
               let photoURL = data["photoURL"] as String! {
                if let mediaItem = JSQPhotoMediaItem(maskAsOutgoing: id == self?.senderId) {
                    self?.addPhotoMessage(withId: id, key: snapshot.key, mediaItem: mediaItem)
               if photoURL.hasPrefix("gs://") {
                self?.fetchImageDataAtURL(photoURL, forMediaItem: mediaItem, clearsPhotoMessageMapOnSuccessForKey: nil)
                }
            }
         }
            self?.updatedMessageRefHandle = Constants.refs.databaseChats.observe(.childChanged, with: { (snapshot) in
                let key = snapshot.key
                let messageData = snapshot.value as! Dictionary<String, String> // 1
                
                if let photoURL = messageData["photoURL"] as String! { // 2
                    // The photo has been updated.
                    if let mediaItem = self?.photoMessageMap[key] { // 3
                        self?.fetchImageDataAtURL(photoURL, forMediaItem: mediaItem, clearsPhotoMessageMapOnSuccessForKey: key) // 4
                    }
                }
            })
        })
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //method to edit chat name.
    @objc func showDisplayNameDialog(){
        let defaults = UserDefaults.standard
        let alert = UIAlertController(title: "Your Display Name", message: "Before you can chat, please choose a display name. Others will see this name when you send chat messages. You can change your display name again by tapping the navigation bar.", preferredStyle: .alert)
        
        alert.addTextField { textField in
            
            if let name = defaults.string(forKey: "jsq_name")
            {
                textField.text = name
            }
            else
            {
                let names = ["Ford", "Arthur", "Zaphod", "Trillian", "Slartibartfast", "Humma Kavula", "Deep Thought"]
                textField.text = names[Int(arc4random_uniform(UInt32(names.count)))]
            }
        }
        
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self, weak alert] _ in
            
            if let textField = alert?.textFields?[0], !textField.text!.isEmpty {
                
                self?.senderDisplayName = textField.text
                
                self?.title = "Chat: \(self!.senderDisplayName!)"
                
                defaults.set(textField.text, forKey: "jsq_name")
                defaults.synchronize()
            }
        }))
        present(alert, animated: true, completion: nil)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData!{
        return messages[indexPath.item]
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int{
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource!{
        return messages[indexPath.item].senderId == senderId ? outgoingBubble : incomingBubble
    }
  
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource!{
        return nil
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString!{
        return messages[indexPath.item].senderId == senderId ? nil : NSAttributedString(string: messages[indexPath.item].senderDisplayName)
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat{
        return messages[indexPath.item].senderId == senderId ? 0 : 15
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!){
        let ref = Constants.refs.databaseChats.childByAutoId()
        let message = ["sender_id": senderId, "name": senderDisplayName, "text": text]
        ref.setValue(message)
        finishSendingMessage()
    }
    
    //images handling
    func sendPhotoMessage() -> String? {
        let itemRef = Constants.refs.databaseChats.childByAutoId()
        
        let messageItem = [
            "photoURL": imageURLNotSetKey,
            "senderId": senderId!,
            ]
        
        itemRef.setValue(messageItem)
        
        JSQSystemSoundPlayer.jsq_playMessageSentSound()
        
        finishSendingMessage()
        return itemRef.key
    }

    func setImageURL(_ url: String, forPhotoMessageWithKey key: String) {
        let itemRef = Constants.refs.databaseChats.child(key)
        itemRef.updateChildValues(["photoURL": url])
    }
    
    override func didPressAccessoryButton(_ sender: UIButton) {
        let picker = UIImagePickerController()
        picker.delegate = self
        if (UIImagePickerController.isSourceTypeAvailable(UIImagePickerControllerSourceType.camera)) {
            picker.sourceType = UIImagePickerControllerSourceType.camera
        } else {
            picker.sourceType = UIImagePickerControllerSourceType.photoLibrary
        }
        
        present(picker, animated: true, completion:nil)
    }
    
}


extension ChatViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
 
    private func addPhotoMessage(withId id: String, key: String, mediaItem: JSQPhotoMediaItem) {
        if let message = JSQMessage(senderId: id, displayName: "", media: mediaItem) {
            messages.append(message)
            
            if (mediaItem.image == nil) {
                photoMessageMap[key] = mediaItem
            }
            
            collectionView.reloadData()
        }
    }
    
    private func fetchImageDataAtURL(_ photoURL: String, forMediaItem mediaItem: JSQPhotoMediaItem, clearsPhotoMessageMapOnSuccessForKey key: String?) {
        let storageRef = Storage.storage().reference(forURL: photoURL)
        storageRef.getData(maxSize: INT64_MAX) { (data, error) in
            if let error = error {
                print("Error downloading image data: \(error)")
                return
            }
            storageRef.getMetadata(completion: { (metadata, metadataErr) in
                if let error = metadataErr {
                    print("Error downloading metadata: \(error)")
                    return
                }
            mediaItem.image = UIImage.init(data: data!)
            self.collectionView.reloadData()
                guard key != nil else {
                    return
                }
                self.photoMessageMap.removeValue(forKey: key!)
            })
        }
    }
    
        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [String : Any]) {
            
            picker.dismiss(animated: true, completion:nil)
            if let photoReferenceUrl = info[UIImagePickerControllerReferenceURL] as? URL {
                let assets = PHAsset.fetchAssets(withALAssetURLs: [photoReferenceUrl], options: nil)
                let asset = assets.firstObject
                if let key = sendPhotoMessage() {
                    asset?.requestContentEditingInput(with: nil, completionHandler: { (contentEditingInput, info) in
                        let imageFileURL = contentEditingInput?.fullSizeImageURL
                        let path = "\(photoReferenceUrl.lastPathComponent)"
                        self.storageRef.child(path).putFile(from: imageFileURL!, metadata: nil) { (metadata, error) in
                            if let error = error {
                                print("Error uploading photo: \(error.localizedDescription)")
                                return
                            }
                    self.setImageURL(self.storageRef.child((metadata?.path)!).description, forPhotoMessageWithKey: key)
                            self.collectionView.reloadData()
                        }
                    })
                }
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true, completion:nil)
        }
}
