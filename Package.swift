// swift-tools-version: 6.0

// Copyright 2026 Brice Dutheil
// SPDX-License-Identifier: MPL-2.0

import PackageDescription

let package = Package(
  name: "MouseLocator",
  platforms: [.macOS(.v14)],
  products: [
    .executable(name: "MouseLocator", targets: ["MouseLocator"]),
    .executable(name: "MouseLocatorCapture", targets: ["MouseLocatorCapture"]),
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
    ),
    .executableTarget(
      name: "MouseLocatorCapture",
      dependencies: ["MouseLocatorCore"]
    ),
  ]
)
