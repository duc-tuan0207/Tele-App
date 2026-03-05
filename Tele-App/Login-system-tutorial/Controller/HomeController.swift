//
//  HomeController.swift
//  TeleApp
//
//  Created by Dezhun on 5/2/26.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

// MARK: - Conversation Model
struct Conversation {
    let id: String
    let participantName: String
    let participantAvatar: String?
    let lastMessage: String
    let lastMessageTime: Date
    let unreadCount: Int
    let isOnline: Bool
}

// MARK: - HomeController
class HomeController: UIViewController {

    // MARK: - UI Components
    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "Search for messages or users"
        sb.backgroundImage = UIImage()
        sb.backgroundColor = .clear
        return sb
    }()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .systemBackground
        tv.separatorInset = UIEdgeInsets(top: 0, left: 76, bottom: 0, right: 0)
        tv.register(ConversationCell.self, forCellReuseIdentifier: ConversationCell.identifier)
        return tv
    }()

    private var conversations: [Conversation] = []
    private var filteredConversations: [Conversation] = []
    private var isSearching = false

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadMockData()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(searchBar)
        view.addSubview(tableView)

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            searchBar.heightAnchor.constraint(equalToConstant: 44),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self
    }

    private func setupNavigationBar() {
        title = "Chats"
        navigationController?.navigationBar.prefersLargeTitles = false

        let editButton = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(didTapEdit))
        let composeButton = UIBarButtonItem(image: UIImage(systemName: "square.and.pencil"), style: .plain, target: self, action: #selector(didTapCompose))
        let logoutButton = UIBarButtonItem(title: "Logout", style: .plain, target: self, action: #selector(didTapLogout))

        navigationItem.leftBarButtonItems = [editButton]
        navigationItem.rightBarButtonItems = [composeButton, logoutButton]
    }

    // MARK: - Mock Data
    private func loadMockData() {
        conversations = [
            Conversation(id: "1", participantName: "Saved Messages", participantAvatar: nil, lastMessage: "image.jpeg", lastMessageTime: Date(), unreadCount: 0, isOnline: false),
            Conversation(id: "2", participantName: "Pixsellz Team", participantAvatar: nil, lastMessage: "GIF", lastMessageTime: Date().addingTimeInterval(-3600), unreadCount: 0, isOnline: true),
            Conversation(id: "3", participantName: "Joshua Lawrence", participantAvatar: nil, lastMessage: "Let's choose the first option", lastMessageTime: Date().addingTimeInterval(-86400), unreadCount: 0, isOnline: false),
            Conversation(id: "4", participantName: "Telegram Designers", participantAvatar: nil, lastMessage: "GIF, Suggested by @alex_21", lastMessageTime: Date().addingTimeInterval(-7200), unreadCount: 17, isOnline: false),
            Conversation(id: "5", participantName: "Albert Lasker", participantAvatar: nil, lastMessage: "Like your quote about...", lastMessageTime: Date().addingTimeInterval(-1800), unreadCount: 0, isOnline: true),
        ]
        filteredConversations = conversations
        tableView.reloadData()
    }

    // MARK: - Selectors
    @objc private func didTapEdit() {}

    @objc private func didTapCompose() {
        let newChatVC = NewChatController()
        newChatVC.didSelectUser = { [weak self] selectedUser in
            guard let self = self else { return }
            let chatVC = ChatController()
            chatVC.recipientName = selectedUser.username
            chatVC.recipientUID = selectedUser.uid
            self.navigationController?.pushViewController(chatVC, animated: true)
        }
        let nav = UINavigationController(rootViewController: newChatVC)
        present(nav, animated: true)
    }

    @objc private func didTapLogout() {
        AuthService.shared.signOut { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                AlertManager.showLogoutError(on: self, with: error)
                return
            }
            if let sceneDelegate = self.view.window?.windowScene?.delegate as? SceneDelegate {
                sceneDelegate.checkAuthentication()
            }
        }
    }
}

// MARK: - UITableViewDelegate & DataSource
extension HomeController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return isSearching ? filteredConversations.count : conversations.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ConversationCell.identifier, for: indexPath) as? ConversationCell else {
            return UITableViewCell()
        }
        let conv = isSearching ? filteredConversations[indexPath.row] : conversations[indexPath.row]
        cell.configure(with: conv)
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 72
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let conv = isSearching ? filteredConversations[indexPath.row] : conversations[indexPath.row]
        let chatVC = ChatController()
        chatVC.recipientName = conv.participantName
        navigationController?.pushViewController(chatVC, animated: true)
    }

        func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let delete = UIContextualAction(style: .destructive, title: "Delete") { _, _, completion in
            self.conversations.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
            completion(true)
        }
        delete.backgroundColor = .systemRed

        let archive = UIContextualAction(style: .normal, title: "Archive") { _, _, completion in
            completion(true)
        }
        archive.backgroundColor = .systemGray

        let mute = UIContextualAction(style: .normal, title: "Mute") { _, _, completion in
            completion(true)
        }
        mute.backgroundColor = .systemOrange

        return UISwipeActionsConfiguration(actions: [archive, delete, mute])
    }

    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let unread = UIContextualAction(style: .normal, title: "Unread") { _, _, completion in
            completion(true)
        }
        unread.backgroundColor = .systemBlue

        let pin = UIContextualAction(style: .normal, title: "Pin") { _, _, completion in
            completion(true)
        }
        pin.backgroundColor = .systemGreen

        return UISwipeActionsConfiguration(actions: [unread, pin])
    }
}

