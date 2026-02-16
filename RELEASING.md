# Release Process

This project uses **Semantic Versioning** (Major.Minor.Patch) and GitHub's automated CI/CD to handle releases.

## 1. Versioning
The version of the app is defined in two places:
- **`Sources/BrightnessControl/Info.plist`**: `CFBundleShortVersionString` (The version shown to users).
- **Git Tags**: Used by GitHub Actions to trigger the release process.

## 2. Automated Release Workflow
When you are ready to release a new version:

1.  **Update Info.plist**: Update the version string to your target version (e.g., `1.0.1`).
2.  **Commit changes**: `git commit -am "chore: bump version to 1.0.1"`
3.  **Push a Tag**:
    ```bash
    git tag v1.0.1
    git push origin --tags
    ```

## 3. What happens next?
The **Build and Release** GitHub Action will automatically:
1.  Verify the code builds on `macos-latest`.
2.  Package the app into a proper `.app` bundle.
3.  Zip the bundle into `BrightnessControl.zip`.
4.  Create a new **GitHub Release** with the zip file attached as a build artifact.

## 4. Manual Verification
Always download the zip from the release page and test it on your machine before announcing it to others.
