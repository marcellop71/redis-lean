namespace Redis

inductive ConnectError where
  | IOError (msg : String)
  | EOFError (msg : String)
  | protocolError (msg : String)
  | otherError (msg : String)
  deriving Repr, Inhabited

instance : ToString ConnectError where
  toString
  | .IOError msg => s!"connect IO error: {msg}"
  | .EOFError msg => s!"connect EOF error: {msg}"
  | .protocolError msg => s!"connect protocol error: {msg}"
  | .otherError msg => s!"connect other error: {msg}"

/-- SSL/TLS specific errors -/
inductive SSLError where
  | initFailed (msg : String)
  | contextCreationFailed (msg : String)
  | handshakeFailed (msg : String)
  deriving Repr, Inhabited

instance : ToString SSLError where
  toString
  | .initFailed msg => s!"SSL init failed: {msg}"
  | .contextCreationFailed msg => s!"SSL context creation failed: {msg}"
  | .handshakeFailed msg => s!"SSL handshake failed: {msg}"

inductive Error where
  | connectError (kind: ConnectError)
  | sslError (kind: SSLError)
  | nullReplyError (msg: String)
  | replyError (msg: String)
  | unexpectedReplyTypeError (msg: String)
  | keyNotFoundError (key: String)
  | noExpiryDefinedError (key: String)
  | otherError (msg: String)
  deriving Repr, Inhabited

instance : ToString Error where
  toString
  | .connectError kind => s!"connect error: {kind}"
  | .sslError kind => s!"SSL error: {kind}"
  | .nullReplyError msg => s!"null reply error: {msg}"
  | .replyError msg => s!"reply error: {msg}"
  | .unexpectedReplyTypeError msg => s!"unexpected reply type error: {msg}"
  | .keyNotFoundError key => s!"key not found error: {key}"
  | .noExpiryDefinedError key => s!"no expiry defined error: {key}"
  | .otherError msg => s!"other error: {msg}"

end Redis
