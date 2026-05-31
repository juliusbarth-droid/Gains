import Foundation

// MARK: - AppleFoundationModelsClient (Stub)
//
// 2026-05-16 (Release-Audit Cleanup):
//
// Vorher enthielt diese Datei einen vollständigen Wrapper um Apple's
// `FoundationModels`-Framework (iOS 26 + Apple Intelligence) für
// on-device-Foto-Erkennung. Der `Image`-Input-Typ aus FoundationModels war
// in einer früheren Beta vorhanden, ist aber im aktuell installierten SDK
// weg/umbenannt — `runAnalysis` lieferte deshalb seit Wochen nur
// `unavailable`-Errors. Aufrufstellen in `FoodPhotoRecognitionView` waren
// ebenfalls toter Code.
//
// Für v1.0 läuft Foto-Erkennung ausschließlich über `GeminiFoodVisionClient`
// (Cloud) mit Apple-Vision-Saliency als Fallback. Die App-Privacy-Section
// muss den Gemini-Datentransfer entsprechend deklarieren.
//
// Wiederbelebung in Phase 2 (nach iOS-26-Final-Release):
//   1. `enum AppleFoundationModelsClient` mit `isAvailable` + `analyze` neu
//      anlegen (Vorlage in Git-History vor diesem Commit).
//   2. In `FoodPhotoRecognitionView.aiInfoChipIcon/Color/Text` und in
//      `FoodPhotoRecognitionAnalyzer.analyze` die On-Device-Stufe als PRIO 1
//      wieder vor `tryGeminiOrLocal` schalten.
//
// Datei bleibt im Xcode-Projekt, damit kein „Missing File"-Reference-Fehler
// im .xcodeproj entsteht.
