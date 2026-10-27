import Foundation

/// Shared loading/empty/failure state for the handful of screens that each
/// fetch one page from iosapps.litten.ca and render it.
enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}
