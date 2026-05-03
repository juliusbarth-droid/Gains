import AVFoundation
import SwiftUI

// MARK: - Barcode Scanner Sheet

struct BarcodeScannerSheet: View {
  @EnvironmentObject private var store: GainsStore
  @Environment(\.dismiss) private var dismiss

  let mealType: RecipeMealType
  let selectedDate: Date
  let onLog: () -> Void

  @State private var scanState: BarcodeScanState = .scanning
  @State private var torchOn = false

  enum BarcodeScanState {
    case scanning
    case loading(String)           // barcode string
    case found(ScannedFoodResult)
    case notFound(String)
    case error(String)
  }

  var body: some View {
    NavigationStack {
      ZStack {
        Color.black.ignoresSafeArea()

        switch scanState {
        case .scanning:
          scannerView
        case .loading(let barcode):
          loadingView(barcode: barcode)
        case .found(let result):
          resultView(result)
        case .notFound(let barcode):
          notFoundView(barcode: barcode)
        case .error(let message):
          errorView(message: message)
        }
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Abbrechen") { dismiss() }
            .foregroundStyle(.white)
        }
        ToolbarItem(placement: .principal) {
          Text("Barcode scannen")
            .font(GainsFont.label(15))
            .foregroundStyle(.white)
        }
        if case .scanning = scanState {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button {
              torchOn.toggle()
            } label: {
              Image(systemName: torchOn ? "bolt.fill" : "bolt.slash.fill")
                .foregroundStyle(.white)
            }
          }
        }
      }
    }
    .presentationDetents([.large])
  }

  // MARK: Scanner View

  private var scannerView: some View {
    ZStack {
      // Camera preview
      BarcodeCameraPreview(torchOn: $torchOn) { barcode in
        handleBarcode(barcode)
      }
      .ignoresSafeArea()

      // Overlay
      VStack {
        Spacer()

        // Finder frame
        RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous)
          .stroke(GainsColor.lime, lineWidth: 2.5)
          .frame(width: 260, height: 130)
          .overlay(
            // Corner accents
            ZStack {
              CornerAccent().stroke(GainsColor.lime, lineWidth: 4)
            }
          )
          .shadow(color: GainsColor.lime.opacity(0.4), radius: 20)

        Text("Halte den Barcode in den Rahmen")
          .font(GainsFont.label(14))
          .foregroundStyle(.white.opacity(0.85))
          .padding(.top, 24)

        Spacer()
        Spacer()
      }
    }
  }

  // MARK: Loading

  private func loadingView(barcode: String) -> some View {
    VStack(spacing: 24) {
      Spacer()
      SwiftUI.ProgressView()
        .tint(GainsColor.lime)
        .scaleEffect(1.6)
      Text("Produkt wird gesucht…")
        .font(GainsFont.label(15))
        .foregroundStyle(.white.opacity(0.8))
      Text("EAN: \(barcode)")
        .font(GainsFont.label(11))
        .foregroundStyle(.white.opacity(0.4))
      Spacer()
    }
  }

  // MARK: Found

  private func resultView(_ result: ScannedFoodResult) -> some View {
    ZStack {
      GainsColor.background.ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(spacing: 20) {
          // Product header
          VStack(spacing: 12) {
            Image(systemName: "barcode.viewfinder")
              .font(.system(size: 36, weight: .light))
              .foregroundStyle(GainsColor.lime)

            Text(result.name)
              .font(GainsFont.title(20))
              .foregroundStyle(GainsColor.ink)
              .multilineTextAlignment(.center)

            if let brand = result.brand {
              Text(brand)
                .font(GainsFont.label(13))
                .foregroundStyle(GainsColor.mutedInk)
            }
          }
          .padding(.top, 8)

          // Nährwerte pro 100g
          VStack(spacing: 12) {
            Text("Nährwerte pro 100g")
              .font(GainsFont.label(13))
              .foregroundStyle(GainsColor.softInk)
              .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
              nutritionCell("\(result.caloriesPer100g)", unit: "kcal", label: "Kalorien", color: GainsColor.ink)
              Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
              nutritionCell("\(Int(result.proteinPer100g))g", unit: "", label: "Protein", color: GainsColor.lime)
              Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
              nutritionCell("\(Int(result.carbsPer100g))g", unit: "", label: "Kohlenhydr.", color: Color(hex: "5BC4F5"))
              Rectangle().fill(GainsColor.border.opacity(0.5)).frame(width: 1, height: 44)
              nutritionCell("\(Int(result.fatPer100g))g", unit: "", label: "Fett", color: Color(hex: "FF8A4A"))
            }
          }
          .padding(18)
          .gainsCardStyle(GainsColor.card)

          // Gram input
          BarcodeGramInputCard(result: result, mealType: mealType, selectedDate: selectedDate) {
            dismiss()
            onLog()
          }

          // Erneut scannen
          Button {
            withAnimation { scanState = .scanning }
          } label: {
            HStack(spacing: 8) {
              Image(systemName: "barcode.viewfinder")
              Text("Erneut scannen")
            }
            .font(GainsFont.label(14))
            .foregroundStyle(GainsColor.softInk)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(GainsColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
          }
          .buttonStyle(.plain)
        }
        .padding(20)
        .padding(.bottom, 10)
      }
    }
  }

  private func nutritionCell(_ value: String, unit: String, label: String, color: Color) -> some View {
    VStack(spacing: 4) {
      Text(value + unit)
        .font(.system(size: 15, weight: .bold, design: .rounded))
        .foregroundStyle(color)
      Text(label)
        .font(GainsFont.label(10))
        .foregroundStyle(GainsColor.mutedInk)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: Not Found

  private func notFoundView(barcode: String) -> some View {
    ZStack {
      GainsColor.background.ignoresSafeArea()
      VStack(spacing: 24) {
        Spacer()
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 44, weight: .light))
          .foregroundStyle(GainsColor.ember)
        Text("Produkt nicht gefunden")
          .font(GainsFont.title(20))
          .foregroundStyle(GainsColor.ink)
        Text("EAN \(barcode) ist nicht in der\nOpen Food Facts Datenbank.")
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
          .multilineTextAlignment(.center)
        VStack(spacing: 10) {
          Button {
            withAnimation { scanState = .scanning }
          } label: {
            Text("Erneut scannen")
              .font(GainsFont.label(15))
              .foregroundStyle(GainsColor.onLime)
              .frame(maxWidth: .infinity).frame(height: 52)
              .background(GainsColor.lime)
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          }
          .buttonStyle(.plain)

          Button { dismiss() } label: {
            Text("Abbrechen")
              .font(GainsFont.label(15))
              .foregroundStyle(GainsColor.softInk)
              .frame(maxWidth: .infinity).frame(height: 52)
              .background(GainsColor.elevated)
              .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        Spacer()
      }
    }
  }

  // MARK: Error

  private func errorView(message: String) -> some View {
    ZStack {
      GainsColor.background.ignoresSafeArea()
      VStack(spacing: 20) {
        Spacer()
        Image(systemName: "camera.fill")
          .font(.system(size: 44, weight: .light))
          .foregroundStyle(GainsColor.ember)
        Text("Kamera nicht verfügbar")
          .font(GainsFont.title(20))
          .foregroundStyle(GainsColor.ink)
        Text(message)
          .font(GainsFont.body(14))
          .foregroundStyle(GainsColor.softInk)
          .multilineTextAlignment(.center)
          .padding(.horizontal, 24)
        Button { dismiss() } label: {
          Text("Schließen")
            .font(GainsFont.label(15))
            .foregroundStyle(GainsColor.onLime)
            .frame(width: 160, height: 50)
            .background(GainsColor.lime)
            .clipShape(RoundedRectangle(cornerRadius: GainsRadius.small, style: .continuous))
        }
        .buttonStyle(.plain)
        Spacer()
      }
    }
  }

  // MARK: Barcode handling

  private func handleBarcode(_ barcode: String) {
    guard case .scanning = scanState else { return }
    withAnimation { scanState = .loading(barcode) }
    OpenFoodFactsService.lookup(barcode: barcode) { result in
      DispatchQueue.main.async {
        withAnimation {
          switch result {
          case .success(let food):
            scanState = .found(food)
          case .failure(let error):
            if case OpenFoodFactsService.LookupError.notFound = error {
              scanState = .notFound(barcode)
            } else {
              scanState = .error(error.localizedDescription)
            }
          }
        }
      }
    }
  }
}

// MARK: - Gram Input inside Result

private struct BarcodeGramInputCard: View {
  @EnvironmentObject private var store: GainsStore

  let result: ScannedFoodResult
  let mealType: RecipeMealType
  let selectedDate: Date
  let onLog: () -> Void

  @State private var grams: Double = 100
  @State private var gramsText = "100"

  private var nutrition: (kcal: Int, p: Int, c: Int, f: Int) {
    let f = grams / 100.0
    return (
      kcal: Int((Double(result.caloriesPer100g) * f).rounded()),
      p:    Int((result.proteinPer100g * f).rounded()),
      c:    Int((result.carbsPer100g * f).rounded()),
      f:    Int((result.fatPer100g * f).rounded())
    )
  }

  var body: some View {
    VStack(spacing: 16) {
      Text("Menge eingeben")
        .font(GainsFont.label(13))
        .foregroundStyle(GainsColor.softInk)
        .frame(maxWidth: .infinity, alignment: .leading)

      Slider(value: $grams, in: 10...500, step: 5)
        .accentColor(GainsColor.lime)
        .onChange(of: grams) { _, new in gramsText = "\(Int(new))" }

      HStack(spacing: 4) {
        TextField("g", text: $gramsText)
          .keyboardType(.numberPad)
          .font(.system(size: 32, weight: .bold, design: .rounded))
          .foregroundStyle(GainsColor.ink)
          .multilineTextAlignment(.center)
          .frame(width: 80)
          .onChange(of: gramsText) { _, new in
            if let v = Double(new), v >= 1, v <= 2000 { grams = v }
          }
        Text("g · \(nutrition.kcal) kcal")
          .font(GainsFont.label(13))
          .foregroundStyle(GainsColor.mutedInk)
      }
      .frame(maxWidth: .infinity)

      // Quick amounts
      HStack(spacing: 8) {
        ForEach([50, 100, 150, 200, 300], id: \.self) { amt in
          Button {
            grams = Double(amt); gramsText = "\(amt)"
          } label: {
            Text("\(amt)g")
              .font(GainsFont.label(11))
              .foregroundStyle(Int(grams) == amt ? GainsColor.moss : GainsColor.softInk)
              .padding(.horizontal, 10).padding(.vertical, 6)
              .background(Int(grams) == amt ? GainsColor.lime.opacity(0.2) : GainsColor.elevated)
              .clipShape(Capsule())
          }
          .buttonStyle(.plain)
        }
      }

      Button {
        store.logNutritionEntry(
          title: "\(result.name) (\(Int(grams))g)",
          mealType: mealType,
          calories: nutrition.kcal,
          protein: nutrition.p,
          carbs: nutrition.c,
          fat: nutrition.f
        )
        onLog()
      } label: {
        HStack {
          Image(systemName: "checkmark")
          Text("Eintragen — \(nutrition.kcal) kcal")
            .font(GainsFont.label(15))
        }
        .foregroundStyle(GainsColor.onLime)
        .frame(maxWidth: .infinity).frame(height: 52)
        .background(GainsColor.lime)
        .clipShape(RoundedRectangle(cornerRadius: GainsRadius.standard, style: .continuous))
      }
      .buttonStyle(.plain)
    }
    .padding(18)
    .gainsCardStyle(GainsColor.card)
  }
}

// MARK: - Corner Accent Shape

private struct CornerAccent: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let l: CGFloat = 20
    let r: CGFloat = 8
    // top-left
    path.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
    path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
    // top-right
    path.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
    path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
    // bottom-right
    path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - l))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
    path.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
    // bottom-left
    path.move(to: CGPoint(x: rect.minX + l, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
    path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r), control: CGPoint(x: rect.minX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - l))
    return path
  }
}

