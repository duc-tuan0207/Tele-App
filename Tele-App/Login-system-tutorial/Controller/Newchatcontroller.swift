//
//  NewChatController.swift
//  TeleApp
//
//  Created by Dezhun on 5/2/26.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

// MARK: - UserResult Model
struct UserResult {
    let uid: String
    let username: String
    let email: String
}

// MARK: - NewChatController
class NewChatController: UIViewController {

    // MARK: - Properties
    private var users: [UserResult] = []
    private var filteredUsers: [UserResult] = []
    private var db = Firestore.firestore()

    var didSelectUser: ((UserResult) -> Void)?

    // MARK: - UI Components
    private let searchBar: UISearchBar = {
        let sb = UISearchBar()
        sb.placeholder = "Search by username or email"
        sb.backgroundImage = UIImage()
        sb.backgroundColor = .clear
        sb.becomeFirstResponder()
        return sb
    }()

    private let tableView: UITableView = {
        let tv = UITableView()
        tv.backgroundColor = .systemBackground
        tv.separatorInset = UIEdgeInsets(top: 0, left: 76, bottom: 0, right: 0)
        tv.register(UserCell.self, forCellReuseIdentifier: UserCell.identifier)
        return tv
    }()

    private let emptyLabel: UILabel = {
        let label = UILabel()
        label.text = "Search for users to start chatting"
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 15)
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let ai = UIActivityIndicatorView(style: .medium)
        ai.hidesWhenStopped = true
        return ai
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        fetchAllUsers()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        searchBar.becomeFirstResponder()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground

        view.addSubview(searchBar)
        view.addSubview(tableView)
        view.addSubview(emptyLabel)
        view.addSubview(activityIndicator)

        searchBar.translatesAutoresizingMaskIntoConstraints = false
        tableView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            searchBar.heightAnchor.constraint(equalToConstant: 44),

            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 4),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            emptyLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 24),
        ])

        tableView.delegate = self
        tableView.dataSource = self
        searchBar.delegate = self

        emptyLabel.isHidden = false
        tableView.isHidden = true
    }

    private func setupNavigationBar() {
        title = "New Chat"
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(didTapCancel))
    }

    // MARK: - Fetch Users from Firestore
    private func fetchAllUsers() {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        activityIndicator.startAnimating()

        db.collection("users").getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }
            self.activityIndicator.stopAnimating()

            if let error = error {
                print("Error fetching users: \(error)")
                return
            }

            self.users = snapshot?.documents.compactMap { doc -> UserResult? in
                let data = doc.data()
                let uid = doc.documentID
                guard uid != currentUID,
                      let username = data["username"] as? String,
                      let email = data["email"] as? String else { return nil }
                return UserResult(uid: uid, username: username, email: email)
            } ?? []

            self.filteredUsers = self.users
        }
    }

    // MARK: - Selectors
    @objc private func didTapCancel() {
        dismiss(animated: true)
    }
}

// MARK: - UITableViewDelegate & DataSource
extension NewChatController: UITableViewDelegate, UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredUsers.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: UserCell.identifier, for: indexPath) as? UserCell else {
            return UITableViewCell()
        }
        cell.configure(with: filteredUsers[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 68
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let selectedUser = filteredUsers[indexPath.row]
        dismiss(animated: true) { [weak self] in
            self?.didSelectUser?(selectedUser)
        }
    }
}

// MARK: - UISearchBarDelegate
extension NewChatController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText.isEmpty {
            filteredUsers = users
            emptyLabel.isHidden = !users.isEmpty
            tableView.isHidden = users.isEmpty
        } else {
            filteredUsers = users.filter {
                $0.username.lowercased().contains(searchText.lowercased()) ||
                $0.email.lowercased().contains(searchText.lowercased())
            }
            emptyLabel.isHidden = !filteredUsers.isEmpty
            tableView.isHidden = filteredUsers.isEmpty

            if filteredUsers.isEmpty {
                emptyLabel.text = "No users found for \"\(searchText)\""
            }
        }
        tableView.reloadData()
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        filteredUsers = users
        tableView.reloadData()
        searchBar.resignFirstResponder()
    }
}

// MARK: - UserCell
class UserCell: UITableViewCell {

    static let identifier = "UserCell"

    private let avatarView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 24
        view.clipsToBounds = true
        return view
    }()

    private let avatarLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textAlignment = .center
        return label
    }()

    private let usernameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .label
        return label
    }()

    private let emailLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabel
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        contentView.addSubview(avatarView)
        avatarView.addSubview(avatarLabel)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(emailLabel)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        emailLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 48),
            avatarView.heightAnchor.constraint(equalToConstant: 48),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            usernameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            usernameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            usernameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),

            emailLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            emailLabel.topAnchor.constraint(equalTo: usernameLabel.bottomAnchor, constant: 3),
            emailLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
        ])
    }

    func configure(with user: UserResult) {
        usernameLabel.text = user.username
        emailLabel.text = user.email
        avatarLabel.text = String(user.username.prefix(1)).uppercased()
        avatarView.backgroundColor = colorForName(user.username)
    }

    private func colorForName(_ name: String) -> UIColor {
        let colors: [UIColor] = [.systemBlue, .systemPurple, .systemPink, .systemOrange, .systemTeal, .systemGreen, .systemIndigo]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}
