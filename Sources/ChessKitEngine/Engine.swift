//
//  Engine.swift
//  ChessKitEngine
//

//import ChessKitEngineCore
import AsyncAlgorithms
import Foundation

public final class Engine: Sendable {
    
    //MARK: - Public properties
    
    /// The type of the engine.
    public let type: EngineType

    /// Whether the engine is currently running.
    ///
    /// - To start the engine, call ``start(coreCount:multipv:)``.
    /// - To stop the engine, call ``stop()``.
    ///
    /// Engine must be running for ``send(command:)`` to work.
    public var isRunning: Bool {
        get async { await engineConfigurationActor.isRunning }
    }
    
    /// Whether logging should be enabled.
    ///
    /// If set to `true`, engine commands and responses
    /// will be logged to the console. The default value is
    /// `false`.
    ///
    ///  Can be set via ``setLoggingEnabled(_:)`` function.
    public var loggingEnabled: Bool {
        get async { await engineConfigurationActor.loggingEnabled }
    }
    
    /// an AsyncStream that is called when engine responses are received.
    ///
    /// The underlying value ``EngineResponse`` contains the engine
    /// response corresponding to the UCI protocol.
    public var responseStream : AsyncStream<EngineResponse>? {
        get async { await engineConfigurationActor.asyncStream }
    }
    
    //MARK: - Private properties
    
    ///Actor used to hold mutating data in a thread safe environment.
    private let engineConfigurationActor: EngineConfiguration
    
    /// Messenger used to communicate with engine.
    private let messenger: EngineMessenger
        
    //MARK: - Life cycle functions
    
    /// Initializes an engine with the provided ``EngineType`` and optional logging enabled flag.
    ///
    /// - parameter type: The type of engine to use.
    /// - parameter loggingEnabled: If set to `true`, engine commands and responses
    ///   will be logged to the console. The default value is `false`.
    public init(type: EngineType, loggingEnabled: Bool = false) {
        self.type = type
        self.messenger = EngineMessenger(engineType: type)
        self.engineConfigurationActor = EngineConfiguration(loggingEnabled: loggingEnabled)
    }


    // This no longer work in an async environment as stop function outlives the deinit function.
    // Support for async deinit should be added in a future version of Swift (6.1)
    // https://github.com/swiftlang/swift-evolution/blob/main/proposals/0371-isolated-synchronous-deinit.md
    //    deinit {
    //        stop()
    //    }

    //MARK: - Public functions
    
    /// Starts the engine.
    ///
    /// You must call this function and wait for ``EngineResponse/readyok``
    /// before you can ask the engine to perform any work.
    ///
    /// - parameter coreCount: The number of processor cores to use for engine
    /// calculation. The default value is `nil` which uses the number of
    /// cores available on the device.
    /// - parameter multipv: The number of lines the engine should return,
    /// sent via the `"MultiPV"` UCI option.
    ///
    public func start(
        coreCount: Int? = nil,
        multipv: Int = 1
    ) async throws {
        await engineConfigurationActor.setAsyncStream()
        await engineConfigurationActor.setMultiPv(multiPv: multipv)
        await engineConfigurationActor.setCoreCount(coreCount: coreCount)
//        setMessengerResponseHandler(coreCount: coreCount, multipv: multipv)

        //Since read in background and notify, requires an active run loop
        //this is called on main thread to ensure there is an active run loop
        //to receive the notification on. 
//        await MainActor.run {
        try await messenger.start(delegate: self)
//        }

        // start engine setup loop
        try await send(command: .uci)
    }

    /// Stops the engine.
    ///
    /// Call this to stop all engine calculation and clean up.
    /// After calling ``stop()``, ``start(coreCount:multipv:)`` must be called before
    /// sending any more commands with ``send(command:)``.
    ///
    /// - note: as temporary fix this function must be called before deiniting the engine.
    public func stop() async throws {
        guard await isRunning == true else { return }
            
        try await send(command: .stop)
        try await send(command: .quit)
        try await messenger.stop()
            
            
        await engineConfigurationActor.clearAsyncStream()
        await engineConfigurationActor.setIsRunning(isRunning: false)
        await engineConfigurationActor.setInitialSetupComplete(initialSetupComplete: false)
    }

    /// Sends a command to the engine.
    ///
    /// - parameter command: The command to send.
    ///
    /// Commands must be of type ``EngineCommand`` to ensure
    /// validity.
    ///
    /// Any responses will be returned via ``responseStream``.
    public func send(command: EngineCommand) async throws {
        guard await isRunning || [.uci, .isready].contains(command) else {
            await log("Engine is not running, call start() first.")
            throw EngineError.NotRunning
        }

        await log(command.rawValue)
        
        await messenger.sendCommand(command: command)
    }
    