// MARK: - UISearchBarDelegate
extension HomeController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            isSearching = false
        } else {
            isSearching = true
            filteredConversations = conversations.filter {
                $0.participantName.lowercased().contains(searchText.lowercased()) ||
                $0.lastMessage.lowercased().contains(searchText.lowercased())
            }
        }
        tableView.reloadData()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        isSearching = false
        searchBar.text = ""
        searchBar.resignFirstResponder()
        tableView.reloadData()
    }
}

// MARK: - ConversationCell
class ConversationCell: UITableViewCell {

    static let identifier = "ConversationCell"

    private let avatarImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 26
        iv.backgroundColor = .systemBlue
        return iv
    }()

    private let avatarLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        return label
    }()
    
    private let onlineIndicator: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGreen
        view.layer.cornerRadius = 7
        view.layer.borderWidth = 2
        view.layer.borderColor = UIColor.systemBackground.cgColor
        view.isHidden = true
        return view
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private let lastMessageLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabel
        label.numberOfLines = 1
        return label
    }()

    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        label.textAlignment = .right
        return label
    }()

    private let unreadBadge: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBlue
        view.layer.cornerRadius = 10
        view.isHidden = true
        return view
    }()

    private let unreadLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    // MARK: - Init
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        contentView.addSubview(avatarImageView)
        avatarImageView.addSubview(avatarLabel)
        contentView.addSubview(onlineIndicator)
        contentView.addSubview(nameLabel)
        contentView.addSubview(lastMessageLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(unreadBadge)
        unreadBadge.addSubview(unreadLabel)

        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        onlineIndicator.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        lastMessageLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        unreadBadge.translatesAutoresizingMaskIntoConstraints = false
        unreadLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            avatarImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 52),
            avatarImageView.heightAnchor.constraint(equalToConstant: 52),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarImageView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarImageView.centerYAnchor),

            onlineIndicator.trailingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 2),
            onlineIndicator.bottomAnchor.constraint(equalTo: avatarImageView.bottomAnchor, constant: 2),
            onlineIndicator.widthAnchor.constraint(equalToConstant: 14),
            onlineIndicator.heightAnchor.constraint(equalToConstant: 14),

            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            timeLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            timeLabel.widthAnchor.constraint(equalToConstant: 60),

            nameLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            nameLabel.trailingAnchor.constraint(equalTo: timeLabel.leadingAnchor, constant: -8),

            lastMessageLabel.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 12),
            lastMessageLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 3),
            lastMessageLabel.trailingAnchor.constraint(equalTo: unreadBadge.leadingAnchor, constant: -8),

            unreadBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            unreadBadge.centerYAnchor.constraint(equalTo: lastMessageLabel.centerYAnchor),
            unreadBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: 20),
            unreadBadge.heightAnchor.constraint(equalToConstant: 20),

            unreadLabel.centerXAnchor.constraint(equalTo: unreadBadge.centerXAnchor),
            unreadLabel.centerYAnchor.constraint(equalTo: unreadBadge.centerYAnchor),
            unreadLabel.leadingAnchor.constraint(equalTo: unreadBadge.leadingAnchor, constant: 4),
            unreadLabel.trailingAnchor.constraint(equalTo: unreadBadge.trailingAnchor, constant: -4),
        ])
    }

    func configure(with conversation: Conversation) {
        nameLabel.text = conversation.participantName
        lastMessageLabel.text = conversation.lastMessage

        let initials = String(conversation.participantName.prefix(1)).uppercased()
        avatarLabel.text = initials
        avatarImageView.backgroundColor = colorForName(conversation.participantName)

        timeLabel.text = formatTime(conversation.lastMessageTime)

        onlineIndicator.isHidden = !conversation.isOnline

        if conversation.unreadCount > 0 {
            unreadBadge.isHidden = false
            unreadLabel.text = "\(conversation.unreadCount)"
        } else {
            unreadBadge.isHidden = true
        }
    }

    private func colorForName(_ name: String) -> UIColor {
        let colors: [UIColor] = [.systemBlue, .systemPurple, .systemPink, .systemOrange, .systemTeal, .systemGreen, .systemIndigo]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM/dd"
            return formatter.string(from: date)
        }
    }
}
