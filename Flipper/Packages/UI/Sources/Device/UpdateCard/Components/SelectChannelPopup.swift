import Core

import SwiftUI

struct SelectChannelPopup: View {
    let onChannelSelected: (Update.Channel) -> Void

    var body: some View {
        HStack {
            Spacer()
            Card {
                VStack(alignment: .leading, spacing: 0) {
                    ChannelMenuRow(
                        title: "Release",
                        color: .release,
                        description: "Stable release (recommended)",
                        onPress: { onChannelSelected(.release) }
                    )
                    .padding(12)

                    Divider()
                        .padding(0)

                    ChannelMenuRow(
                        title: "Release-Candidate",
                        color: .candidate,
                        description: "Pre-release under testing",
                        onPress: { onChannelSelected(.candidate) }
                    )
                    .padding(12)

                    Divider()
                        .padding(0)

                    ChannelMenuRow(
                        title: "Development",
                        color: .development,
                        description: "Daily unstable build, lots of bugs",
                        onPress: { onChannelSelected(.development) }
                    )
                    .padding(12)

                    Divider()
                        .padding(0)

                    ChannelMenuRow(
                        title: "Custom",
                        color: .custom,
                        description: "Upload file with custom firmware",
                        onPress: { onChannelSelected(.custom) }
                    )
                    .padding(12)
                }
            }
            .frame(width: 220)
        }
    }
}

struct ChannelMenuRow: View {
    let title: String
    let color: Color
    let description: String
    var onPress: () -> Void

    var body: some View {
        Button {
            onPress()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(color)
                    Text(description)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.black40)
                }
                Spacer()
            }
        }
    }
}
