# Contributing

Thanks for helping. Issues and pull requests are welcome in Turkish or English.

- **Build and test:** see "Geliştirme" in [README.md](README.md). Before a pull
  request: `cargo test --workspace`, and in `apps/desktop`: `flutter analyze`
  and `flutter test`. CI runs the same.
- **Scope:** the app plays what the user adds. Pull requests that bundle
  channel lists, streams, VPNs, ad or tracking SDKs, or a paid activation
  scheme will not be merged.
- **Secrets:** never put provider passwords, MACs or API keys in SQLite, logs
  or tests; they belong in the OS keyring (`core/crates/kp-core/src/secret.rs`).
- **License:** contributions are accepted under the project's license,
  [MPL-2.0](LICENSE).
