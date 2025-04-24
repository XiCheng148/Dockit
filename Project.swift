import ProjectDescription
// MARK: - Version
let appVersion = "0.3.5"  // 应用版本号
let buildVersion = "@BUILD_NUMBER@"  // 构建版本号占位符，会被 GitHub Actions 替换

let project = Project(
    name: "Dockit",
    options: .options(
        defaultKnownRegions: ["zh-Hans", "zh-Hant", "en"],
        developmentRegion: "zh-Hans"
    ),
    packages: [
        // .remote(url: "https://github.com/SwiftUIX/SwiftUIX", requirement: .upToNextMajor(from: "0.1.9")),
        // .remote(url: "https://github.com/SwifterSwift/SwifterSwift", requirement: .upToNextMajor(from: "7.0.0")),
        .remote(url: "https://github.com/sindresorhus/Defaults", requirement: .upToNextMajor(from: "8.2.0")),
        .remote(url: "https://github.com/MrKai77/DynamicNotchKit", requirement: .upToNextMajor(from: "0.1.0")),
        .remote(url: "https://github.com/sindresorhus/LaunchAtLogin-Modern", requirement: .branch("main")),
        .remote(url: "https://github.com/sindresorhus/KeyboardShortcuts", requirement: .branch("main")),
    ],
    settings: .settings(
        base: [
            // 添加 SkyLight 框架
            "OTHER_LDFLAGS": ["-framework", "SkyLight"],
            // 添加 SkyLight 框架搜索路径
            "FRAMEWORK_SEARCH_PATHS": ["$(inherited)", "/System/Library/PrivateFrameworks"],
            "SWIFT_VERSION": SettingValue(stringLiteral: "5.9"),
            "DEVELOPMENT_LANGUAGE": SettingValue(stringLiteral: "zh-Hans"),
            "SWIFT_EMIT_LOC_STRINGS": SettingValue(stringLiteral: "YES"),
            "MARKETING_VERSION": SettingValue(stringLiteral: appVersion),
            "CURRENT_PROJECT_VERSION": SettingValue(stringLiteral: buildVersion)
        ],
        configurations: [
            .debug(name: "Debug"),
            .release(name: "Release")
        ]
    ),
    targets: [
        .target(
            name: "Dockit",
            destinations: .macOS,
            product: .app,
            bundleId: "io.tuist.Dockit",
            deploymentTargets: .macOS("13.5"),
            infoPlist: .extendingDefault(with: [
                "LSUIElement": true,  // 设置为纯菜单栏应用
                "CFBundleDevelopmentRegion": "zh-Hans",  // 设置默认开发区域为简体中文
                "CFBundleLocalizations": ["zh-Hans", "zh-Hant", "en"],  // 支持的语言列表
                "AppleLanguages": ["zh-Hans"],  // 设置默认语言为简体中文
                "NSHumanReadableCopyright": "Copyright © 2024 XiCheng. All rights reserved.",
                "LSApplicationCategoryType": "public.app-category.utilities",
                "LSMinimumSystemVersion": "13.5",
                "CFBundleShortVersionString": .string(appVersion),  // 市场版本号
                "CFBundleVersion": .string(buildVersion)  // 构建版本号
            ]),
            sources: ["Dockit/Sources/**"],
            resources: ["Dockit/Resources/**"],
            entitlements: .file(path: "Tuist/Signing/Dockit.entitlements"),
            dependencies: [
                .package(product: "Defaults"),
                // .package(product: "SwiftUIX"),
                // .package(product: "SwifterSwift"),
                .package(product: "KeyboardShortcuts"),
                .package(product: "LaunchAtLogin"),
                .package(product: "DynamicNotchKit"),
                // .sdk(name: "SkyLight", type: .framework, status: .required)
                // .framework(path: "/System/Library/PrivateFrameworks/SkyLight.framework")
            ],
            settings: .settings(
                base: [
                    "DEVELOPMENT_LANGUAGE": "zh-Hans",
                    "SWIFT_VERSION": "5.9",
                    "SWIFT_EMIT_LOC_STRINGS": "YES"
                ],
                configurations: [
                    .debug(name: "Debug"),
                    .release(name: "Release")
                ]
            )
        ),
        .target(
            name: "DockitTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "io.tuist.DockitTests",
            infoPlist: .default,
            sources: ["Dockit/Tests/**"],
            resources: [],
            dependencies: [.target(name: "Dockit")]
        ),
    ]
)
