# Building Vexel for iOS

Vexel targets iPhone and iPad, with iOS 16.0 as the deployment baseline. The application is generated from
`project.yml` with XcodeGen. The editing and project-format code lives in the `Packages/VexelCore` Swift package.

## Build from GitHub without a Mac

The workflow at `.github/workflows/ios-ipa.yml` is manual-only (`workflow_dispatch`) and runs on a GitHub-hosted macOS runner. Pushes and pull requests do not start it automatically. Open **Actions → Vexel Validation → Run workflow** to start validation. The optional `build_ipa` input defaults to `false`; enable it only when you also want an unsigned IPA build.

The workflow:
1. Builds and tests every Swift package under `Packages/`.
2. Installs XcodeGen and generates `Vexel.xcodeproj`.
3. Archives the app for generic physical iOS devices with code signing disabled.
4. Packages the archived app as `Vexel-unsigned.ipa`.
5. Uploads the IPA as the `Vexel-unsigned-IPA` workflow artifact.

To retrieve it on iPhone, open the successful workflow run in GitHub, open Artifacts, and download
`Vexel-unsigned-IPA`. The downloaded artifact is a ZIP containing the IPA.

## Important: unsigned versus installable

The CI artifact is an **unsigned IPA**. It proves that the iOS device build compiled and packages the app, but iOS
will not install it as a normal app without a valid signature and provisioning profile. This workflow does not
use, request, or store Apple credentials.

A signed device build requires an Apple Developer signing identity, a provisioning profile for the app's bundle
identifier, and securely stored CI credentials. A free Apple ID can be used for limited personal development
signing, but the signing and refresh process has separate constraints. Do not commit certificates, private keys,
provisioning profiles, or passwords to the repository.

## Local build

On a Mac with Xcode and XcodeGen installed:

```sh
swift test --package-path Packages/VexelCore
xcodegen generate
xcodebuild archive -project Vexel.xcodeproj -scheme Vexel \
  -configuration Release -destination 'generic/platform=iOS' \
  -archivePath build/Vexel.xcarchive
```

For an unsigned archive, add `CODE_SIGNING_ALLOWED=NO`.

## iPhone-only development

The source can be edited from iPhone using GitHub's web editor or a Git client. GitHub Actions performs the
Xcode build remotely. The iOS Simulator and physical-device debugging still require access to a Mac or a
separately configured remote Mac service; CI success is not a substitute for testing on the actual iPhone and iPad.
