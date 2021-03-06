use "http_server"
use "net"
use "promises"
use "valbytes"
use "../../kuafu"

actor Main
  new create(env: Env) =>
    let tcplauth: TCPListenAuth = TCPListenAuth(env.root)

    let server =
      Kuafu(tcplauth, env.out)
        .> get("/", MyHandler~apply())
        .> get("/:name", MyHandler~apply(), [(DefaultMiddleware~before(), DefaultMiddleware~after())]) // Add default middlware to make compiler happy
        .serve(ServerConfig(where port' = "8080"))

primitive MyHandler
  fun apply(
    method: Method val,
    uri: URL val,
    headers: Array[Header val] val,
    captures: Array[(String val, String val)] val,
    body: ByteArrays val): Promise[ResponseData] =>
    let name: String val = QueryHelper.get_or_else(captures, "name")
    let body' =
      "".join(
        [ "Hello"; if name != "" then " " + name else "" end; "!"
        ].values()).array()
    let p: Promise[ResponseData] = Promise[ResponseData]
    p((StatusOK, [as (String val, String val):], ByteArrays(body')))
    p
