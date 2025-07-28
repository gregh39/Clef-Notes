import SwiftUI
import Combine
import CoreData

struct StudentCellView: View {
    @ObservedObject var student: StudentCD
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            if let avatarData = student.avatar, let uiImage = UIImage(data: avatarData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading) {
                Text(student.name ?? "Unknown Student")
                    .font(.headline)
                    .fontWeight(.bold)
                Text(student.instrument ?? "No Instrument")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
