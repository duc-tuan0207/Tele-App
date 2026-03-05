//
//  UserInfoController.swift
//  TeleApp
//
//  Created by Dezhun on 5/2/26.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

class UserInfoController: UIViewController {

    // MARK: - Properties
    var recipientUID: String = ""
    var recipientName: String = ""
    var isEditMode: Bool = false

    private var db = Firestore.firestore()

    // MARK: - UI Components
    private let tableView: UITableView = {
        let tv = UITableView(frame: .zero, style: .grouped)
        tv.backgroundColor = UIColor.systemGroupedBackground
        tv.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tv.register(InfoHeaderCell.self, forCellReuseIdentifier: InfoHeaderCell.identifier)
        tv.register(InfoRowCell.self, forCellReuseIdentifier: InfoRowCell.identifier)
        tv.register(ActionCell.self, forCellReuseIdentifier: ActionCell.identifier)
        return tv
    }()

    private var username: String = ""
    private var email: String = ""
    private var bio: String = "Design adds value faster, than it adds cost"
    private var isOnline: Bool = true

    // MARK: - Sections
    enum Section: Int, CaseIterable {
        case header, info, actions, danger
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        fetchUserInfo()
    }

    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemGroupedBackground
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        tableView.delegate = self
        tableView.dataSource = self
    }

    private func setupNavigationBar() {
        title = "Info"
        if isEditMode {
            navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(didTapCancel))
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(didTapDone))
        } else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Edit", style: .plain, target: self, action: #selector(didTapEdit))
        }
    }

    // MARK: - Fetch User Info
    private func fetchUserInfo() {
        let uid = recipientUID.isEmpty ? (Auth.auth().currentUser?.uid ?? "") : recipientUID

        db.collection("users").document(uid).getDocument { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            self.username = data["username"] as? String ?? self.recipientName
            self.email = data["email"] as? String ?? ""
            self.bio = data["bio"] as? String ?? ""
            self.isOnline = data["isOnline"] as? Bool ?? false
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - Selectors
    @objc private func didTapCancel() {
        dismiss(animated: true)
    }

    @objc private func didTapDone() {
        // TODO: Save changes to Firestore
        dismiss(animated: true)
    }

    @objc private func didTapEdit() {
        isEditMode = true
        setupNavigationBar()
        tableView.reloadData()
    }
}

// MARK: - UITableViewDelegate & DataSource
extension UserInfoController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return isEditMode ? 2 : Section.allCases.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if isEditMode {
            return section == 0 ? 1 : 3
        }
        switch Section(rawValue: section) {
        case .header: return 1
        case .info: return 3
        case .actions: return 3
        case .danger: return 1
        default: return 0
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        if isEditMode {
            if indexPath.section == 0 {
                let cell = tableView.dequeueReusableCell(withIdentifier: InfoHeaderCell.identifier, for: indexPath) as! InfoHeaderCell
                cell.configure(name: username, isOnline: isOnline, isEditing: true)
                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: InfoRowCell.identifier, for: indexPath) as! InfoRowCell
                switch indexPath.row {
                case 0: cell.configure(label: "First Name", value: username.components(separatedBy: " ").first ?? username, isEditable: true)
                case 1: cell.configure(label: "Last Name", value: username.components(separatedBy: " ").last ?? "", isEditable: true)
                case 2: cell.configure(label: "Bio", value: bio, isEditable: true)
                default: break
                }
                return cell
            }
        }

        switch Section(rawValue: indexPath.section) {
        case .header:
            let cell = tableView.dequeueReusableCell(withIdentifier: InfoHeaderCell.identifier, for: indexPath) as! InfoHeaderCell
            cell.configure(name: username, isOnline: isOnline, isEditing: false)
            return cell

        case .info:
            let cell = tableView.dequeueReusableCell(withIdentifier: InfoRowCell.identifier, for: indexPath) as! InfoRowCell
            switch indexPath.row {
            case 0: cell.configure(label: "email", value: email, isEditable: false)
            case 1: cell.configure(label: "bio", value: bio, isEditable: false)
            case 2: cell.configure(label: "username", value: "@\(username.lowercased().replacingOccurrences(of: " ", with: "_"))", isEditable: false, valueColor: .systemBlue)
            default: break
            }
            return cell

        case .actions:
            let cell = tableView.dequeueReusableCell(withIdentifier: ActionCell.identifier, for: indexPath) as! ActionCell
            switch indexPath.row {
            case 0: cell.configure(title: "Send Message", color: .systemBlue)
            case 1: cell.configure(title: "Share Contact", color: .systemBlue)
            case 2: cell.configure(title: "Start Secret Chat", color: .systemBlue)
            default: break
            }
            return cell

        case .danger:
            let cell = tableView.dequeueReusableCell(withIdentifier: ActionCell.identifier, for: indexPath) as! ActionCell
            cell.configure(title: "Block User", color: .systemRed)
            return cell

        default:
            return UITableViewCell()
        }
    }

    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 0 { return 100 }
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard !isEditMode else { return }

        switch Section(rawValue: indexPath.section) {
        case .actions:
            switch indexPath.row {
            case 0:
                navigationController?.popViewController(animated: true)
            case 1:
                shareContact()
            case 2:
                break
            default: break
            }
        case .danger:
            confirmBlockUser()
        default: break
        }
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if isEditMode { return nil }
        switch Section(rawValue: section) {
        case .actions: return nil
        case .danger: return nil
        default: return nil
        }
    }

    // MARK: - Helpers
    private func shareContact() {
        let text = "\(username)\n\(email)"
        let activityVC = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        present(activityVC, animated: true)
    }

    private func confirmBlockUser() {
        let alert = UIAlertController(title: "Block \(username)?", message: "Blocked users cannot send you messages.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Block", style: .destructive) { _ in
            // TODO: Block user in Firestore
        })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
    }
}

