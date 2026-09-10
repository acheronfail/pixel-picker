#!/usr/bin/env swift
// Sparkle 2.9 accepts a base64-encoded 32-byte Ed25519 seed.
// CryptoKit generates the seed in memory; no Security/Keychain APIs are used.
import Foundation
import CryptoKit
import Darwin

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: ./scripts/create-sparkle-keys.swift /absolute/directory/outside/repository\n", stderr)
    exit(1)
}
let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true).resolvingSymlinksInPath()
let repository = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().resolvingSymlinksInPath()
guard CommandLine.arguments[1].hasPrefix("/"),
      directory.path != repository.path,
      !directory.path.hasPrefix(repository.path + "/") else {
    fputs("Choose an absolute directory outside this repository.\n", stderr)
    exit(1)
}
// Require a fresh private directory; refuse to overwrite any existing keys.
guard !FileManager.default.fileExists(atPath: directory.path) else {
    fputs("Refusing to use an existing output directory.\n", stderr)
    exit(1)
}
umask(0o077)
do {
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false,
                                           attributes: [.posixPermissions: 0o700])
    let key = Curve25519.Signing.PrivateKey()
    try key.rawRepresentation.base64EncodedData().write(to: directory.appendingPathComponent("sparkle-private-key"), options: .withoutOverwriting)
    try key.publicKey.rawRepresentation.base64EncodedData().write(to: directory.appendingPathComponent("sparkle-public-key"), options: .withoutOverwriting)
    print("Created keys in \(directory.path). Back up both files. No keychain changes made.")
    print("SUPublicEDKey: \(key.publicKey.rawRepresentation.base64EncodedString())")
} catch {
    fputs("Could not create keys: \(error.localizedDescription)\n", stderr)
    exit(1)
}
