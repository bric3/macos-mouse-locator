// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "MouseLocator",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "MouseLocator", targets: ["MouseLocator"]),
    .executable(name: "MouseLocatorCheck", targets: ["MouseLocatorCheck"]),
  ],
  targets: [
    .target(name: "MouseLocatorCore"),
    .executableTarget(
      name: "MouseLocator",
      dependencies: ["MouseLocatorCore"]
    ),
    .executableTarget(
      name: "MouseLocatorCheck",
      dependencies: ["MouseLocatorCore"]
    )
  ]
)
