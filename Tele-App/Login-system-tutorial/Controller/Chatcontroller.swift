//
//  ChatController.swift
//  TeleApp
//
//  Created by Dezhun on 5/2/26.
//
//SSdads
import UIKit
import FirebaseAuth
import FirebaseFirestore

// MARK: - Message Model
struct Message {
    let id: String
    let senderId: String
    let text: String
    let imageUrl: String?
    let timestamp: Date
    var isSeen: Bool
    
    var isFromCurrentUser: Bool {
        return senderId == Auth.auth().currentUser?.uid
    }
}

// MARK: - ChatController
class ChatController: UIViewController {
    
    // MARK: - Properties
    var conversationId: String = ""
    var recipientName: String = ""
    var recipientUID: String = ""
    
    private var messages: [Message] = []
    private var db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    // MARK: - UI Components
    private let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = UIColor(red: 0.82, green: 0.88, blue: 0.94, alpha: 1.0)
        tv.separatorStyle = .none
        tv.register(MessageCell.self, forCellReuseIdentifier: MessageCell.identifier)
        tv.register(ImageMessageCell.self, forCellReuseIdentifier: ImageMessageCell.identifier)
        tv.keyboardDismissMode = .interactive
        return tv
    }()
    
    // Input bar
    private let inputContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        return view
    }()
    
    private let messageTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Message"
        tf.backgroundColor = UIColor.secondarySystemBackground
        tf.layer.cornerRadius = 20
        tf.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        tf.leftViewMode = .always
        tf.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 16, height: 0))
        tf.rightViewMode = .always
        tf.font = .systemFont(ofSize: 16)
        return tf
    }()
    
    private let sendButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        btn.tintColor = .systemBlue
        btn.contentVerticalAlignment = .fill
        btn.contentHorizontalAlignment = .fill
        return btn
    }()
    
    private let attachButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "paperclip"), for: .normal)
        btn.tintColor = .systemGray
        return btn
    }()
    
    private let micButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "mic"), for: .normal)
        btn.tintColor = .systemGray
        return btn
    }()
    
    private var inputContainerBottomConstraint: NSLayoutConstraint!
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        setupKeyboardObservers()
        loadMockMessages()
        // TODO: listenToMessages() — kết nối Firestore thật
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        listener?.remove()
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Setup UI
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(tableView)
        view.addSubview(inputContainerView)
        inputContainerView.addSubview(messageTextField)
        inputContainerView.addSubview(sendButton)
        inputContainerView.addSubview(attachButton)
        inputContainerView.addSubview(micButton)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        inputContainerView.translatesAutoresizingMaskIntoConstraints = false
        messageTextField.translatesAutoresizingMaskIntoConstraints = false
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        attachButton.translatesAutoresizingMaskIntoConstraints = false
        micButton.translatesAutoresizingMaskIntoConstraints = false
        
        inputContainerBottomConstraint = inputContainerView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        
        NSLayoutConstraint.activate([
            inputContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputContainerBottomConstraint,
            inputContainerView.heightAnchor.constraint(equalToConstant: 60),
            
            attachButton.leadingAnchor.constraint(equalTo: inputContainerView.leadingAnchor, constant: 8),
            attachButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            attachButton.widthAnchor.constraint(equalToConstant: 36),
            attachButton.heightAnchor.constraint(equalToConstant: 36),
            
            messageTextField.leadingAnchor.constraint(equalTo: attachButton.trailingAnchor, constant: 6),
            messageTextField.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            messageTextField.heightAnchor.constraint(equalToConstant: 40),
            messageTextField.trailingAnchor.constraint(equalTo: micButton.leadingAnchor, constant: -6),
            
            micButton.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -4),
            micButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            micButton.widthAnchor.constraint(equalToConstant: 36),
            micButton.heightAnchor.constraint(equalToConstant: 36),
            
            sendButton.trailingAnchor.constraint(equalTo: inputContainerView.trailingAnchor, constant: -8),
            sendButton.centerYAnchor.constraint(equalTo: inputContainerView.centerYAnchor),
            sendButton.widthAnchor.constraint(equalToConstant: 36),
            sendButton.heightAnchor.constraint(equalToConstant: 36),
            
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputContainerView.topAnchor),
        ])
        
        tableView.delegate = self
        tableView.dataSource = self
        messageTextField.delegate = self
        
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
        attachButton.addTarget(self, action: #selector(didTapAttach), for: .touchUpInside)
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        tableView.addGestureRecognizer(tapGesture)
    }
    
    private func setupNavigationBar() {
        // Custom title view with avatar + name + last seen
        let titleView = UIView()
        
        let avatarView = UIView()
        avatarView.backgroundColor = .systemBlue
        avatarView.layer.cornerRadius = 17
        avatarView.clipsToBounds = true
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        
        let avatarLabel = UILabel()
        avatarLabel.text = String(recipientName.prefix(1)).uppercased()
        avatarLabel.textColor = .white
        avatarLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        avatarLabel.textAlignment = .center
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let nameLabel = UILabel()
        nameLabel.text = recipientName.isEmpty ? "Chat" : recipientName
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = .label
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let statusLabel = UILabel()
        statusLabel.text = "last seen just now"
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabel
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        
        titleView.addSubview(avatarView)
        avatarView.addSubview(avatarLabel)
        titleView.addSubview(nameLabel)
        titleView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: titleView.leadingAnchor),
            avatarView.centerYAnchor.constraint(equalTo: titleView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 34),
            avatarView.heightAnchor.constraint(equalToConstant: 34),
            
            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            
            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: titleView.topAnchor, constant: 2),
            
            statusLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 8),
            statusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 1),
            statusLabel.bottomAnchor.constraint(equalTo: titleView.bottomAnchor, constant: -2),
            
            titleView.widthAnchor.constraint(equalToConstant: 200),
            titleView.heightAnchor.constraint(equalToConstant: 40),
        ])
        
        navigationItem.titleView = titleView
        
        let videoCallBtn = UIBarButtonItem(image: UIImage(systemName: "video"), style: .plain, target: self, action: #selector(didTapVideoCall))
        let callBtn = UIBarButtonItem(image: UIImage(systemName: "phone"), style: .plain, target: self, action: #selector(didTapCall))
        navigationItem.rightBarButtonItems = [videoCallBtn, callBtn]
    }
    
    // MARK: - Keyboard
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func keyboardWillShow(_ notification: Notification) {
        if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
            let keyboardHeight = keyboardFrame.height - view.safeAreaInsets.bottom
            inputContainerBottomConstraint.constant = -keyboardHeight
            UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
            scrollToBottom()
        }
    }
    
    @objc private func keyboardWillHide(_ notification: Notification) {
        inputContainerBottomConstraint.constant = 0
        UIView.animate(withDuration: 0.3) { self.view.layoutIfNeeded() }
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Mock Data
    private func loadMockMessages() {
        let myUID = Auth.auth().currentUser?.uid ?? "me"
        messages = [
            Message(id: "1", senderId: "other", text: "Good morning!", imageUrl: nil, timestamp: Date().addingTimeInterval(-3600), isSeen: true),
            Message(id: "2", senderId: "other", text: "Do you know what time is it?", imageUrl: nil, timestamp: Date().addingTimeInterval(-3500), isSeen: true),
            Message(id: "3", senderId: myUID, text: "It's morning in Tokyo 😎", imageUrl: nil, timestamp: Date().addingTimeInterval(-3400), isSeen: true),
            Message(id: "4", senderId: "other", text: "What is the most popular meal in Japan?", imageUrl: nil, timestamp: Date().addingTimeInterval(-3300), isSeen: true),
            Message(id: "5", senderId: "other", text: "Do you like it?", imageUrl: nil, timestamp: Date().addingTimeInterval(-3200), isSeen: true),
            Message(id: "6", senderId: myUID, text: "I think top two are:", imageUrl: nil, timestamp: Date().addingTimeInterval(-3100), isSeen: true),
        ]
        tableView.reloadData()
        scrollToBottom(animated: false)
    }
    
    // MARK: - Firestore (TODO: kết nối thật)
    private func listenToMessages() {
        listener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self, let docs = snapshot?.documents else { return }
                self.messages = docs.compactMap { doc -> Message? in
                    let data = doc.data()
                    guard let senderId = data["senderId"] as? String,
                          let text = data["text"] as? String,
                          let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else { return nil }
                    return Message(id: doc.documentID, senderId: senderId, text: text, imageUrl: data["imageUrl"] as? String, timestamp: timestamp, isSeen: data["isSeen"] as? Bool ?? false)
                }
                self.tableView.reloadData()
                self.scrollToBottom()
            }
    }
    
    private func sendMessage(text: String) {
        guard let myUID = Auth.auth().currentUser?.uid else { return }
        let messageData: [String: Any] = [
            "senderId": myUID,
            "text": text,
            "timestamp": Timestamp(date: Date()),
            "isSeen": false,
            "type": "text"
        ]
        // Add to mock locally
        let newMsg = Message(id: UUID().uuidString, senderId: myUID, text: text, imageUrl: nil, timestamp: Date(), isSeen: false)
        messages.append(newMsg)
        tableView.reloadData()
        scrollToBottom()
        
        // TODO: Uncomment khi có conversationId thật
        // db.collection("conversations").document(conversationId).collection("messages").addDocument(data: messageData)
    }
    
    // MARK: - Helpers
    private func scrollToBottom(animated: Bool = true) {
        guard messages.count > 0 else { return }
        let indexPath = IndexPath(row: messages.count - 1, section: 0)
        tableView.scrollToRow(at: indexPath, at: .bottom, animated: animated)
    }
    
    // MARK: - Long Press Menu
    private func showMessageMenu(for message: Message, at indexPath: IndexPath) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Mark as Unread", style: .default) { _ in })
        alert.addAction(UIAlertAction(title: "Pin", style: .default) { _ in })
        alert.addAction(UIAlertAction(title: "Mute", style: .default) { _ in })
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.messages.remove(at: indexPath.row)
            self?.tableView.deleteRows(at: [indexPath], with: .fade)
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    // MARK: - Selectors
    @objc private func didTapSend() {
        guard let text = messageTextField.text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        sendMessage(text: text)
        messageTextField.text = ""
    }
    
    @objc private func didTapAttach() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        present(picker, animated: true)
    }
    
    @objc private func didTapVideoCall() {}
    @objc private func didTapCall() {}
}

