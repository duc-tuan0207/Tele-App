//
//  SceneDelegate.swift
//  Tele-App
//
//  Created by Dezhun on 6/2/26.
//

import UIKit
import FirebaseAuth

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    // TODO: - Check Auth
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        self.setupWindow(with: scene)
        self.checkAuthentication()
        
    }
    
    private func setupWindow(with scene: UIScene) {
            guard let windowScene = (scene as? UIWindowScene) else { return }
            let window = UIWindow(windowScene: windowScene)
            self.window = window
            self.window?.makeKeyAndVisible()
        }
    
    public func checkAuthentication(){
        if Auth.auth().currentUser == nil {
            gotoController(with: LoginController())
        } else {
            gotoController(with: HomeController())
        }
    }
    private func gotoController(with viewController: UIViewController){
        DispatchQueue.main.async { [weak self] in
            UIView.animate(withDuration: 0.25){
                self?.window?.layer.opacity = 0
            } completion: { [weak self] _ in

                let nav = UINavigationController(rootViewController: viewController)
                nav.modalPresentationStyle = .fullScreen
                self?.window?.rootViewController = nav
                
                UIView.animate(withDuration: 0.25) { [weak self] in
                    self?.window?.layer.opacity = 1
                }
            }
            
        }
    }
}
