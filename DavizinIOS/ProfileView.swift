import UIKit

// MARK: - ProfileView — pantalla de perfil, accesible desde el avatar del header.
// Sistema de rango (Bronce->Plata->Oro->Diamante) segun inyecciones totales,
// guardadas en UserDefaults. Igual patron UIView que el resto de pantallas.

protocol ProfileViewDelegate: AnyObject {
    func profileViewDidTapLogout(_ view: ProfileView)
}

enum SessionStats {
    private static let key = "dz_injection_count"

    static var injectionCount: Int {
        get { UserDefaults.standard.integer(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    static func recordInjection() {
        injectionCount += 1
    }
}

private struct RankTier {
    let minCount: Int
    let name: String
    let color: UIColor
}

private let rankTiers: [RankTier] = [
    RankTier(minCount: 0,   name: "BRONCE",   color: UIColor(red: 0.54, green: 0.43, blue: 0.29, alpha: 1.0)),
    RankTier(minCount: 50,  name: "PLATA",    color: UIColor(red: 0.72, green: 0.77, blue: 0.80, alpha: 1.0)),
    RankTier(minCount: 150, name: "ORO",      color: UIColor(red: 0.88, green: 0.72, blue: 0.29, alpha: 1.0)),
    RankTier(minCount: 300, name: "DIAMANTE", color: AppTheme.accentHot)
]

private func currentRankTier(for count: Int) -> RankTier {
    rankTiers.last { count >= $0.minCount } ?? rankTiers[0]
}

final class ProfileView: UIView {
    weak var delegate: ProfileViewDelegate?

    private let avatarCircle = UIView()
    private let avatarLabel = UILabel()
    private let nameLabel = UILabel()
    private let rankBadge = UIView()
    private let rankLabel = UILabel()
    private let countValueLabel = UILabel()
    private let logoutButton = ARIFIButton(title: "CERRAR SESIÓN", style: .destructive)

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    /// Se llama cada vez que la pantalla se muestra, para reflejar el conteo actual.
    func refresh() {
        let count = SessionStats.injectionCount
        let tier = currentRankTier(for: count)
        rankLabel.text = "◆ \(tier.name)"
        rankLabel.textColor = tier.color
        rankBadge.layer.borderColor = tier.color.withAlphaComponent(0.5).cgColor
        rankBadge.backgroundColor = tier.color.withAlphaComponent(0.12)
        countValueLabel.text = "\(count)"
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        avatarCircle.backgroundColor = AppTheme.card
        avatarCircle.layer.cornerRadius = 31
        avatarCircle.layer.borderWidth = 2
        avatarCircle.layer.borderColor = AppTheme.accent.cgColor
        avatarCircle.layer.shadowColor = AppTheme.accent.cgColor
        avatarCircle.layer.shadowOpacity = 0.3
        avatarCircle.layer.shadowRadius = 14
        avatarCircle.translatesAutoresizingMaskIntoConstraints = false

        avatarLabel.text = "N"
        avatarLabel.font = .systemFont(ofSize: 22, weight: .black)
        avatarLabel.textColor = AppTheme.primaryText
        avatarLabel.textAlignment = .center
        avatarLabel.translatesAutoresizingMaskIntoConstraints = false
        avatarCircle.addSubview(avatarLabel)

        nameLabel.text = "Davizin"
        nameLabel.font = AppTheme.titleFont(19)
        nameLabel.textColor = AppTheme.primaryText

        rankLabel.font = .systemFont(ofSize: 10, weight: .heavy)
        rankLabel.translatesAutoresizingMaskIntoConstraints = false
        rankBadge.layer.cornerRadius = 100
        rankBadge.layer.borderWidth = 1
        rankBadge.translatesAutoresizingMaskIntoConstraints = false
        rankBadge.addSubview(rankLabel)

        let nameStack = UIStackView(arrangedSubviews: [nameLabel, rankBadge])
        nameStack.axis = .vertical
        nameStack.alignment = .leading
        nameStack.spacing = 6

        let heroStack = UIStackView(arrangedSubviews: [avatarCircle, nameStack])
        heroStack.axis = .horizontal
        heroStack.alignment = .center
        heroStack.spacing = 16
        heroStack.translatesAutoresizingMaskIntoConstraints = false

        let sectionTitle = UILabel()
        sectionTitle.text = "CUENTA"
        sectionTitle.font = .systemFont(ofSize: 10, weight: .heavy)
        sectionTitle.textColor = AppTheme.accent

        let countRow = makeRow(label: "Inyecciones totales", valueLabel: countValueLabel)

        let card = ARIFICardView()
        let cardStack = UIStackView(arrangedSubviews: [heroStack, sectionTitle, countRow, logoutButton])
        cardStack.axis = .vertical
        cardStack.spacing = 16
        cardStack.setCustomSpacing(24, after: heroStack)
        cardStack.translatesAutoresizingMaskIntoConstraints = false
        card.translatesAutoresizingMaskIntoConstraints = false
        card.addContent(cardStack)
        addSubview(card)

        logoutButton.addTarget(self, action: #selector(logoutTapped), for: .touchUpInside)

        NSLayoutConstraint.activate([
            avatarCircle.widthAnchor.constraint(equalToConstant: 62),
            avatarCircle.heightAnchor.constraint(equalToConstant: 62),
            avatarLabel.centerXAnchor.constraint(equalTo: avatarCircle.centerXAnchor),
            avatarLabel.centerYAnchor.constraint(equalTo: avatarCircle.centerYAnchor),
            rankBadge.heightAnchor.constraint(equalToConstant: 22),
            rankLabel.leadingAnchor.constraint(equalTo: rankBadge.leadingAnchor, constant: 10),
            rankLabel.trailingAnchor.constraint(equalTo: rankBadge.trailingAnchor, constant: -10),
            rankLabel.centerYAnchor.constraint(equalTo: rankBadge.centerYAnchor),

            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 22),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -22),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: AppTheme.contentMaximumWidth),
            cardStack.widthAnchor.constraint(greaterThanOrEqualToConstant: 240),
            logoutButton.heightAnchor.constraint(equalToConstant: AppTheme.controlHeight)
        ])

        refresh()
    }

    private func makeRow(label: String, valueLabel: UILabel) -> UIView {
        let labelView = UILabel()
        labelView.text = label
        labelView.font = .systemFont(ofSize: 13, weight: .medium)
        labelView.textColor = AppTheme.secondaryText

        valueLabel.font = AppTheme.monoFont(13)
        valueLabel.textColor = AppTheme.accentHot
        valueLabel.textAlignment = .right

        let row = UIStackView(arrangedSubviews: [labelView, valueLabel])
        row.axis = .horizontal
        row.distribution = .equalSpacing
        return row
    }

    @objc private func logoutTapped() {
        SoundService.shared.playClick()
        delegate?.profileViewDidTapLogout(self)
    }
}
