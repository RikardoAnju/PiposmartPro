// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "url_launcher_ios", path: "../.packages/url_launcher_ios-6.4.1"),
        .package(name: "shared_preferences_foundation", path: "../.packages/shared_preferences_foundation-2.5.6"),
        .package(name: "share_plus", path: "../.packages/share_plus-12.0.2"),
        .package(name: "mobile_scanner", path: "../.packages/mobile_scanner-7.2.0"),
        .package(name: "image_picker_ios", path: "../.packages/image_picker_ios-0.8.13+6"),
        .package(name: "google_sign_in_ios", path: "../.packages/google_sign_in_ios-5.9.0"),
        .package(name: "flutter_secure_storage_darwin", path: "../.packages/flutter_secure_storage_darwin-0.3.2"),
        .package(name: "flutter_local_notifications", path: "../.packages/flutter_local_notifications-21.0.0"),
        .package(name: "flutter_contacts", path: "../.packages/flutter_contacts-2.1.0"),
        .package(name: "firebase_messaging", path: "../.packages/firebase_messaging-16.2.2"),
        .package(name: "firebase_core", path: "../.packages/firebase_core-4.9.0"),
        .package(name: "file_picker", path: "../.packages/file_picker-10.3.10"),
        .package(name: "device_info_plus", path: "../.packages/device_info_plus-12.4.0"),
        .package(name: "sqflite_darwin", path: "../.packages/sqflite_darwin-2.4.3"),
        .package(name: "app_links", path: "../.packages/app_links-7.0.0"),
        .package(name: "FlutterFramework", path: "../.packages/FlutterFramework")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "url-launcher-ios", package: "url_launcher_ios"),
                .product(name: "shared-preferences-foundation", package: "shared_preferences_foundation"),
                .product(name: "share-plus", package: "share_plus"),
                .product(name: "mobile-scanner", package: "mobile_scanner"),
                .product(name: "image-picker-ios", package: "image_picker_ios"),
                .product(name: "google-sign-in-ios", package: "google_sign_in_ios"),
                .product(name: "flutter-secure-storage-darwin", package: "flutter_secure_storage_darwin"),
                .product(name: "flutter-local-notifications", package: "flutter_local_notifications"),
                .product(name: "flutter-contacts", package: "flutter_contacts"),
                .product(name: "firebase-messaging", package: "firebase_messaging"),
                .product(name: "firebase-core", package: "firebase_core"),
                .product(name: "file-picker", package: "file_picker"),
                .product(name: "device-info-plus", package: "device_info_plus"),
                .product(name: "sqflite-darwin", package: "sqflite_darwin"),
                .product(name: "app-links", package: "app_links"),
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
