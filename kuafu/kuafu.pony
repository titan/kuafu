use "collections"
use "http_server"
use "logger"
use "net"
use "time"

primitive _TimestampLogFormatter is LogFormatter
  fun box apply(msg: String val, loc: SourceLoc val): String val =>
    (let seconds, let nanoseconds) = Time.now()
    let date = PosixDate(seconds, nanoseconds)
    try
      let time = date.format("%Y-%m-%d %H:%M:%S")?
      "[" + time + "] " + msg
    else
      msg
    end

class iso Kuafu
  let _auth: TCPListenAuth val
  let _logger: Logger[String] val
  let _routes: Array[Route] iso = recover Array[Route] end
  var _not_found: _HandlerPair = (_NotFoundHandler~apply(), [])

  new iso create(
    auth: TCPListenAuth val,
    out: OutStream,
    log_level: LogLevel = Info)
  =>
    _auth = auth
    _logger = StringLogger(log_level, out, _TimestampLogFormatter)

  fun ref add(
    route: Route)
  =>
    _routes.push(route)

  fun ref connect(
    pattern: String val,
    handler: RequestHandler,
    middlewares: Array[Middleware] val = [])
  =>
    """
    Create a route for a CONNECT method on the given URL path with the given
    handler and middlewares.
    """
    _routes.push((CONNECT, pattern, handler, middlewares))

  fun ref delete(
    pattern: String val,
    handler: RequestHandler,
    middlewares: Array[Middleware] val = [])
  =>
    """
    Create a route for a DELETE method on the given URL path with the given
    handler and middlewares.
    """
    _routes.push((DELETE, pattern, handler, middlewares))

  fun ref get(
    pattern: String val,
    handler: RequestHandler,
    middlewares: Array[Middleware] val = [])
  =>
    """
    Create a route for a GET method on the given URL path with the given handler
    and middlewares.
    """
    _routes.push((GET, pattern, handler, middlewares))

  fun ref head(
    pattern: String val,
    handler: RequestHandler,
    middlewares: Array[Middleware] val = [])
  =>
    """
    Create a route for a HEAD method on the given URL path with the given
    handler and middlewares.
    """
    _routes.push((HEAD, pattern, handler, middlewares))

  fun ref options(
    pattern: String val,
    handler: RequestHandler,
    middlewares: Array[Middleware] val = [])
  =>
    """
    Create a route for a OPTIONS method on the given URL path with the given
    handler and middlewares.
    """
    _routes.push((OPTIONS, pattern, handler, middlewares))

  fun ref patch(
    pattern: String val,
    handler: RequestHandler,
    middlewares: Array[Middleware] val = [])
  =>
    """
    Create a route for a PATCH method on the given URL path with the given
    handler and middlewares.
    """
    _routes.push((PATCH, pattern, handler, middlewares))

  fun ref post(
    pattern: String val,
    handler: RequestHandler,
    middlewares: Array[Middleware] val = [])
  =>
    """
    Create a route for a POST method on the given URL path with the given
    handler and middlewares.
    """
    _routes.push((POST, pattern, handler, middlewares))

  fun ref put(
    pattern: String val,
    handler: RequestHandler,
    middlewares: Array[Middleware] val = [])
  =>
    """
    Create a route for a PUT method on the given URL path with the given handler
    and middlewares.
    """
    _routes.push((PUT, pattern, handler, middlewares))

  fun ref trace(
    pattern: String val,
    handler: RequestHandler,
    middlewares: Array[Middleware] val = [])
  =>
    """
    Create a route for a TRACE method on the given URL path with the given
    handler and middlewares.
    """
    _routes.push((TRACE, pattern, handler, middlewares))

  fun ref not_found(
    handler: RequestHandler,
    middlewares: Array[Middleware] val = [])
  =>
    """
    Setup handler and middlewares for routes not found.
    """
    _not_found = (handler~apply(), middlewares)

  fun val serve(
    config: ServerConfig)
  : Server =>
    """
    Serve incoming HTTP requests.
    """
    let server_notify = _ServerNotify(_logger)
    let handler_factory = _HandlerFactory(_logger, _routes, _not_found)
    Server(_auth, consume server_notify, handler_factory, config)
