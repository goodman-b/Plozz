@testable import AetherEngine
import CoreModels
import FeaturePlayback
import XCTest
@testable import EnginePlozzigen

// Fork semantics (atmos-heights-back): on tvOS 26+ an audible, non-session-sharing on-demand
// load renders object audio as APAC 7.1.4; every other platform/path keeps upstream `.off`.
private func forkExpectedObjectAudioRendering(audible: Bool = true, shares: Bool = false) -> ObjectAudioRendering {
    #if os(tvOS)
    if #available(tvOS 26.0, *), audible, !shares { return .apac(.l714) }
    #endif
    return .off
}

@MainActor
final class SpatialAudioLayoutPreferenceTests: XCTestCase {
    func testOptionalEngineComponentsAreExcluded() {
        // Fork: the object-audio traits are compiled into this build (Package.swift `traits:`).
        XCTAssertTrue(AetherEngine.OptionalComponent.trueHDObjectAudio.isBuiltIn)
        XCTAssertTrue(AetherEngine.OptionalComponent.dtsxObjectAudio.isBuiltIn)
        XCTAssertFalse(AetherEngine.OptionalComponent.dualLayerDolbyVision.isBuiltIn)
        XCTAssertFalse(AetherEngine.OptionalComponent.dolbyVisionStillReshaping.isBuiltIn)
    }

    func testStillExtractionRequiresAnOrdinaryBaseLayer() {
        XCTAssertFalse(FrameDecodeContext.yieldsStill(dolbyVisionNoBaseLayer: true))
        XCTAssertTrue(FrameDecodeContext.yieldsStill(dolbyVisionNoBaseLayer: false))
    }

    func testLegacyLayoutsCannotEnableHeightConversionAcrossProvidersAndDownloads() throws {
        let defaults = UserDefaults.standard
        let previousLayout = defaults.object(forKey: SpatialAudioLayoutStore.storageKey)
        defer { defaults.set(previousLayout, forKey: SpatialAudioLayoutStore.storageKey) }
        let store = SpatialAudioLayoutStore(defaults: defaults)
        let engine = try PlozzigenVideoEngine()
        defer { engine.stop() }
        let earlier = engine.onDemandLoadOptions(for: request)
        for layout in SpatialAudioLayout.allCases {
            store.save(layout)
            for provider: ProviderKind in [.jellyfin, .emby, .plex, .silo, .mediaShare] {
                for channels: Int? in [nil, 2, 6, 8] {
                    var request = request
                    request.sourceProvider = provider
                    request.sourceMetadata = .init(audio: .init(codec: "dts", channels: channels))
                    XCTAssertEqual(engine.onDemandLoadOptions(for: request).objectAudioRendering, forkExpectedObjectAudioRendering())
                    request.streamURL = URL(fileURLWithPath: "/fixture/download.mkv")
                    XCTAssertEqual(engine.onDemandLoadOptions(for: request).objectAudioRendering, forkExpectedObjectAudioRendering())
                }
            }
        }
        XCTAssertEqual(earlier.objectAudioRendering, forkExpectedObjectAudioRendering())
    }

    func testEveryOutputPolicyKeepsHeightConversionOffAndPreservesOrdinaryBridge() {
        for lossless in [false, true] {
            for policy in [
                LiveChannelOutputPolicy(isAudible: true),
                .init(isAudible: false),
                .init(isAudible: true, sharesAudioSession: true),
                .init(isAudible: false, sharesAudioSession: true)
            ] {
                let options = PlozzigenVideoEngine.onDemandLoadOptions(
                    losslessAudioEnabled: lossless, outputPolicy: policy
                )
                XCTAssertEqual(options.objectAudioRendering, forkExpectedObjectAudioRendering(
                    audible: policy.isAudible, shares: policy.sharesAudioSession
                ))
                XCTAssertEqual(options.audioBridgeMode, lossless ? .lossless : .surroundCompat)
            }
        }
    }

    func testHeightConversionStaysOffForOnDemandAndLiveStreams() {
        let onDemand = PlozzigenVideoEngine.onDemandLoadOptions()
        XCTAssertEqual(onDemand.objectAudioRendering, forkExpectedObjectAudioRendering())
        XCTAssertFalse(onDemand.preferDualLayerDolbyVision)
        for suffix in ["ts", "m3u8"] {
            let options = PlozzigenVideoEngine.liveLoadOptions(
                httpHeaders: [:], url: URL(string: "https://example.invalid/live.\(suffix)")
            )
            XCTAssertEqual(options.objectAudioRendering, .off)
        }
    }

    func testActualRenderedPipelineLabelsAreRecognized() {
        for bed in SpatialSpeakerLayout.allCases {
            for codec in ["truehd", "dts"] {
                let track = TrackInfo(id: 0, name: "English", codec: codec, language: "en", isDefault: true)
                for (route, expected): (SoftwareAtmosRoute, LocalizedStringResource) in [
                    (.pcmBed(bed), "Rendered to PCM"), (.apac(bed), "Lossy encoding")
                ] {
                    let pipeline = AetherEngine.softwareAudioDecoderLabel(
                        audioTracks: [track], activeIndex: 0, route: route
                    )
                    XCTAssertEqual(PlaybackDiagnostics(
                        audioPipelineDescription: pipeline, mode: .plozzigen
                    ).audioEncodingDescription, expected)
                }
            }
        }
    }

    private var request: PlaybackRequest {
        PlaybackRequest(item: MediaItem(id: "movie", title: "Fixture", kind: .movie),
                        streamURL: URL(string: "https://example.invalid/movie.mkv")!)
    }
}
