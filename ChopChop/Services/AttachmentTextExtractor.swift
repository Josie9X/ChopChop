import Foundation
import PDFKit
import UIKit
import UniformTypeIdentifiers
import Vision

enum AttachmentTextExtractor {
    static func attachment(fromFileURL url: URL) async throws -> UploadedAttachment {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let fileName = url.lastPathComponent
        let mimeType = mimeType(for: url.pathExtension)
        let extractedText = try await extractText(data: data, fileName: fileName, mimeType: mimeType)
        let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw PlanningError.documentParsingFailed
        }
        debugLog("fileName=\(fileName), size=\(data.count), extractedTextLength=\(trimmedText.count)")

        let shouldSendRawFile = mimeType == "application/pdf"
        return UploadedAttachment(
            fileName: fileName,
            mimeType: mimeType,
            fileSize: data.count,
            extractedText: trimmedText,
            fileBase64: shouldSendRawFile ? data.base64EncodedString() : nil
        )
    }

    static func attachment(fromPhotoData data: Data, fileName: String = "相册图片.jpg") async throws -> UploadedAttachment {
        let extractedText = try await extractImageText(data)
        let trimmedText = extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw PlanningError.documentParsingFailed
        }
        debugLog("fileName=\(fileName), size=\(data.count), extractedTextLength=\(trimmedText.count)")

        return UploadedAttachment(
            fileName: fileName,
            mimeType: "image/jpeg",
            fileSize: data.count,
            extractedText: trimmedText,
            fileBase64: nil
        )
    }

    private static func extractText(data: Data, fileName: String, mimeType: String) async throws -> String {
        if mimeType == "application/pdf" {
            return extractPDFText(data) ?? ""
        }

        if mimeType.hasPrefix("image/") {
            return try await extractImageText(data)
        }

        if let text = String(data: data, encoding: .utf8) {
            return text
        }

        throw PlanningError.documentParsingFailed
    }

    private static func extractPDFText(_ data: Data) -> String? {
        guard let document = PDFDocument(data: data) else { return nil }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            if let text = document.page(at: index)?.string {
                pages.append(text)
            }
        }
        return pages.joined(separator: "\n")
    }

    private static func extractImageText(_ data: Data) async throws -> String {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            throw PlanningError.documentParsingFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage)
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private static func mimeType(for pathExtension: String) -> String {
        if let type = UTType(filenameExtension: pathExtension),
           let mimeType = type.preferredMIMEType {
            return mimeType
        }
        return "application/octet-stream"
    }

    private static func debugLog(_ message: String) {
        guard AppConfig.networkLoggingEnabled else { return }
        print("[AttachmentTextExtractor] \(message)")
    }
}
