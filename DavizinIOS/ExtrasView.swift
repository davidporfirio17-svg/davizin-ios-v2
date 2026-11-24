import UIKit
import SafariServices

protocol ExtrasViewDelegate: AnyObject {
    func extrasViewDidRequestOpenURL(_ view: ExtrasView, url: URL)
}

final class ExtrasView: UIView {
    weak var delegate: ExtrasViewDelegate?

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .clear
        translatesAutoresizingMaskIntoConstraints = false

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.showsVerticalScrollIndicator = false
        addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.alignment = .fill
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)

        contentStack.addArrangedSubview(makeBrandCard())
        contentStack.addArrangedSubview(makeSectionHeading())
        contentStack.addArrangedSubview(makeFeatureCard(
            icon: "sparkles.rectangle.stack",
            title: "Hologramas",
            subtitle: "Accede al panel de hologramas DZ.",
            action: #selector(openHologramas)
        ))

        let footer = UILabel()
        footer.text = "NYXEL EXTERNAL  ·  Extras"
        footer.font = UIFont.systemFont(ofSize: 10, weight: .semibold)
        footer.textColor = AppTheme.tertiaryText
        footer.textAlignment = .center
        footer.adjustsFontForContentSizeCategory = true
        contentStack.addArrangedSubview(footer)

        let preferredWidth = contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -36)
        preferredWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
            contentStack.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 18),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -18),
            contentStack.widthAnchor.constraint(lessThanOrEqualToConstant: 720),
            preferredWidth
        ])
    }

    private func makeBrandCard() -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = AppTheme.backgroundRaise
        card.layer.cornerRadius = 22
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = AppTheme.hairlineStrong.cgColor

        let avatar = UIImageView(image: UIImage(named: "NyxelAvatar"))
        avatar.translatesAutoresizingMaskIntoConstraints = false
        avatar.contentMode = .scaleAspectFill
        avatar.clipsToBounds = true
        avatar.layer.cornerRadius = 24
        avatar.layer.borderWidth = 1.5
        avatar.layer.borderColor = AppTheme.accent.withAlphaComponent(0.65).cgColor

        let title = UILabel()
        title.text = "NYXEL EXTERNAL"
        title.font = .systemFont(ofSize: 17, weight: .bold)
        title.textColor = AppTheme.primaryText
        title.adjustsFontForContentSizeCategory = true

        let eyebrow = UILabel()
        eyebrow.text = "EXTRAS"
        eyebrow.font = .systemFont(ofSize: 10, weight: .bold)
        eyebrow.textColor = AppTheme.readableAccent
        eyebrow.adjustsFontForContentSizeCategory = true

        let subtitle = UILabel()
        subtitle.text = "Funciones y herramientas adicionales."
        subtitle.font = UIFont.preferredFont(forTextStyle: .subheadline)
        subtitle.textColor = AppTheme.secondaryText
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.numberOfLines = 0

        let copy = UIStackView(arrangedSubviews: [eyebrow, title, subtitle])
        copy.axis = .vertical
        copy.alignment = .leading
        copy.spacing = 4
        copy.translatesAutoresizingMaskIntoConstraints = false

        let brandRow = UIStackView(arrangedSubviews: [avatar, copy])
        brandRow.axis = .horizontal
        brandRow.alignment = .center
        brandRow.spacing = 13
        brandRow.translatesAutoresizingMaskIntoConstraints = false

        card.addSubview(brandRow)

        NSLayoutConstraint.activate([
            avatar.widthAnchor.constraint(equalToConstant: 48),
            avatar.heightAnchor.constraint(equalToConstant: 48),
            brandRow.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            brandRow.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            brandRow.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            brandRow.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18)
        ])
        return card
    }

    private func makeSectionHeading() -> UIView {
        let container = UIView()
        let title = UILabel()
        title.text = "Extras disponibles"
        title.font = .systemFont(ofSize: 19, weight: .bold)
        title.textColor = AppTheme.primaryText
        title.adjustsFontForContentSizeCategory = true

        let subtitle = UILabel()
        subtitle.text = "Herramientas y contenido adicional."
        subtitle.font = UIFont.preferredFont(forTextStyle: .footnote)
        subtitle.textColor = AppTheme.secondaryText
        subtitle.adjustsFontForContentSizeCategory = true
        subtitle.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [title, subtitle])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -2),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2)
        ])
        return container
    }

    private func makeFeatureCard(icon: String, title: String, subtitle: String, action: Selector) -> UIView {
        let card = UIView()
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = AppTheme.backgroundRaise
        card.layer.cornerRadius = 18
        card.layer.cornerCurve = .continuous
        card.layer.borderWidth = 1
        card.layer.borderColor = AppTheme.hairline.cgColor

        let iconBackground = UIView()
        iconBackground.translatesAutoresizingMaskIntoConstraints = false
        iconBackground.backgroundColor = AppTheme.accentDim.withAlphaComponent(0.18)
        iconBackground.layer.cornerRadius = 12

        let symbol = UIImageView(image: UIImage(systemName: icon))
        symbol.translatesAutoresizingMaskIntoConstraints = false
        symbol.tintColor = AppTheme.readableAccent
        symbol.contentMode = .scaleAspectFit
        iconBackground.addSubview(symbol)

        let heading = UILabel()
        heading.text = title
        heading.font = .systemFont(ofSize: 15, weight: .semibold)
        heading.textColor = AppTheme.primaryText
        heading.adjustsFontForContentSizeCategory = true

        let sub = UILabel()
        sub.text = subtitle
        sub.font = UIFont.preferredFont(forTextStyle: .subheadline)
        sub.textColor = AppTheme.secondaryText
        sub.adjustsFontForContentSizeCategory = true
        sub.numberOfLines = 0

        let chevron = UIImageView(image: UIImage(systemName: "chevron.right"))
        chevron.translatesAutoresizingMaskIntoConstraints = false
        chevron.tintColor = AppTheme.tertiaryText
        chevron.contentMode = .scaleAspectFit

        let textStack = UIStackView(arrangedSubviews: [heading, sub])
        textStack.axis = .vertical
        textStack.spacing = 3
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let row = UIStackView(arrangedSubviews: [iconBackground, textStack, chevron])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)

        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: action, for: .touchUpInside)
        card.addSubview(button)

        NSLayoutConstraint.activate([
            iconBackground.widthAnchor.constraint(equalToConstant: 40),
            iconBackground.heightAnchor.constraint(equalToConstant: 40),
            symbol.centerXAnchor.constraint(equalTo: iconBackground.centerXAnchor),
            symbol.centerYAnchor.constraint(equalTo: iconBackground.centerYAnchor),
            symbol.widthAnchor.constraint(equalToConstant: 18),
            symbol.heightAnchor.constraint(equalToConstant: 18),
            chevron.widthAnchor.constraint(equalToConstant: 12),
            chevron.heightAnchor.constraint(equalToConstant: 16),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            button.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: card.trailingAnchor),
            button.topAnchor.constraint(equalTo: card.topAnchor),
            button.bottomAnchor.constraint(equalTo: card.bottomAnchor)
        ])
        return card
    }

    @objc private func openHologramas() {
        guard let url = URL(string: "https://dz-holograma.davidporfirio17.workers.dev") else { return }
        delegate?.extrasViewDidRequestOpenURL(self, url: url)
    }
}
