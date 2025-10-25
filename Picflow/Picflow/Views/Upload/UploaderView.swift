//
//  UploaderView.swift
//  Picflow
//
//  Created by AI Assistant
//

import SwiftUI

struct UploaderView: View {
    @ObservedObject var uploader: Uploader
    @ObservedObject var authenticator: Authenticator
    let onBack: () -> Void
    @State private var isDragging = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Back Button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Galleries")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Dropzone (fills available vertical space)
            DropzoneView(isDragging: $isDragging, onFilesSelected: handleFilesSelected)
                .frame(maxHeight: .infinity)
            
            // Bottom components
            VStack(spacing: 16) {
                // Upload Progress (when uploading or just completed)
                if (uploader.isUploading && !uploader.uploadQueue.isEmpty) || uploader.uploadState == .completed {
                    UploadProgressView(uploader: uploader)
                }
                
                // Capture One Integration
                CaptureOneStatusView(uploader: uploader)
            }
            .padding(.top, 16)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
    }
    
    // MARK: - File Handling
    
    private func handleFilesSelected(_ urls: [URL]) {
        print("📁 Files selected: \(urls.count)")
        uploader.queueFiles(urls)
    }
}

// MARK: - Dropzone View

struct DropzoneView: View {
    @Binding var isDragging: Bool
    let onFilesSelected: ([URL]) -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                // Upload Icon (96px placeholder)
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 96, height: 96)
                    
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.accentColor)
                }
                
                // Title
                Text("Upload")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)
                
                // Description
                Text("Drag and drop or choose files to upload to Picflow.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                // Choose Files Button
                Button("Choose Files") {
                    selectFiles()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 8])
                )
                .foregroundColor(Color.primary.opacity(isDragging ? 0.5 : 0.2))
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
            return true
        }
    }
    
    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .jpeg, .png, .heic, .rawImage]
        
        if panel.runModal() == .OK {
            onFilesSelected(panel.urls)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var collectedURLs: [URL] = []
        let lock = NSLock()
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, error) in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    lock.lock()
                    collectedURLs.append(url)
                    lock.unlock()
                }
                group.leave()
            }
        }
        
        // Wait for all files to be collected, then call handler once
        group.notify(queue: .main) {
            if !collectedURLs.isEmpty {
                onFilesSelected(collectedURLs)
            }
        }
    }
}

// MARK: - Upload Progress View

struct UploadProgressView: View {
    @ObservedObject var uploader: Uploader
    
    var body: some View {
        let totalFiles = uploader.uploadQueue.count
        let currentIndex = uploader.currentFileIndex + 1
        
        // Format speed in Mbps
        let speedMbps = (uploader.uploadSpeed * 8) / 1_000_000
        let speedText = String(format: "%.1f Mbit/s", speedMbps)
        
        // Format remaining time
        let timeRemaining = Int(uploader.estimatedTimeRemaining)
        let timeText = timeRemaining > 0 ? "\(timeRemaining)s remaining" : ""
        
        // Build description
        let description: String
        if uploader.uploadState == .completed {
            description = "All files uploaded successfully"
        } else if totalFiles > 1 {
            var parts: [String] = []
            parts.append("\(currentIndex) of \(totalFiles)")
            if !timeText.isEmpty {
                parts.append(timeText)
            }
            if speedMbps > 0 {
                parts.append(speedText)
            }
            description = parts.joined(separator: ", ")
        } else {
            description = speedMbps > 0 ? speedText : "Uploading..."
        }
        
        return GenericUploadProgressView(
            state: uploader.uploadState,
            description: description
        )
    }
}

// MARK: - Generic Upload Progress View

struct GenericUploadProgressView: View {
    let state: UploadState
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Left side: Icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: statusIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(statusColor)
            }
            
            // Middle: Title and Status
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    private var statusTitle: String {
        switch state {
        case .completed:
            return "Completed"
        default:
            return "Uploading"
        }
    }
    
    private var statusIcon: String {
        switch state {
        case .completed:
            return "checkmark.circle.fill"
        case .failed:
            return "exclamationmark.triangle.fill"
        default:
            return "arrow.up.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .completed:
            return .green
        case .failed:
            return .red
        default:
            return .accentColor
        }
    }
}

