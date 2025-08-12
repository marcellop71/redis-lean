namespace Redis

/-- SSL verification mode -/
inductive SSLVerifyMode where
  | none  -- Do not verify server certificate (insecure)
  | peer  -- Verify server certificate (default)
  deriving Repr, BEq

/-- SSL/TLS configuration for Redis connections -/
structure SSLConfig where
  /-- CA certificate file for server verification -/
  cacertPath : Option String := none
  /-- Directory containing CA certificates -/
  caPath : Option String := none
  /-- Client certificate file (for mTLS) -/
  certPath : Option String := none
  /-- Client private key file (for mTLS) -/
  keyPath : Option String := none
  /-- Server Name Indication (SNI) hostname -/
  serverName : Option String := none
  /-- Certificate verification mode -/
  verifyMode : SSLVerifyMode := .peer
  deriving Repr

namespace SSLConfig

def default : SSLConfig := {}

/-- Create SSL config for one-way SSL (server verification only) -/
def oneWay (cacertPath : String) (serverName : Option String := none) : SSLConfig :=
  { cacertPath := some cacertPath, serverName, verifyMode := .peer }

/-- Create SSL config for mTLS (mutual authentication) -/
def mTLS (cacertPath : String) (certPath : String) (keyPath : String)
    (serverName : Option String := none) : SSLConfig :=
  { cacertPath := some cacertPath, certPath := some certPath,
    keyPath := some keyPath, serverName, verifyMode := .peer }

/-- Create SSL config with no verification (insecure, for testing) -/
def insecure : SSLConfig := { verifyMode := .none }

end SSLConfig

structure Config where
  host : String := "127.0.0.1"
  port : Nat := 6379
  database : Nat := 0
  ssl : Option SSLConfig := none
  deriving Repr

namespace Config

def default : Config := {}

def withHost (host : String) : Config := { host }

def withPort (port : Nat) : Config := { port }

def withDatabase (database : Nat) : Config := { database }

/-- Enable SSL with the given configuration -/
def withSSL (config : Config) (sslConfig : SSLConfig) : Config :=
  { config with ssl := some sslConfig }

/-- Enable SSL with just a CA certificate path -/
def withSSLCert (config : Config) (cacertPath : String) : Config :=
  { config with ssl := some (SSLConfig.oneWay cacertPath) }

/-- Check if SSL is enabled -/
def isSSLEnabled (config : Config) : Bool :=
  config.ssl.isSome

def make (host : String) (port : Nat) (database : Nat) : Config :=
  { host, port, database }

-- create a Redis configuration from a host:port or host:port/database string
def fromString (hostPortDb : String) : Option Config := do
  let dbParts := hostPortDb.split (· == '/') |>.toList
  let (hostPort, database) := match dbParts with
    | [hp] => (hp.toString, 0)
    | [hp, dbStr] =>
      match dbStr.toString.toNat? with
      | some db => (hp.toString, db)
      | none => (hp.toString, 0)
    | _ => (hostPortDb, 0)

  let parts := hostPort.split (· == ':') |>.toList
  match parts with
  | [host] => some { host := host.toString, database }
  | [host, portStr] =>
    match portStr.toString.toNat? with
    | some port => some { host := host.toString, port, database }
    | none => none
  | _ => none

-- convert Config to a connection string format
def toString (config : Config) : String :=
  if config.database == 0 then
    s!"{config.host}:{config.port}"
  else
    s!"{config.host}:{config.port}/{config.database}"

-- parse a Redis URL (redis://host:port/database)
def fromUrl (url : String) : Option Config := do
  let cleanUrl := if url.startsWith "redis://" then (url.drop 8).toString else url
  fromString cleanUrl

end Config

end Redis
