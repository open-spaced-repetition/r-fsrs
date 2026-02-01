# rfsrs (development version)
 
# rfsrs 0.1.0

* Initial release
* R bindings for fsrs-rs Rust library via rextendr
* Core functions:
  - `fsrs_default_parameters()`: Get FSRS-6 default parameters (21 values)
  - `fsrs_initial_state()`: Create initial memory state for new cards
  - `fsrs_next_state()`: Calculate memory state after a review
  - `fsrs_next_interval()`: Get optimal interval for next review
  - `fsrs_retrievability()`: Calculate probability of recall
* Supports all four FSRS ratings (Again, Hard, Good, Easy)
* Available on r-universe: https://chrislongros.r-universe.dev
* Builds successfully on Linux and macOS (Windows builds pending)
