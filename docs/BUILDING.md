# Building Vexel for iOS

Vexel targets iPhone and iPad, with iOS 16.0 as the deployment baseline. The application is generated from
`project.yml` with XcodeGen. The editing and project-format code lives in the `Packages/VexelCore` Swift package.

## Continuous integration

`.github/workflows/ios-ci.yml` runs on pushes to `feat/modular-engine-architecture`, pull requests targeting
`feat/port-reference-ui`, and manual dispatch. It verifies the effect registry and engine-port status, builds and
tests every Swift package under `Packages/`, generates the Xcode project, and builds the iOS Simulator target.

## Build an unsigned IPA from GitHub without a Mac

The `.github/workflows/ios-ipa.yml` workflow is manual-only (`workflow_dispatch`). It runs on a standard
GitHub-hosted `macos-15` runner and builds the selected branch.

1. Open **Actions → Build Vexel IPA**.
2. Tap **Run workflow**.
3. Select the branch to build, normally `feat/modular-engine-architecture`.
4. Tap **Run workflow** and wait for the job to complete.
5. Open the successful run and download the `Vexel-unsigned-IPA` artifact.

The artifact contains `Vexel-unsigned.ipa` and its SHA-256 checksum. The IPA is archived for generic iOS
devices with code signing disabled. The workflow validates the app bundle's Info.plist and executable, checks
the IPA ZIP structure, and uploads the artifact. It does not sign the app.

## Important: unsigned versus installable

The CI artifact is an **unsigned IPA**. A successful archive proves that Xcode compiled and packaged the app;
it does not prove physical-device installation or runtime correctness. iOS requires a valid signature and
provisioning profile to install the app normally. This workflow does not use, request, or store Apple credentials.

A signed device build requires an Apple Developer signing identity, a provisioning profile for the app's bundle
identifier, and securely stored signing credentials. Do not commit certificates, private keys, provisioning
profiles, or passwords to the repository.

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
separately configured remote Mac service; CI success is not a substitute for testing on actual iPhone and iPad
hardware.