// MARK: - AVFoundation Camera Preview

struct BarcodeCameraPreview: UIViewRepresentable {
  @Binding var torchOn: Bool
  let onBarcodeDetected: (String) -> Void

  func makeUIView(context: Context) -> BarcodePreviewView {
    let view = BarcodePreviewView()
    view.onBarcodeDetected = onBarcodeDetected
    view.setup()
    return view
  }

  func updateUIView(_ uiView: BarcodePreviewView, context: Context) {
    uiView.setTorch(torchOn)
  }
}

final class BarcodePreviewView: UIView {
  var onBarcodeDetected: ((String) -> Void)?
  private var captureSession: AVCaptureSession?
  private var previewLayer: AVCaptureVideoPreviewLayer?
  private var metadataDelegate: BarcodeMetadataDelegate?
  private var lastDetected: String?

  override func layoutSubviews() {
    super.layoutSubviews()
    previewLayer?.frame = bounds
  }

  func setup() {
    let session = AVCaptureSession()
    guard
      let device = AVCaptureDevice.default(for: .video),
      let input  = try? AVCaptureDeviceInput(device: device),
      session.canAddInput(input)
    else { return }
    session.addInput(input)

    let output = AVCaptureMetadataOutput()
    guard session.canAddOutput(output) else { return }
    session.addOutput(output)

    // Retain the delegate on self so it lives as long as this view
    let delegate = BarcodeMetadataDelegate { [weak self] barcode in
      self?.didDetect(barcode)
    }
    metadataDelegate = delegate
    output.setMetadataObjectsDelegate(delegate, queue: .main)
    output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39, .qr]

