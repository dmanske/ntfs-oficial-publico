// swift-tools-version:5.9
// Pacote do app NTFS Oficial: o Motor (sem tela, testável) e o app SwiftUI.
// Sem dependências externas e sem recursos (os textos ficam em código: Shared/Texto.swift).
import PackageDescription

let package = Package(
    name: "NTFSOficial",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NTFSOficial", targets: ["NTFSOficial"]),
        .library(name: "NTFSOficialMotor", targets: ["NTFSOficialMotor"]),
    ],
    targets: [
        .target(
            name: "NTFSOficialMotor",
            linkerSettings: [.linkedFramework("DiskArbitration")]
        ),
        .executableTarget(
            name: "NTFSOficial",
            dependencies: ["NTFSOficialMotor"]
        ),
        .testTarget(
            name: "NTFSOficialMotorTests",
            dependencies: ["NTFSOficialMotor"]
        ),
    ]
)
