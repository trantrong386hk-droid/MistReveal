import Foundation
import StoreKit

// MARK: - StoreKit 错误类型

enum StoreError: Error {
    case failedVerification
}

// MARK: - 购买管理器（StoreKit 2）

@MainActor
class PurchaseManager: ObservableObject {

    static let shared = PurchaseManager()

    // Product IDs
    static let monthlySubscriptionID = "com.chunlizhou.MistReveal.subscription.monthly"
    static let deepReportID          = "com.chunlizhou.MistReveal.deepreport"

    @Published var monthlyProduct: Product?
    @Published var deepReportProduct: Product?

    /// 是否持有有效订阅（月订阅）
    @Published var isSubscribed = false

    /// 是否已购买深度报告（一次性买断）
    @Published var hasDeepReport = false

    @Published var isPurchasing = false
    @Published var errorMessage: String?

    private var transactionListenerTask: Task<Void, Error>?

    private init() {
        transactionListenerTask = listenForTransactionUpdates()
        Task {
            await loadProducts()
            await refreshPurchaseStatus()
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - 加载商品

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [
                Self.monthlySubscriptionID,
                Self.deepReportID
            ])
            for product in products {
                switch product.id {
                case Self.monthlySubscriptionID:
                    monthlyProduct = product
                case Self.deepReportID:
                    deepReportProduct = product
                default:
                    break
                }
            }
        } catch {
            errorMessage = "无法加载商品信息"
        }
    }

    // MARK: - 发起购买

    func purchase(_ product: Product) async throws {
        isPurchasing = true
        defer { isPurchasing = false }
        errorMessage = nil

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await handleVerifiedTransaction(transaction)
            await transaction.finish()
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    // MARK: - 恢复购买

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshPurchaseStatus()
        } catch {
            errorMessage = "恢复购买失败，请检查网络后重试"
        }
    }

    // MARK: - 刷新购买状态

    func refreshPurchaseStatus() async {
        var subscribed = false
        var hasReport = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            guard transaction.revocationDate == nil else { continue }

            switch transaction.productID {
            case Self.monthlySubscriptionID:
                subscribed = true
            case Self.deepReportID:
                hasReport = true
            default:
                break
            }
        }

        isSubscribed = subscribed
        hasDeepReport = hasReport
    }

    // MARK: - 私有辅助

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let signedType):
            return signedType
        }
    }

    private func handleVerifiedTransaction(_ transaction: Transaction) async {
        switch transaction.productID {
        case Self.monthlySubscriptionID:
            isSubscribed = true
        case Self.deepReportID:
            hasDeepReport = true
        default:
            break
        }
    }

    private func listenForTransactionUpdates() -> Task<Void, Error> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { break }
                do {
                    let transaction = try await self.checkVerified(result)
                    await self.handleVerifiedTransaction(transaction)
                    await transaction.finish()
                } catch {
                    // 跳过无效交易
                }
            }
        }
    }
}