    let preview = AVCaptureVideoPreviewLayer(session: session)
    preview.videoGravity = .resizeAspectFill
    preview.frame = bounds
    layer.insertSublayer(preview, at: 0)
    previewLayer = preview

    captureSession = session
    DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
  }

  func setTorch(_ on: Bool) {
    guard
      let device = AVCaptureDevice.default(for: .video),
      device.hasTorch,
      (try? device.lockForConfiguration()) != nil
    else { return }
    device.torchMode = on ? .on : .off
    device.unlockForConfiguration()
  }

  func didDetect(_ barcode: String) {
    guard barcode != lastDetected else { return }
    lastDetected = barcode
    // vibrate
    let generator = UIImpactFeedbackGenerator(style: .medium)
    generator.impactOccurred()
    onBarcodeDetected?(barcode)
  }
}

final class BarcodeMetadataDelegate: NSObject, AVCaptureMetadataOutputObjectsDelegate {
  private let onDetect: (String) -> Void
  init(onDetect: @escaping (String) -> Void) { self.onDetect = onDetect }

  func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
    if let obj = objects.first as? AVMetadataMachineReadableCodeObject,
       let string = obj.stringValue {
      onDetect(string)
    }
  }
}

// MARK: - Open Food Facts Service

struct ScannedFoodResult {
  let barcode: String
  let name: String
  let brand: String?
  let caloriesPer100g: Int
  let proteinPer100g: Double
  let carbsPer100g: Double
  let fatPer100g: Double
}

