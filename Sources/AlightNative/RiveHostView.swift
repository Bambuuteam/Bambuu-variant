import SwiftUI
import RiveRuntime

struct RiveHostView: View {
    @StateObject private var viewModel = RiveViewModel(fileName: "quick_start", in: Bundle.module)

    var body: some View {
        viewModel.view()
            .frame(width: 200, height: 200)
            .border(Color.white.opacity(0.3))
    }
}
