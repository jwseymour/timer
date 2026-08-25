// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PomodoroUp",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .target(
            name: "PomodoroFormula",
            path: "Sources/PomodoroFormula"
        ),
        .testTarget(
            name: "PomodoroFormulaTests",
            dependencies: ["PomodoroFormula"],
            path: "Tests/PomodoroFormulaTests"
        ),
        .executableTarget(
            name: "PomodoroUp",
            dependencies: ["PomodoroFormula"],
            path: "Sources/PomodoroUp"
        ),
        .testTarget(
            name: "PomodoroUpTests",
            dependencies: ["PomodoroUp"],
            path: "Tests/PomodoroUpTests"
        )
    ]
)