// MARK: - InfoHeaderCell
class InfoHeaderCell: UITableViewCell {

    static let identifier = "InfoHeaderCell"

    private let avatarView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 36
        view.clipsToBounds = true
        view.backgroundColor = .systemBlue
        return view
    }()

    private let avatarLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 28, weight: .semibold)
        label.textAlignment = .center
        return label
    }()

    private let nameLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        return label
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14)
        label.textColor = .systemBlue
        return label
    }()

    private let callButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setImage(UIImage(systemName: "phone.fill"), for: .normal)
        btn.tintColor = .systemBlue
        return btn
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none

        contentView.addSubview(avatarView)
        avatarView.addSubview(avatarLabel)
        contentView.addSubview(nameLabel)
        contentView.addSubview(statusLabel)
        contentView.addSubview(callButton)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        callButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 72),
            avatarView.heightAnchor.constraint(equalToConstant: 72),

            avatarLabel.centerXAnchor.constraint(equalTo: avatarView.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 16),

            statusLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            statusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),

            callButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            callButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            callButton.widthAnchor.constraint(equalToConstant: 36),
            callButton.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    func configure(name: String, isOnline: Bool, isEditing: Bool) {
        nameLabel.text = name
        statusLabel.text = isOnline ? "online" : "last seen recently"
        avatarLabel.text = String(name.prefix(1)).uppercased()
        callButton.isHidden = isEditing

        let colors: [UIColor] = [.systemBlue, .systemPurple, .systemPink, .systemOrange, .systemTeal]
        let index = abs(name.hashValue) % colors.count
        avatarView.backgroundColor = colors[index]
    }
}

// MARK: - InfoRowCell
class InfoRowCell: UITableViewCell {

    static let identifier = "InfoRowCell"

    private let labelText: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()

    private let valueTextField: UITextField = {
        let tf = UITextField()
        tf.font = .systemFont(ofSize: 16)
        tf.textColor = .label
        tf.isUserInteractionEnabled = false
        return tf
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupCell() {
        selectionStyle = .none
        contentView.addSubview(labelText)
        contentView.addSubview(valueTextField)

        labelText.translatesAutoresizingMaskIntoConstraints = false
        valueTextField.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            labelText.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            labelText.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            labelText.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            valueTextField.topAnchor.constraint(equalTo: labelText.bottomAnchor, constant: 2),
            valueTextField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            valueTextField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueTextField.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
        ])
    }

    func configure(label: String, value: String, isEditable: Bool, valueColor: UIColor = .label) {
        labelText.text = label
        valueTextField.text = value
        valueTextField.textColor = valueColor
        valueTextField.isUserInteractionEnabled = isEditable
        if isEditable {
            valueTextField.borderStyle = .none
            labelText.textColor = .systemBlue
        }
    }
}

// MARK: - ActionCell
class ActionCell: UITableViewCell {

    static let identifier = "ActionCell"

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16)
        return label
    }()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        contentView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(title: String, color: UIColor) {
        titleLabel.text = title
        titleLabel.textColor = color
    }
}
