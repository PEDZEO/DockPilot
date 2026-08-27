//
//  DockCommandRunner.swift
//  DockPilot
//

import Foundation

struct DockCommandRunner {
    func run(_ executablePath: String, arguments: [String]) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            guard FileManager.default.fileExists(atPath: executablePath) else {
                throw DockUtilError.commandFailed("File does not exist: \(executablePath)")
            }

            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                throw DockUtilError.commandFailed(error.localizedDescription)
            }

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8) ?? ""
            let errorOutput = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard process.terminationStatus == 0 else {
                let message = errorOutput.isEmpty
                    ? "Command exited with code \(process.terminationStatus)"
                    : errorOutput
                throw DockUtilError.commandFailed(message)
            }

            return output
        }.value
    }
}
