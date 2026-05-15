// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "RoomLightSensor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "RoomLightSensor",
            targets: ["RoomLightSensor"]
        )
    ],
    targets: [
        .target(
            name: "RoomLightSensorCore"
        ),
        .executableTarget(
            name: "RoomLightSensor",
            dependencies: ["RoomLightSensorCore"]
        ),
        .testTarget(
            name: "RoomLightSensorCoreTests",
            dependencies: ["RoomLightSensorCore"]
        )
    ]
)
