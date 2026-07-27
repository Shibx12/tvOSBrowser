//
//  SceneDelegate.m
//  Browser
//

#import "SceneDelegate.h"
#import "AppDelegate.h"

@implementation SceneDelegate

- (AppDelegate *)applicationDelegate {
    return (AppDelegate *)UIApplication.sharedApplication.delegate;
}

- (void)scene:(UIScene *)scene
willConnectToSession:(UISceneSession *)session
      options:(UISceneConnectionOptions *)connectionOptions {
    if (![scene isKindOfClass:[UIWindowScene class]]) {
        return;
    }

    // When a storyboard is configured in UIApplicationSceneManifest, UIKit
    // creates the window and attaches it to this scene automatically.
}

- (void)sceneWillResignActive:(UIScene *)scene {
    [[self applicationDelegate] saveCookiesToDefaults];
}

- (void)sceneDidEnterBackground:(UIScene *)scene {
    [[self applicationDelegate] saveCookiesToDefaults];
}

- (void)sceneWillEnterForeground:(UIScene *)scene {
    [[self applicationDelegate] restoreCookiesFromDefaults];
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    [[self applicationDelegate] restoreCookiesFromDefaults];
}

@end
