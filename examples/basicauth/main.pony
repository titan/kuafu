use "collections"
use "encode/base64"
use "http_server"
use "net"
use "promises"
use "valbytes"
use "../../kuafu"

actor Main
  new create(env: Env) =>
    let tcplauth: TCPListenAuth = TCPListenAuth(env.root)

    let accounts: Map[String val, String val] trn = recover trn Map[String val, String val](1) end
    accounts("my_username") = "my_super_secret_password"
    let accounts': Map[String val, String val] val = consume accounts

    let server =
      Kuafu(tcplauth, env.out)
        .> get("/", H, [ BasicAuth("My Realm", consume accounts') ])
        .serve(ServerConfig(where port' = "8080"))

primitive H is RequestHandler
  fun apply(
    method: Method val,
    uri: URL val,
    headers: Array[Header val] val,
    captures: Array[(String val, String val)] val,
    body: ByteArrays val): Promise[ResponseData] =>
    let p: Promise[ResponseData] = Promise[ResponseData]
    p(ResponseDataBuilder(StatusOK, [as (String val, String val):], ByteArrays("Hello".array())))
    p

class BasicAuth is Middleware
  """
  Performs Basic Authentication as described in RFC 2617
  """
  let _realm: String val
  let _accounts: Map[String val, String val] val

  new val create(
    realm: String val,
    accounts: Map[String val, String val] val)
  =>
    _realm = realm
    _accounts = consume accounts

  fun val before(
    method: Method val,
    uri: URL val,
    headers: Array[Header val] val,
    captures: Array[(String val, String val)] val,
    body: ByteArrays val)
  : Promise[(ResponseData | RequestData)] =>
    let p: Promise[(ResponseData | RequestData)] = Promise[(ResponseData | RequestData)]
    let auth = HeaderHelper.get_or_else(headers, "Authorization")
    let basic_scheme = "Basic "
    if auth.at(basic_scheme) then
      try
        let decoded = Base64.decode[String iso](auth.substring(basic_scheme.size().isize()))?
        let creds = decoded.split(":")
        if creds.size() == 2 then
          let given_un = creds(0)?
          let given_pw = creds(1)?
          if _accounts(given_un)? == given_pw then
            p(RequestDataBuilder(method, uri, headers, captures, body))
          else
            p(ResponseDataBuilder(StatusUnauthorized, [("WWW-Authenticate", "\"".join(["Basic realm="; _realm; ""].values()))], ByteArrays))
          end
        else
          p(ResponseDataBuilder(StatusUnauthorized, [("WWW-Authenticate", "\"".join(["Basic realm="; _realm; ""].values()))], ByteArrays))
        end
      else
        p(ResponseDataBuilder(StatusUnauthorized, [("WWW-Authenticate", "\"".join(["Basic realm="; _realm; ""].values()))], ByteArrays))
      end
    else
      p(ResponseDataBuilder(StatusUnauthorized, [("WWW-Authenticate", "\"".join(["Basic realm="; _realm; ""].values()))], ByteArrays))
    end
    p
