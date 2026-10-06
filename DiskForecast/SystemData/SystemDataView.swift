import SwiftUI

struct SystemDataView: View {
    let model: SystemDataModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("System Data, explained").font(.title2.bold())
                    Text("What macOS files under System Data in Storage settings, and how to reclaim it with "
                        + "Apple's and each tool's own commands. Nothing runs until you confirm.")
                        .font(.callout).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if model.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Button("Refresh") { model.load() }
                }
            }
            .padding()
            Divider()
            List(model.rows) { row in
                SystemDataRowView(row: row, model: model)
            }
            .overlay {
                if model.rows.isEmpty && model.isLoading {
                    ProgressView("Measuring…")
                }
            }
        }
        .onAppear { model.load() }
    }
}

private struct SystemDataRowView: View {
    let row: SystemDataRow
    let model: SystemDataModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title).font(.body.weight(.medium))
                Spacer()
                if let bytes = row.bytes {
                    Text(Bytes.format(bytes)).monospacedDigit().font(.body.weight(.medium))
                } else if let note = row.sizeNote {
                    Text(note).foregroundStyle(.secondary)
                }
            }
            if row.bytes != nil, let note = row.sizeNote {
                Text(note).font(.caption).foregroundStyle(.secondary)
            }
            Text(row.explanation).font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !row.details.isEmpty {
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(row.details, id: \.self) { Text($0) }
                }
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            }
            if !row.fixes.isEmpty {
                FlowButtons(fixes: row.fixes, model: model)
            }
        }
        .padding(.vertical, 6)
    }
}

private struct FlowButtons: View {
    let fixes: [SystemDataFix]
    let model: SystemDataModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(fixes) { fix in
                HStack(spacing: 6) {
                    Button(fix.title + "…") { model.perform(fix) }
                        .disabled(model.runningFix != nil)
                    if model.runningFix == fix.id {
                        ProgressView().controlSize(.small)
                    }
                }
            }
        }
        .controlSize(.small)
    }
}
