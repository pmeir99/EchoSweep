# EchoSweep

Native SwiftUI duplicate music finder for Apple Silicon. Select a folder, external drive, or SD card. Uses Chromaprint acoustic fingerprints to group conservatively matching recordings despite different filenames and encodings. Inspect sizes, reveal files in Finder, and manually select files to move to Trash.

## Build

Push this project to a GitHub repository with default branch `main`. Open Actions → Build Apple Silicon → Run workflow. Download the `EchoSweep-arm64` artifact from the successful workflow run.

The workflow bundles `fpcalc` and its dynamic dependencies. The app uses macOS native materials and adopts the host system's visual appearance, including Liquid Glass where supported. The app targets arm64 and macOS 15+; macOS 27-specific rendering requires testing on macOS 27.

## Caveats

The initial version groups identical Chromaprint fingerprints of the first 120 seconds. It does not yet support fuzzy or partial-track matches, robust quality scoring, cancellation, or reporting unreadable tracks. Identical fingerprints are strong candidates, not cryptographic proof of identical recordings. The app is ad-hoc signed, not notarized. Keep backups before removing files.