// MARK: - UITableViewDelegate & DataSource
extension ChatController: UITableViewDelegate, UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let message = messages[indexPath.row]
        
        if message.imageUrl != nil {
            let cell = tableView.dequeueReusableCell(withIdentifier: ImageMessageCell.identifier, for: indexPath) as! ImageMessageCell
            cell.configure(with: message)
            return cell
        } else {
            let cell = tableView.dequeueReusableCell(withIdentifier: MessageCell.identifier, for: indexPath) as! MessageCell
            cell.configure(with: message)
            return cell
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return 60
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
    }
    
    // Long press
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let message = messages[indexPath.row]
        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { _ in
            let markUnread = UIAction(title: "Mark as Unread", image: UIImage(systemName: "message.badge")) { _ in }
            let pin = UIAction(title: "Pin", image: UIImage(systemName: "pin")) { _ in }
            let mute = UIAction(title: "Mute", image: UIImage(systemName: "bell.slash")) { _ in }
            let delete = UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.messages.remove(at: indexPath.row)
                self?.tableView.deleteRows(at: [indexPath], with: .fade)
            }
            return UIMenu(title: "", children: [markUnread, pin, mute, delete])
        }
    }
}

// MARK: - UITextFieldDelegate
extension ChatController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        didTapSend()
        return true
    }
}

