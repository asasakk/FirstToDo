import SwiftUI
import GoogleMobileAds

struct AdBannerView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let viewController = UIViewController()
        
        // ★修正: AdSize.banner ではなく、AdSizeBanner (そのまま書く)
        let view = BannerView(adSize: AdSizeBanner)
        
        view.adUnitID = "ca-app-pub-3940256099942544/2934735716"
        
        view.rootViewController = viewController
        viewController.view.addSubview(view)
        
        // ★修正: ここも AdSizeBanner.size
        viewController.view.frame = CGRect(origin: .zero, size: AdSizeBanner.size)
        
        view.load(Request())
        
        return viewController
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}
