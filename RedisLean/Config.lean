namespace Redis

structure Config where
  host : String := "127.0.0.1"
  port : Nat := 6379
  database : Nat := 0
  deriving Repr

namespace Config

def default : Config := {}

def withHost (host : String) : Config := { host }

def withPort (port : Nat) : Config := { port }

def withDatabase (database : Nat) : Config := { database }

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