// MARK: - UIImagePickerControllerDelegate
extension ChatController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        picker.dismiss(animated: true)
        // TODO: Upload image to Firebase Storage
    }
}

// MARK: - MessageCell
class MessageCell: UITableViewCell {
    
    static let identifier = "MessageCell"
    
    private let bubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        label.numberOfLines = 0
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let seenIcon: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "checkmark.circle.fill")
        iv.tintColor = .systemBlue
        iv.contentMode = .scaleAspectFit
        return iv
    }()
    
    private var leadingConstraint: NSLayoutConstraint!
    private var trailingConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setupCell()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupCell() {
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(messageLabel)
        bubbleView.addSubview(timeLabel)
        bubbleView.addSubview(seenIcon)
        
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        seenIcon.translatesAutoresizingMaskIntoConstraints = false
        
        leadingConstraint = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        trailingConstraint = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
            
            messageLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            
            timeLabel.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 4),
            timeLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -8),
            timeLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -6),
            
            seenIcon.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -2),
            seenIcon.centerYAnchor.constraint(equalTo: timeLabel.centerYAnchor),
            seenIcon.widthAnchor.constraint(equalToConstant: 12),
            seenIcon.heightAnchor.constraint(equalToConstant: 12),
        ])
    }
    
    func configure(with message: Message) {
        messageLabel.text = message.text
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        timeLabel.text = formatter.string(from: message.timestamp)
        
        if message.isFromCurrentUser {
            bubbleView.backgroundColor = UIColor(red: 0.78, green: 0.93, blue: 0.76, alpha: 1.0) // light green
            messageLabel.textColor = .black
            seenIcon.isHidden = !message.isSeen
            leadingConstraint.isActive = false
            trailingConstraint.isActive = true
        } else {
            bubbleView.backgroundColor = .white
            messageLabel.textColor = .black
            seenIcon.isHidden = true
            trailingConstraint.isActive = false
            leadingConstraint.isActive = true
        }
    }
}

