// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "MouseLocator",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "MouseLocator", targets: ["MouseLocator"])
  ],
  targets: [
    .executableTarget(name: "MouseLocator")
  ]
)

