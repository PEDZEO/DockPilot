//
//  ProfileListView.swift
//  DockPilot
//
//

import SwiftUI
import SwiftData

struct ProfileListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @StateObject private var shortcutPreferences = ShortcutPreferences.shared
    @Query(sort: \Profile.sortOrder) private var profiles: [Profile]
    
    @Binding var selectedProfile: Profile?
    @Binding var showingNewProfile: Bool
    
    let currentProfileID: UUID?
    let onApply: @MainActor @Sendable (Profile) async -> Void
    let onRefresh: @MainActor @Sendable (Profile) async -> Void
    let onDuplicate: @MainActor @Sendable (Profile) -> Void
    
    @State private var profileToEdit: Profile?
    @State private var applyingProfile: Profile?
    @State private var deletingProfile: Profile?
    
    var body: some View {
        List(selection: $selectedProfile) {
            ForEach(profiles) { profile in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(profile.name)
                                .font(.headline)
                            
                            if profile.isDefault {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                        
                        Text(AppLocalization.string("%d items", locale: locale, profile.items.count))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if profile.id == currentProfileID {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                    
                    if applyingProfile?.id == profile.id {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
                .tag(profile)
                .contextMenu {
                    Button("Apply Profile") {
                        Task {
                            applyingProfile = profile
                            await onApply(profile)
                            applyingProfile = nil
                        }
                    }
                    
                    Button("Refresh from Dock") {
                        Task {
                            await onRefresh(profile)
                        }
                    }
                    
                    Divider()
                    
                    Button("Duplicate") {
                        onDuplicate(profile)
                    }
                    
                    Button("Rename") {
                        profileToEdit = profile
                    }
                    
                    Divider()
                    
                    Button("Delete", role: .destructive) {
                        deletingProfile = profile
                    }
                }
            }
        }
        .navigationTitle("Profiles")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNewProfile = true
                } label: {
                    Label("New Profile", systemImage: "plus")
                }
            }
        }
        .sheet(item: $profileToEdit) { profile in
            NavigationStack {
                ProfileFormView(profile: profile) { _ in
                    // Profile updated
                }
            }
        }
        .alert("Delete Profile", isPresented: .constant(deletingProfile != nil), presenting: deletingProfile) { profile in
            Button("Cancel", role: .cancel) {
                deletingProfile = nil
            }
            Button("Delete", role: .destructive) {
                deleteProfile(profile)
            }
        } message: { profile in
            Text(AppLocalization.string(
                "Are you sure you want to delete '%@'? This action cannot be undone.",
                locale: locale,
                profile.name
            ))
        }
    }
    
    private func deleteProfile(_ profile: Profile) {
        withAnimation {
            if selectedProfile?.id == profile.id {
                selectedProfile = nil
            }

            let replacement = profiles.first { $0.id != profile.id }
            if profile.id == currentProfileID {
                if let replacement {
                    DockStateManager.shared.setCurrentProfile(replacement)
                } else {
                    DockStateManager.shared.clearCurrentProfile()
                }
            }

            if profile.isDefault, let replacement {
                replacement.isDefault = true
            }
            modelContext.delete(profile)
            shortcutPreferences.removeAssignment(for: profile.id)
            do {
                try modelContext.save()
            } catch {
                print("❌ Failed to delete profile: \(error)")
            }
        }
        deletingProfile = nil
    }
}
