struct TunerSectionView: View {
    @Binding var isTunerOn: Bool
    let toggleAction: (Bool) -> Void

    var body: some View {
        Section("Tuner") {
            Toggle("Play A 440", isOn: $isTunerOn)
                .onChange(of: isTunerOn) { newValue in
                    toggleAction(newValue)
                }
        }
    }
}