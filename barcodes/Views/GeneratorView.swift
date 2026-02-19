import SwiftData
import SwiftUI

struct GeneratorView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedType: BarcodeType = .qr
    @State private var inputText = ""
    @State private var descriptionText = ""
    @State private var showSavedConfirmation = false
    @State private var isSaving = false
    @State private var previewImage: UIImage?
    @FocusState private var focusedField: Field?

    // Advanced options state
    @State private var qrCorrectionLevel: QRCorrectionLevel = .medium
    @State private var aztecCorrectionLevel: Double = 23
    @State private var aztecCompactStyle = false
    @State private var pdf417CorrectionLevel: Int = 0
    @State private var pdf417CompactionMode: PDF417CompactionMode = .automatic
    @State private var pdf417CompactStyle = false
    @State private var pdf417ColumnCount: Int = 0

    var onSave: ((ScannedBarcode) -> Void)?

    private enum Field { case input, description }

    private var supportsMultiline: Bool {
        switch selectedType {
        case .qr, .pdf417, .aztec, .dataMatrix: true
        default: false
        }
    }

    /// Localized explicitly - ternary/switch results are String, not LocalizedStringKey
    private var multilinePlaceholder: String {
        switch selectedType {
        case .qr:
            String(localized: "Enter URL, text, or other content",
                   comment: "Placeholder for QR code multiline input")
        case .pdf417, .aztec, .dataMatrix:
            String(localized: "Enter text content",
                   comment: "Placeholder for multiline barcode input")
        default: String(localized: "Enter value", comment: "Placeholder for the barcode value input in the generator")
        }
    }

    private var validation: BarcodeValidator.ValidationResult {
        BarcodeValidator.validate(inputText, for: selectedType)
    }

    private var previewTaskID: String {
        var id = "\(selectedType.rawValue):\(inputText)"
        switch selectedType {
        case .qr:
            id += "|ecc:\(qrCorrectionLevel.rawValue)"
        case .aztec:
            id += "|ecc:\(Int(aztecCorrectionLevel))|compact:\(aztecCompactStyle)"
        case .pdf417:
            id += "|ecc:\(pdf417CorrectionLevel)|mode:\(pdf417CompactionMode.rawValue)"
            id += "|compact:\(pdf417CompactStyle)|cols:\(pdf417ColumnCount)"
        default:
            break
        }
        return id
    }

    var body: some View {
        NavigationStack {
            Form {
                previewSection
                typeSection
                inputSection
                GeneratorAdvancedOptionsSection(
                    selectedType: selectedType,
                    qrCorrectionLevel: $qrCorrectionLevel,
                    aztecCorrectionLevel: $aztecCorrectionLevel,
                    aztecCompactStyle: $aztecCompactStyle,
                    pdf417CorrectionLevel: $pdf417CorrectionLevel,
                    pdf417CompactionMode: $pdf417CompactionMode,
                    pdf417CompactStyle: $pdf417CompactStyle,
                    pdf417ColumnCount: $pdf417ColumnCount
                )
                notesSection
                saveSection
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Create")
            .overlay {
                if showSavedConfirmation {
                    savedOverlay
                }
            }
            .task(id: previewTaskID) {
                guard validation.isValid else {
                    previewImage = nil
                    return
                }
                let barcode = createBarcodeWithOptions(rawValue: inputText, type: selectedType)
                let size = CGSize(width: 200, height: 200)
                let key = BarcodeImageCache.cacheKey(
                    rawValue: barcode.rawValue,
                    type: barcode.type.rawValue,
                    descriptorArchive: nil,
                    width: Int(size.width),
                    height: Int(size.height),
                    generatorOptions: barcode.generatorOptionsKey
                )
                if let cached = BarcodeImageCache.shared.image(for: key) {
                    previewImage = cached
                    return
                }
                if let diskHit = await BarcodeImageCache.shared.cachedImage(for: key) {
                    previewImage = diskHit
                    return
                }
                if let generated = BarcodeGenerator.generateImage(for: barcode, size: size) {
                    await BarcodeImageCache.shared.storeImage(generated, for: key)
                    previewImage = generated
                }
            }
        }
    }

    // MARK: - Preview

    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                if let previewImage {
                    Image(uiImage: previewImage)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                } else {
                    Image(systemName: "barcode.viewfinder")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                        .frame(width: 200, height: 200)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .onTapGesture { focusedField = nil }
        }
    }

    // MARK: - Type Picker

    private var typeSection: some View {
        Section {
            Picker("Barcode Type", selection: $selectedType) {
                ForEach(BarcodeType.allCases, id: \.self) { type in
                    Text(type.localizedName).tag(type)
                }
            }
            .accessibilityIdentifier("barcode-type-picker")
        } footer: {
            Text(BarcodeValidator.hint(for: selectedType))
        }
        .onChange(of: selectedType) {
            if !inputText.isEmpty, !BarcodeValidator.validate(inputText, for: selectedType).isValid {
                inputText = ""
            }
            resetAdvancedOptions()
        }
    }

    // MARK: - Input Field

    private var inputSection: some View {
        Section {
            if !inputText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: validation.isValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(validation.isValid ? .green : .red)
                        .font(.subheadline)
                    Text(validation.message)
                        .font(.subheadline)
                        .foregroundColor(validation.isValid ? .secondary : .red)
                }
            }

            if supportsMultiline {
                TextEditor(text: $inputText)
                    .focused($focusedField, equals: .input)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .frame(minHeight: 80)
                    .accessibilityIdentifier("barcode-input-editor")
                    .id(selectedType)
                    .overlay(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text(multilinePlaceholder)
                                .foregroundStyle(.placeholder)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
            } else {
                TextField("Enter value", text: $inputText)
                    .focused($focusedField, equals: .input)
                    .keyboardType(BarcodeValidator.keyboardType(for: selectedType))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityIdentifier("barcode-input-field")
                    .id(selectedType)
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        Section("Notes") {
            TextField("Description (optional)", text: $descriptionText)
                .focused($focusedField, equals: .description)
        }
    }

    // MARK: - Save

    private var saveSection: some View {
        Section {
            Button {
                save()
            } label: {
                HStack {
                    Spacer()
                    Label("Save Barcode", systemImage: "square.and.arrow.down")
                        .font(.headline)
                    Spacer()
                }
            }
            .disabled(!validation.isValid || isSaving)
        }
    }

    private func save() {
        isSaving = true

        let barcode = createBarcodeWithOptions(rawValue: inputText, type: selectedType)
        barcode.barcodeDescription = descriptionText.isEmpty ? nil : descriptionText
        barcode.isGenerated = true
        modelContext.insert(barcode)

        UINotificationFeedbackGenerator().notificationOccurred(.success)

        withAccessibleAnimation {
            showSavedConfirmation = true
        }

        Task {
            try? await Task.sleep(for: .seconds(1.2))
            withAccessibleAnimation {
                showSavedConfirmation = false
            }
            onSave?(barcode)
            resetForm()
            isSaving = false
        }
    }

    private func resetForm() {
        inputText = ""
        descriptionText = ""
        resetAdvancedOptions()
    }

    private func resetAdvancedOptions() {
        qrCorrectionLevel = .medium
        aztecCorrectionLevel = 23
        aztecCompactStyle = false
        pdf417CorrectionLevel = 0
        pdf417CompactionMode = .automatic
        pdf417CompactStyle = false
        pdf417ColumnCount = 0
    }

    private func createBarcodeWithOptions(rawValue: String, type: BarcodeType) -> ScannedBarcode {
        var correctionLevel: String?
        var isCompactStyle = false
        var compactionMode: String?
        var columnCount: Int?

        switch type {
        case .qr:
            if qrCorrectionLevel != .medium {
                correctionLevel = qrCorrectionLevel.rawValue
            }
        case .aztec:
            correctionLevel = String(Int(aztecCorrectionLevel))
            isCompactStyle = aztecCompactStyle
        case .pdf417:
            if pdf417CorrectionLevel != 0 {
                correctionLevel = String(pdf417CorrectionLevel)
            }
            if pdf417CompactionMode != .automatic {
                compactionMode = pdf417CompactionMode.rawValue
            }
            if pdf417CompactStyle {
                isCompactStyle = true
            }
            if pdf417ColumnCount != 0 {
                columnCount = pdf417ColumnCount
            }
        default:
            break
        }

        return ScannedBarcode(
            rawValue: rawValue,
            type: type,
            correctionLevel: correctionLevel,
            isCompactStyle: isCompactStyle,
            compactionMode: compactionMode,
            columnCount: columnCount
        )
    }

    // MARK: - Saved Overlay

    private var savedOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Saved")
                .font(.headline)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .transition(.scale.combined(with: .opacity))
    }
}