enum OpenFoodFactsService {
  enum LookupError: Error {
    case notFound
    case networkError(Error)
    case parseError
  }

  static func lookup(barcode: String, completion: @escaping (Result<ScannedFoodResult, LookupError>) -> Void) {
    let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
    guard let url = URL(string: urlString) else {
      completion(.failure(.parseError)); return
    }

    var request = URLRequest(url: url)
    request.setValue("GainsApp/1.0", forHTTPHeaderField: "User-Agent")
    request.timeoutInterval = 10

    URLSession.shared.dataTask(with: request) { data, _, error in
      if let error = error {
        completion(.failure(.networkError(error))); return
      }
      guard let data = data,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let status = json["status"] as? Int, status == 1,
            let product = json["product"] as? [String: Any]
      else {
        completion(.failure(.notFound)); return
      }

      let name = (product["product_name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
      guard !name.isEmpty else { completion(.failure(.notFound)); return }

      let brand = product["brands"] as? String
      let nutriments = product["nutriments"] as? [String: Any] ?? [:]

      func nut(_ key: String) -> Double {
        if let v = nutriments[key] as? Double { return v }
        if let v = nutriments[key] as? Int { return Double(v) }
        return 0
      }

      let result = ScannedFoodResult(
        barcode: barcode,
        name: name,
        brand: brand?.isEmpty == false ? brand : nil,
        caloriesPer100g: Int(nut("energy-kcal_100g").rounded()),
        proteinPer100g:  nut("proteins_100g"),
        carbsPer100g:    nut("carbohydrates_100g"),
        fatPer100g:      nut("fat_100g")
      )
      completion(.success(result))
    }.resume()
  }
}
