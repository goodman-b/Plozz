# Fork notice — personal Apple TV build

**This branch is not upstream Plozz and is not endorsed by it.** Parent:
[`brandomoore/Plozz`](https://github.com/brandomoore/Plozz), branch `atmos-heights-back`.
Companion engine fork: [`goodman-b/AetherEngine`](https://github.com/goodman-b/AetherEngine),
branch `atmos-activator-all-beds` (upstream of that: `superuser404notfound/AetherEngine` by
Vincent Herbst).

## What this branch changes

One functional change: on **tvOS only**, object-audio output is re-enabled as
**APAC 7.1.4**, so Dolby TrueHD + Atmos reaches a home soundbar with its **height channels**
instead of being folded into the bed. It is applied where upstream sets
`options.objectAudioRendering = .off`, guarded by availability, audibility and audio-session
sharing:

```swift
#if os(tvOS)
if #available(tvOS 26.0, *), outputPolicy.isAudible, !outputPolicy.sharesAudioSession {
    options.objectAudioRendering = .apac(.l714)
}
#endif
```

Supporting changes: the engine dependency moves from a pinned `url:`+`revision:` to a local
`path:` (path dependencies cannot carry SwiftPM `traits:`, so the object-audio traits are enabled
in the engine fork's manifest instead); `project.yml` gains `SDKROOT`/`SUPPORTED_PLATFORMS` for
`Plozz` and `PlozzTopShelf`; the CI pipeline guard is extended to accept the path dependency
rather than relaxed; attribution and playback-engine docs describe the deviation truthfully.

**APAC rather than `.render`** is deliberate: `.render` selects the PCM bed, and that bed carries
an open mis-mapping report against this engine revision (`AetherEngine#964`; also `Plozz#265`),
whose author reports APAC placing every channel correctly. **7.1.4** because the target sink is a
7.1.4-capable soundbar; the engine's 9.1.6 mode folds six heights into four.

## What is deliberately not published

**No built artifacts.** No `.ipa`, no `.app`, no provisioning profile, no certificate — a bundle
would carry signing and profile data and would amount to distributing a decoder build. Source
only. `.gitignore` refuses those paths.

## Licensing

Upstream licences are preserved unmodified: **GPL-3.0** (Plozz) and **LGPL-3.0 with the author's
Apple Store / DRM exception** (AetherEngine). Height audio engages Dolby and DTS patent territory;
this branch exists for one household device on Apple's own free-personal-team sideloading path and
is not offered as a product, a distribution, or advice that the feature is licensed for shipping.

## Building it

Requires the **tvOS 27 SDK** (the engine uses `#available(tvOS 27.1, *)`), so Xcode 27 on
Apple silicon — and Xcode 27 has no Intel slice.

1. `tools/generate-project.sh` — **never** bare `xcodegen`: it leaves `${PLOZZ_*}` unexpanded, and
   the resulting bundle ships an empty URL scheme and Bonjour services list, which breaks `plozz://`
   and device pairing.
2. Restore `PlozzTV.xcscheme` afterwards; regeneration removes it.
3. Set both environment variables — `PLOZZ_TV_ID` otherwise defaults to the **maintainer's** Apple
   TV UDID:
   `PLOZZ_DEVELOPMENT_TEAM=<your team> PLOZZ_TV_ID=<your tvOS device UDID>`
4. Signing needs a GUI login session; over SSH the keychain refuses with
   `error: User interaction is not allowed.`

## Also noted upstream

`NOTICE.md` pins an engine revision that disagrees with `Package.resolved`; reproduced on pristine
`main` and reported as [Plozz#411](https://github.com/brandomoore/Plozz/issues/411). Not folded
into this branch — it is upstream's to settle.
