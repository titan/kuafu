# kuafu

A simple restful framework written in [Pony](https://www.ponylang.io) language.

## Features

- **Asynchronous Middleware Chaining:** Easily add multiple middlewares to the
  rout which can execute asynchronous functions both before and after the
  request handler.

- **Fast Route Matches:** A request can only match exactly one or no route by
  [bitset-router](https://github.com/titan/pony-bitset-router). But it limits to
  hold only 128 routes for every HTTP methods.

## Usage

### Installation

1. Install [corral](https://github.com/ponylang/corral)

2. `corral add -r master github.com/titan/kuafu.git`

3. `corral fetch` to fetch your dependencies

4. `use "bitset-router"` to include this package

5. `corral run -- ponyc` to compile your application

### Named Parameters

``` pony
use "http_server"
use "kuafu"
use "net"
use "promises"
use "valbytes"

actor Main
  new create(env: Env) =>
    let tcplauth: TCPListenAuth = TCPListenAuth(env.root)

    let server =
      Kuafu(tcplauth, env.out)
        .> get("/", H)
        .> get("/:name", H)
        .serve(ServerConfig(where port' = "8080"))

primitive H is RequestHandler
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
```

In above example, `:name` is a named parameter, and the value can be retrieved
by `QueryHelper.get_or_else(captures, "name")`.

Named parameters only match a single path segment:

```
Path: /users/:username

  /users/foo                match
  /users/bar                match
  /users/foo/bar            no match
  /users/                   no match
```

[bitset-router](https://github.com/titan/pony-bitset-router.git) also supports
wildcard parameters that may be used at the end of a path:

```
Path: /static/*filepath

  /static/foo                match
  /static/foo/bar.html       match
```
### Using Middleware

``` pony
use "collections"
use "encode/base64"
use "http_server"
use "kuafu"
use "net"
use "promises"
use "valbytes"

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
```

Above example uses Basic Authentication (RFC 2617) with a middleware.
