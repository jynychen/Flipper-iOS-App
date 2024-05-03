import Core
import SwiftUI

struct AppsView: View {
    @EnvironmentObject var model: Applications
    @EnvironmentObject var router: Router
    @Environment(\.dismiss) var dismiss

    @AppStorage(.selectedTab) private var selectedTab: TabView.Tab = .device

    @State private var selectedSegment: AppsSegments.Segment = .all

    @State private var predicate = ""
    @State private var showSearchView = false

    @State private var sharedApp: SharedApp = .init()

    struct SharedApp {
        var alias: String?
        var show = false
    }

    @State private var isNotConnectedAlertPresented = false

    var allSelected: Bool {
        selectedSegment == .all
    }

    var installedSelected: Bool {
        selectedSegment == .installed
    }

    init() {
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AllAppsView()
                    .opacity(allSelected && predicate.isEmpty ? 1 : 0)

                InstalledAppsView()
                    .opacity(installedSelected && predicate.isEmpty ? 1 : 0)

                AppSearchView(predicate: $predicate)
                    .environmentObject(model)
                    .opacity(!predicate.isEmpty ? 1 : 0)

                NavigationLink("", isActive: $sharedApp.show) {
                    if let alias = sharedApp.alias {
                        AppView(alias: alias)
                    }
                }
            }
            .background(Color.background)
            .navigationBarBackground(Color.a1)
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showSearchView {
                    LeadingToolbarItems {
                        SearchButton { }
                            .opacity(0)
                    }

                    PrincipalToolbarItems {
                        AppsSegments(selected: $selectedSegment)
                    }

                    TrailingToolbarItems {
                        SearchButton {
                            selectedSegment = .all
                            showSearchView = true
                        }
                        .analyzingTapGesture {
                            recordSearchOpened()
                        }
                    }
                } else {
                    PrincipalToolbarItems {
                        HStack(spacing: 14) {
                            SearchField(
                                placeholder: "App name, description",
                                predicate: $predicate
                            )

                            CancelSearchButton {
                                predicate = ""
                                showSearchView = false
                            }
                        }
                    }
                }
            }
        }
        .onReceive(router.showApps) {
            selectedSegment = .installed
            selectedTab = .apps
        }
        .onOpenURL { url in
            if url.isApplicationURL {
                sharedApp.alias = url.applicationAlias
                selectedTab = .apps
                sharedApp.show = true
            }
        }
    }

    // MARK: Analytics

    func recordSearchOpened() {
        analytics.appOpen(target: .fapHubSearch)
    }
}