    /// Enable printing logs to console.
    ///
    /// - parameter loggingEnabled: If set to `true`, engine commands and responses
    ///   will be logged to the console. The default value is `false`.
    ///
    public func setLoggingEnabled(_ loggingEnabled: Bool) {
        Task {
            await engineConfigurationActor
                .setLoggingEnabled(loggingEnabled: loggingEnabled)
        }
    }

    // MARK: - Private functions

    /// Logs `message` if `loggingEnabled` is `true`.
    private func log(_ message: String) async {
        if await loggingEnabled {
            print(message)
        }
    }
    
    /// convinience function to set up `messenger.responseHandler`
    private func handleServerResponse(response: String) {
        Task{ [weak self] in
            guard let self,
                  let parsed = EngineResponse(rawValue: response) else {
                if !response.isEmpty {
                    await self?.log(response)
                }
                return
            }
                
            await self.log(parsed.rawValue)
                
            if await !self.isRunning {
                if parsed == .readyok {
                    try? await self.performInitialSetup(
                        coreCount: engineConfigurationActor.coreCount,
                        multipv: engineConfigurationActor.multiPv
                    )
                } else if let next = EngineCommand.nextSetupLoopCommand(
                    given: parsed
                ) {
                    try? await self.send(command: next)
                }
            }
            await self.engineConfigurationActor.streamContinuation?.yield(parsed)
        }
    }
    
    /// Sets initial engine options.
    private func performInitialSetup(coreCount: Int, multipv: Int) async throws {
        guard await !engineConfigurationActor.initialSetupComplete else { return }
        
        await engineConfigurationActor.setIsRunning(isRunning: true)

        // configure engine-specific options
        for command in type.setupCommands {
            try await send(command: command)
        }

        // configure common engine options
        try await send(command: .setoption(
            id: "Threads",
            value: "\(max(coreCount - 1, 1))"
        ))
        try await send(command: .setoption(id: "MultiPV", value: "\(multipv)"))

        await engineConfigurationActor
            .setInitialSetupComplete(initialSetupComplete:  true)
    }
}

extension Engine: EngineMessengerDelegate {
    func engineMessengerDidReceiveResponse(_ response: String) {
        handleServerResponse(response: response)
    }
}

//MARK: EngineConfiguration actor

//An actor to hold the configuration for the engine class.
//Since engine now conforms to sendable protocol, we need to
//move the mutable data into async safe environment.
//
fileprivate actor EngineConfiguration: Sendable {
    /// Whether the engine is currently running.
    private(set) var isRunning = false
    
    /// Whether logging should be enabled.
    private(set) var loggingEnabled = false
    
    /// Whether the initial engine setup was completed
    private(set) var initialSetupComplete = false
    
    /// An async stream to notify the end user about engine responses
    private(set) var asyncStream: AsyncStream<EngineResponse>?
    
    /// A reference to AsyncStream's continuation for later access by `EngineMessenger.responseHandler`
    private(set) var streamContinuation: AsyncStream<EngineResponse>.Continuation?
    
    private(set) var multiPv: Int = 1
    private(set) var coreCount: Int = ProcessInfo.processInfo.processorCount
    
    init(loggingEnabled: Bool = false) {
        self.loggingEnabled = loggingEnabled
        
        Task{ await setAsyncStream() }
    }
    
    func setLoggingEnabled(loggingEnabled: Bool) async {
        self.loggingEnabled = loggingEnabled
    }
    
    func setInitialSetupComplete(initialSetupComplete: Bool) async {
        self.initialSetupComplete = initialSetupComplete
    }
    
    func setIsRunning(isRunning: Bool) async {
        self.isRunning = isRunning
    }
    
    func setMultiPv(multiPv: Int) async {
        self.multiPv = multiPv
    }
    
    func setCoreCount(coreCount: Int?) async {
        if let coreCount {
            self.coreCount = coreCount
        }
    }
    
    func setAsyncStream() async {
        guard self.asyncStream == nil else { return }
        
        self.asyncStream = AsyncStream { (continuation: AsyncStream<EngineResponse>.Continuation) -> Void in
            Task{ await setStreamContinuation(continuation) }
        }
    }
    
    func clearAsyncStream() async {
        self.asyncStream = nil
        self.streamContinuation = nil
    }
    
    private func setStreamContinuation(_ continuation: AsyncStream<EngineResponse>.Continuation?) async {
        self.streamContinuation = continuation
    }
}
