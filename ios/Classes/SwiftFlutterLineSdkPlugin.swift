import Flutter
import UIKit

import LineSDK

public class SwiftFlutterLineSdkPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.linecorp/flutter_line_sdk", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterLineSdkPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    registrar.addApplicationDelegate(instance)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {

    guard let method = LineChannelMethod(rawValue: call.method) else {
      result(FlutterMethodNotImplemented)
      return
    }

    let arguments = call.arguments as? [String: Any]
    method.call(arguments: arguments, result: result)
  }

  public func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool
  {
    return LoginManager.shared.application(application, open: url, options: options)
  }

  public func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([Any]) -> Void) -> Bool
  {
    return LoginManager.shared.application(application, open: userActivity.webpageURL)
  }
}

extension LineSDKError {
  var flutterError: FlutterError {
    return FlutterError(code: String(errorCode), message: errorDescription, details: errorUserInfo)
  }
}

extension FlutterError {
  static let nilArgument = FlutterError(
    code: "argument.nil",
    message: "Expect an argument when invoking channel method, but it is nil.", details: nil
  )

  static func failedArgumentField<T>(_ fieldName: String, type: T.Type) -> FlutterError {
    return .init(
      code: "argument.failedField",
      message: "Expect a `\(fieldName)` field with type <\(type)> in the argument, " +
               "but it is missing or type not matched.",
      details: fieldName)
  }
}

enum LineChannelMethod: String {
  case setup
  case login
  case logout
  case getProfile
  case refreshToken
  case verifyAccessToken
  case getBotFriendshipStatus
  case currentAccessToken

  func call(arguments: [String: Any]?, result: @escaping FlutterResult) {

    let runner: (_ arguments: [String: Any]?, _ result: @escaping FlutterResult) -> Void

    switch self {
    case .setup:                  runner = setup
    case .login:                  runner = login
    case .logout:                 runner = logout
    case .getProfile:             runner = getProfile
    case .refreshToken:           runner = refreshToken
    case .verifyAccessToken:      runner = verifyAccessToken
    case .getBotFriendshipStatus: runner = getBotFriendshipStatus
    case .currentAccessToken:     runner = currentAccessToken
    }

    runner(arguments, result)
  }
}

extension LineChannelMethod {

  func setup(arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard let args = arguments else {
      result(FlutterError.nilArgument)
      return
    }

    guard let channelId = args["channelId"] as? String else {
      result(FlutterError.failedArgumentField("channelId", type: String.self))
      return
    }
    let universalLinkURL = (args["universalLink"] as? String)
      .map { URL(string: $0) } ?? nil
    LoginManager.shared.setup(channelID: channelId, universalLinkURL: universalLinkURL)
    result(nil)
  }

  func login(arguments: [String: Any]?, result: @escaping FlutterResult) {

    guard let args = arguments else {
      result(FlutterError.nilArgument)
      return
    }

    let scopes = (args["scopes"] as? [String])?.map { LoginPermission(rawValue: $0) } ?? [.profile]
    let onlyWebLogin = (args["onlyWebLogin"] as? Bool) ?? false

    var options: LoginManagerOptions = []
    if onlyWebLogin { options = .onlyWebLogin }

    if let botPrompt = args["botPrompt"] as? String {
      switch botPrompt {
      case "aggressive": options.insert(.botPromptAggressive)
      case "normal": options.insert(.botPromptNormal)
      default: break
      }
    }

    LoginManager.shared.login(
      permissions: Set(scopes),
      in: nil,
      options: options) { r in
        switch r {
        case .success(let value): result(value.json)
        case .failure(let error): result(error.flutterError)
        }
    }
  }

  func logout(arguments: [String: Any]?, result: @escaping FlutterResult) {
    LoginManager.shared.logout { r in
      switch r {
      case .success: result(nil)
      case .failure(let error): result(error.flutterError)
      }
    }
  }

  func getProfile(arguments: [String: Any]?, result: @escaping FlutterResult) {
    API.getProfile { r in
      switch r {
      case .success(let value): result(value.json)
      case .failure(let error): result(error.flutterError)
      }
    }
  }

  func refreshToken(arguments: [String: Any]?, result: @escaping FlutterResult) {
    API.refreshAccessToken { r in
      switch r {
      case .success(let value): result(value.json)
      case .failure(let error): result(error.flutterError)
      }
    }
  }

  func verifyAccessToken(arguments: [String: Any]?, result: @escaping FlutterResult) {
    API.verifyAccessToken { r in
      switch r {
      case .success(let value): result(value.json)
      case .failure(let error): result(error.flutterError)
      }
    }
  }

  func getBotFriendshipStatus(arguments: [String: Any]?, result: @escaping FlutterResult) {
    API.getBotFriendshipStatus { r in
      switch r {
      case .success(let value): result(value.json)
      case .failure(let error): result(error.flutterError)
      }
    }
  }

  func currentAccessToken(arguments: [String: Any]?, result: @escaping FlutterResult) {
    result(AccessTokenStore.shared.current?.json)
  }
}

private let encoder = JSONEncoder()
extension Encodable {
  var json: String {
    let data = try! encoder.encode(self)
    return String(data: data, encoding: .utf8)!
  }
}
