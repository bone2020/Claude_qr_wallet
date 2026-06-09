from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import LETTER
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import inch
from reportlab.platypus import (
    SimpleDocTemplate,
    Paragraph,
    Spacer,
    Table,
    TableStyle,
    PageBreak,
    ListFlowable,
    ListItem,
)


OUT = "docs/shop_afrik/Shop_Afrik_Project_Plan_and_Roadmap.pdf"

PALETTE = {
    "dark": colors.HexColor("#101418"),
    "panel": colors.HexColor("#171D24"),
    "deep_teal": colors.HexColor("#063F3B"),
    "teal": colors.HexColor("#0BA99D"),
    "aqua": colors.HexColor("#3ED1C2"),
    "coral": colors.HexColor("#F56565"),
    "muted": colors.HexColor("#6B7280"),
    "border": colors.HexColor("#D9E2E7"),
    "light": colors.HexColor("#F3FBFA"),
    "gray": colors.HexColor("#F2F4F7"),
    "ink": colors.HexColor("#1F2933"),
}


def styles():
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName="Helvetica-Bold",
            fontSize=30,
            leading=36,
            textColor=PALETTE["deep_teal"],
            alignment=TA_LEFT,
            spaceAfter=8,
        ),
        "subtitle": ParagraphStyle(
            "Subtitle",
            parent=base["Normal"],
            fontName="Helvetica",
            fontSize=16,
            leading=22,
            textColor=PALETTE["teal"],
            spaceAfter=18,
        ),
        "body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=10.3,
            leading=14,
            textColor=PALETTE["ink"],
            spaceAfter=7,
        ),
        "h1": ParagraphStyle(
            "H1",
            parent=base["Heading1"],
            fontName="Helvetica-Bold",
            fontSize=16,
            leading=20,
            textColor=PALETTE["deep_teal"],
            spaceBefore=14,
            spaceAfter=8,
        ),
        "h2": ParagraphStyle(
            "H2",
            parent=base["Heading2"],
            fontName="Helvetica-Bold",
            fontSize=12.5,
            leading=16,
            textColor=PALETTE["teal"],
            spaceBefore=10,
            spaceAfter=6,
        ),
        "small": ParagraphStyle(
            "Small",
            parent=base["BodyText"],
            fontName="Helvetica",
            fontSize=8.6,
            leading=11,
            textColor=PALETTE["ink"],
        ),
        "small_white": ParagraphStyle(
            "SmallWhite",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=8.6,
            leading=11,
            textColor=colors.white,
        ),
        "callout_title": ParagraphStyle(
            "CalloutTitle",
            parent=base["BodyText"],
            fontName="Helvetica-Bold",
            fontSize=10.5,
            leading=13,
            textColor=PALETTE["deep_teal"],
            spaceAfter=3,
        ),
    }


S = styles()


def p(text, style="body"):
    return Paragraph(text, S[style])


def bullets(items):
    return ListFlowable(
        [ListItem(p(item), leftIndent=12) for item in items],
        bulletType="bullet",
        leftIndent=18,
        bulletFontName="Helvetica",
        bulletFontSize=9,
    )


def numbered(items):
    return ListFlowable(
        [ListItem(p(item), leftIndent=12) for item in items],
        bulletType="1",
        leftIndent=20,
        bulletFontName="Helvetica",
        bulletFontSize=9,
    )


def callout(title, body):
    table = Table(
        [[p(title, "callout_title")], [p(body)]],
        colWidths=[6.35 * inch],
        hAlign="LEFT",
    )
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, -1), PALETTE["light"]),
                ("BOX", (0, 0), (-1, -1), 0.6, colors.HexColor("#BDEDE7")),
                ("LEFTPADDING", (0, 0), (-1, -1), 10),
                ("RIGHTPADDING", (0, 0), (-1, -1), 10),
                ("TOPPADDING", (0, 0), (-1, -1), 8),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 8),
            ]
        )
    )
    return [table, Spacer(1, 10)]