// MARK: - ImageMessageCell
class ImageMessageCell: UITableViewCell {
    
    static let identifier = "ImageMessageCell"
    
    private let bubbleView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        view.backgroundColor = UIColor(red: 0.78, green: 0.93, blue: 0.76, alpha: 1.0)
        return view
    }()
    
    private let fileNameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .systemGreen
        return label
    }()
    
    private let fileSizeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let thumbnailView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray4
        view.layer.cornerRadius = 8
        return view
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11)
        label.textColor = .secondaryLabel
        return label
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        setupCell()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupCell() {
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(thumbnailView)
        bubbleView.addSubview(fileNameLabel)
        bubbleView.addSubview(fileSizeLabel)
        bubbleView.addSubview(timeLabel)
        
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        thumbnailView.translatesAutoresizingMaskIntoConstraints = false
        fileNameLabel.translatesAutoresizingMaskIntoConstraints = false
        fileSizeLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            bubbleView.widthAnchor.constraint(equalToConstant: 240),
            
            thumbnailView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 8),
            thumbnailView.centerYAnchor.constraint(equalTo: bubbleView.centerYAnchor),
            thumbnailView.widthAnchor.constraint(equalToConstant: 56),
            thumbnailView.heightAnchor.constraint(equalToConstant: 56),
            thumbnailView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            thumbnailView.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8),
            
            fileNameLabel.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 8),
            fileNameLabel.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 12),
            fileNameLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -8),
            
            fileSizeLabel.leadingAnchor.constraint(equalTo: thumbnailView.trailingAnchor, constant: 8),
            fileSizeLabel.topAnchor.constraint(equalTo: fileNameLabel.bottomAnchor, constant: 2),
            
            timeLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -8),
            timeLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -6),
        ])
    }
    
    func configure(with message: Message) {
        fileNameLabel.text = message.imageUrl ?? "image.png"
        fileSizeLabel.text = "2.8 MB"
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        timeLabel.text = formatter.string(from: message.timestamp)
    }
}