def table(headers, rows, widths):
    data = [[p(h, "small_white") for h in headers]]
    for row in rows:
        data.append([p(str(value), "small") for value in row])
    t = Table(data, colWidths=[w * inch for w in widths], repeatRows=1, hAlign="LEFT")
    t.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), PALETTE["deep_teal"]),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.35, PALETTE["border"]),
                ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
                ("LEFTPADDING", (0, 0), (-1, -1), 7),
                ("RIGHTPADDING", (0, 0), (-1, -1), 7),
                ("TOPPADDING", (0, 0), (-1, -1), 6),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 6),
            ]
        )
    )
    return [t, Spacer(1, 10)]


def footer(canvas, doc):
    canvas.saveState()
    canvas.setFont("Helvetica", 8)
    canvas.setFillColor(PALETTE["muted"])
    canvas.drawString(inch, 0.5 * inch, "Shop Afrik Project Plan and Technical Roadmap")
    canvas.drawRightString(7.5 * inch, 0.5 * inch, f"Page {doc.page}")
    canvas.restoreState()


def story():
    items = []
    items += [p("Shop Afrik", "title"), p("Project Plan and Technical Roadmap", "subtitle")]
    items.append(
        p(
            "A professional planning brief for building Shop Afrik as a full African e-commerce marketplace integrated with QR Wallet business payments."
        )
    )
    items += table(
        ["Field", "Details"],
        [
            ("Document type", "Product plan, architecture brief, and implementation roadmap"),
            ("Prepared for", "Shop Afrik project kickoff"),
            ("Version", "Planning draft 1.0"),
            ("Date", "June 5, 2026"),
            ("Source material", "Existing Shop Afrik specs, QR Wallet integration plans, and visual color reference"),
        ],
        [1.55, 4.8],
    )
    items += callout(
        "Planning Position",
        "Start with a focused marketplace MVP: buyer shopping, seller product management, admin approvals, QR Wallet pay-now checkout, order tracking, refunds, and day-8 seller settlement. Defer deep links and pay-on-delivery until the core marketplace flow is stable.",
    )
    items.append(PageBreak())

    items += [p("1. Executive Summary", "h1")]
    items.append(
        p(
            "Shop Afrik is planned as a full multi-seller e-commerce marketplace for African markets. The first release should prove the core marketplace loop: discover a product, place an order, pay through QR Wallet, fulfill the order, handle refunds within a clear window, and settle sellers after the refund period."
        )
    )
    items += callout(
        "Recommended MVP",
        "Build a mobile-first Flutter marketplace backed by a dedicated Shop Afrik Firebase project. Use QR Wallet merchant QR payment for v1, require seller KYC through QR Wallet, and hold proceeds in the Shop Afrik business wallet until day 8 after delivery.",
    )

    items += [p("2. Product Vision", "h1")]
    items.append(
        p(
            "Shop Afrik should feel like a trusted African commerce platform: practical enough for everyday shopping, strong enough for seller operations, and disciplined enough for payments, refunds, and admin control."
        )
    )
    items.append(
        bullets(
            [
                "Buyers can discover products, compare options, pay securely, track orders, and request refunds.",
                "Sellers can onboard, upload products, manage stock, process orders, and monitor earnings.",
                "Admins can approve sellers and products, manage refunds, configure commissions, view reports, and investigate risk.",
                "QR Wallet remains the payment foundation while Shop Afrik owns the e-commerce experience.",
            ]
        )
    )

    items += [p("3. Product Scope", "h1")]
    items += table(
        ["Area", "MVP Scope", "Deferred"],
        [
            ("Buyer app", "Auth, catalog, product detail, cart, QR checkout, orders, refunds, wishlist, reviews", "Live chat, flash sales, comparison, price-drop alerts"),
            ("Seller dashboard", "Seller onboarding, KYC check, product CRUD, inventory, order updates, payout visibility", "Bulk CSV upload, analytics, coupons, vacation mode"),
            ("Admin dashboard", "Seller/product approval, order overview, refund control, commission settings, audit logs", "A/B tests, advanced fraud scoring, warehouse operations"),
            ("Payments", "QR Wallet merchant QR pay-now flow, business wallet collection, refunds, day-8 settlement", "Deep link handoff, pay on delivery, non-wallet payment methods"),
            ("Logistics", "Basic delivery statuses and delivery fee model", "Courier app, live GPS dispatch, warehouse inspection tooling"),
        ],
        [1.25, 3.0, 2.1],
    )

    items += [p("4. Platform Architecture", "h1")]
    items.append(
        p(
            "The recommended architecture is a separate Shop Afrik app and Firebase backend integrated with QR Wallet through Cloud Functions. This keeps the wallet product stable while giving Shop Afrik freedom to evolve marketplace data, seller workflows, and admin controls."
        )
    )
    items += table(
        ["Layer", "Responsibility"],
        [
            ("Shop Afrik Flutter app", "Buyer, seller, and admin experiences. Mobile-first, with admin web support when needed."),
            ("Shop Afrik Firebase project", "Products, categories, orders, buyers, sellers, reviews, refunds, notifications, audit logs, and settlement records."),
            ("Shop Afrik Cloud Functions", "Order creation, QR payload generation, payment confirmation, settlement jobs, refund workflow, seller/admin permissions."),
            ("QR Wallet Firebase project", "Business wallet, wallet balance, QR signing, sendMoney, refunds, holds, withdrawals, and existing KYC/wallet infrastructure."),
        ],
        [2.0, 4.35],
    )
    items += callout(
        "Architecture Decision",
        "Use the QR Wallet business wallet pattern, not a QR Wallet tenant refactor. The existing planning documents identify this as lower risk because it reuses established QR Wallet functions while keeping new Shop Afrik logic additive.",
    )

    items += [p("5. QR Wallet Payment Flow", "h1")]
    items.append(
        numbered(
            [
                "Buyer adds items to cart in Shop Afrik and starts checkout.",
                "Shop Afrik calculates subtotal, payment fee, delivery fee, and total.",
                "Shop Afrik calls QR Wallet's signed QR payload function for the Shop Afrik business wallet.",
                "Buyer opens QR Wallet, scans the QR code, confirms payment, and enters PIN.",
                "QR Wallet sendMoney debits the buyer and credits the Shop Afrik business wallet.",
                "Shop Afrik detects the transaction, marks the order as paid, and begins fulfillment.",
                "After delivery and the 7-day refund window, Shop Afrik settles the seller share to the seller's QR Wallet.",
            ]
        )
    )

    items += [p("6. Money, Refunds, and Settlement", "h1")]
    items += table(
        ["Policy", "Recommendation"],
        [
            ("Commission", "Start at 15 percent, configurable globally and later per category."),
            ("Payment fee", "Buyer pays payment processing fee as a separate checkout line item."),
            ("Refund window", "7 days from courier-confirmed delivery."),
            ("Partial refunds", "Allowed for multi-item orders; single-item orders are full refund or no refund."),
            ("Settlement", "Day 8 auto-settlement to seller QR Wallet after refund window closes."),
            ("Seller KYC", "Required through QR Wallet before seller approval."),
            ("Admin escalation", "Use tiered refund approval based on refund amount and admin role."),
        ],
        [1.55, 4.8],
    )

    items += [p("7. Core Data Model", "h1")]
    items += table(
        ["Collection", "Purpose"],
        [
            ("products", "Catalog records with seller, price, images, stock, category, and approval status."),
            ("categories", "Category tree for browse, filters, and admin management."),
            ("orders", "Buyer order totals, payment status, delivery status, timestamps, and settlement status."),
            ("sellers", "Store profile, QR Wallet link, KYC status, rating, approval status, and payout settings."),
            ("buyers", "Customer profile, addresses, wishlist, and notification preferences."),
            ("reviews", "Verified-buyer product reviews and ratings."),
            ("refund_requests", "Buyer refund requests, evidence, inspection result, admin decisions, and escalation state."),
            ("settlements", "Day-8 payout records from Shop Afrik to sellers."),
            ("notifications", "In-app notification history for buyers, sellers, and admins."),
            ("admin_audit", "Append-only audit trail for admin and financial actions."),
        ],
        [1.65, 4.7],
    )

    items += [p("8. Visual Direction", "h1")]
    items.append(
        p(
            "The visual reference points toward a premium dark mobile interface with teal action states, soft aqua highlights, and coral danger states. Shop Afrik should borrow the trust and polish of fintech UI, then add stronger product imagery for the shopping experience."
        )
    )
    items += table(
        ["Token", "Hex", "Usage"],
        [
            ("Primary dark", "#101418", "App background, high-trust surfaces"),
            ("Panel dark", "#171D24", "Cards, forms, product panels, bottom sheets"),
            ("Deep teal", "#063F3B", "Brand anchor, headers, dark accents"),
            ("Primary teal", "#0BA99D", "Main buttons, active tabs, payment confirmation"),
            ("Bright aqua", "#3ED1C2", "Highlights, success states, gradients"),
            ("Danger coral", "#F56565", "Refund warnings, delete actions, failed payment states"),
            ("Muted text", "#9AA4B2", "Secondary labels and helper text"),
        ],
        [1.45, 1.05, 3.85],
    )

    items += [p("9. Build Roadmap", "h1")]
    items += table(
        ["Phase", "Outcome", "Key Work"],
        [
            ("Phase 0: Decisions", "Ready-to-build scope", "Choose countries, Firebase project ID, commission, refund thresholds, delivery model, and initial categories."),
            ("Phase 1: Project setup", "New app foundation", "Create GitHub repo, scaffold Flutter app, connect Firebase, define routing, theme, and base services."),
            ("Phase 2: Backend", "Marketplace data foundation", "Products, sellers, buyers, orders, payment confirmation, state machine, security rules, and Cloud Functions."),
            ("Phase 3: Buyer MVP", "Customer shopping flow", "Home, categories, search, product detail, cart, checkout, QR payment, orders, wishlist, reviews."),
            ("Phase 4: Seller MVP", "Seller operations", "Seller onboarding, product CRUD, inventory, order management, sales and payout visibility."),
            ("Phase 5: Admin MVP", "Platform control", "Approval queues, orders, refunds, commissions, audit logs, reports, and role controls."),
            ("Phase 6: Enhancements", "Smoother commerce", "Deep links, pay on delivery, courier confirmation, advanced notifications, promotions, analytics."),
        ],
        [1.35, 1.55, 3.45],
    )

    items += [p("10. Open Decisions", "h1")]
    items += table(
        ["Decision", "Recommended Default"],
        [
            ("Initial countries", "Start with Ghana and Nigeria if operations are ready; otherwise Ghana only for faster launch."),
            ("Firebase project", "Create a dedicated Shop Afrik Firebase project separate from QR Wallet."),
            ("Commission", "15 percent for MVP, stored as admin-configurable platform setting."),
            ("Refund Tier 1", "Admin can approve up to NGN 50,000 equivalent."),
            ("Refund Tier 2", "Admin plus supervisor approval up to NGN 300,000 equivalent."),
            ("Low stock threshold", "20 percent of initial stock or a seller-defined minimum quantity."),
            ("Delivery code", "Optional in MVP, recommended before scaling courier operations."),
            ("Minimum order amount", "Decide per country after delivery fee model is selected."),
            ("Initial categories", "Start with 10 to 15 main categories."),
            ("Max products per seller", "500 products per seller for v1."),
        ],
        [2.0, 4.35],
    )

    items += [p("11. Immediate Next Steps", "h1")]
    items.append(
        numbered(
            [
                "Approve this planning document or mark changes.",
                "Choose the final MVP country scope and Firebase project name.",
                "Create the GitHub repository for Shop Afrik.",
                "Create the Flutter project and commit the initial scaffold.",
                "Implement theme tokens, routing shell, Firebase setup, and app role structure.",
                "Build backend data model and security rules before UI screens rely on live data.",
            ]
        )
    )

    items += [p("Appendix A: Source Planning Inputs", "h1")]
    items.append(
        bullets(
            [
                "shop-afrik-complete-spec.curentmd.md",
                "shop-afrik-integration-plan-v3-FINAL.md",
                "shop-afrik-qr-wallet-integration-plan ONE.md.pdf",
                "Shop Afrik visual color reference image",
            ]
        )
    )
    return items


def main():
    doc = SimpleDocTemplate(
        OUT,
        pagesize=LETTER,
        rightMargin=inch,
        leftMargin=inch,
        topMargin=inch,
        bottomMargin=0.8 * inch,
        title="Shop Afrik Project Plan and Technical Roadmap",
    )
    doc.build(story(), onFirstPage=footer, onLaterPages=footer)
    print(OUT)


if __name__ == "__main__":
    main()
