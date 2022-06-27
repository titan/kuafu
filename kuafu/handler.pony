use "bitset-router"
use "collections"
use "http_server"
use "logger"
use "promises"
use "valbytes"

type ResponseData is
  ( Status val // http status code
  , Array[Header val] val // headers
  , ByteArrays val // body
  )

primitive ResponseDataBuilder
  fun val apply(
    status: Status val,
    headers: Array[Header val] val,
    body: ByteArrays val)
  : ResponseData =>
    (status, headers, body)

type RequestData is
  ( Method val // http method
  , URL val // url
  , Array[Header val] val // headers
  , Array[(String val, String val)] val // captured paramters from url
  , ByteArrays val // body
  )

primitive RequestDataBuilder
  fun val apply(
    method: Method val,
    uri: URL val,
    headers: Array[Header val] val,
    captures: Array[(String val, String val)] val,
    body: ByteArrays val)
  : RequestData =>
    (method, uri, headers, captures, body)

type Middleware is
  ( {(Method val, URL val, Array[Header val] val, Array[(String val, String val)] val, ByteArrays val): Promise[(ResponseData | RequestData)]} val // before
  , {(Status val, Array[Header val] val, ByteArrays val): Promise[ResponseData]} val // after
  )

primitive DefaultMiddleware
  fun val before(
    method: Method val,
    uri: URL val, // url
    headers: Array[Header val] val,
    captures: Array[(String val, String val)] val, // captured parameters from url
    body: ByteArrays val)
  : Promise[(ResponseData | RequestData)] =>
    let p: Promise[(ResponseData | RequestData)] = Promise[(ResponseData | RequestData)]
    p((method, uri, headers, captures, body))
    p

  fun val after(
    status: Status val,
    headers: Array[Header val] val,
    body: ByteArrays val)
  : Promise[ResponseData] =>
    let p: Promise[ResponseData] = Promise[ResponseData]
    p((status, headers, body))
    p

type RequestHandler is {(Method val, URL val, Array[Header val] val, Array[(String val, String val)] val, ByteArrays val): Promise[ResponseData]} val

type Route is
  ( Method val // http method
  , String val // url path
  , RequestHandler // request handler
  , Array[Middleware] val // middlewares
  )

type _HandlerPair is
  ( RequestHandler
  , Array[Middleware] val
  )

type _RouteData is
  ( _HandlerPair
  , Method // http method
  , URL val // uri
  , Array[Header val] val // headers
  , Array[(String val, String val)] val // captures
  , ByteArrays // body
  )

class _Handler is Handler
  """
  Backend application instance for a single HTTP session.

  Executed on an actor representing the HTTP Session.
  That means we have 1 actor per TCP Connection
  (to be exact it is 2 as the TCPConnection is also an actor).
  """
  let _session: Session
  let _not_found: _HandlerPair
  let _connect_router: Router val
  let _connect_handlers: Array[_HandlerPair] val
  let _delete_router: Router val
  let _delete_handlers: Array[_HandlerPair] val
  let _get_router: Router val
  let _get_handlers: Array[_HandlerPair] val
  let _head_router: Router val
  let _head_handlers: Array[_HandlerPair] val
  let _options_router: Router val
  let _options_handlers: Array[_HandlerPair] val
  let _patch_router: Router val
  let _patch_handlers: Array[_HandlerPair] val
  let _post_router: Router val
  let _post_handlers: Array[_HandlerPair] val
  let _put_router: Router val
  let _put_handlers: Array[_HandlerPair] val
  let _trace_router: Router val
  let _trace_handlers: Array[_HandlerPair] val
  embed _reqs: Map[RequestID, _RouteData] = Map[RequestID, _RouteData]

  new create(
    session: Session,
    not_found: _HandlerPair,
    connect_router: Router val,
    connect_handlers: Array[_HandlerPair] val,
    delete_router: Router val,
    delete_handlers: Array[_HandlerPair] val,
    get_router: Router val,
    get_handlers: Array[_HandlerPair] val,
    head_router: Router val,
    head_handlers: Array[_HandlerPair] val,
    options_router: Router val,
    options_handlers: Array[_HandlerPair] val,
    patch_router: Router val,
    patch_handlers: Array[_HandlerPair] val,
    post_router: Router val,
    post_handlers: Array[_HandlerPair] val,
    put_router: Router val,
    put_handlers: Array[_HandlerPair] val,
    trace_router: Router val,
    trace_handlers: Array[_HandlerPair] val)
  =>
    _session = session
    _not_found = not_found
    _connect_router = connect_router
    _connect_handlers = connect_handlers
    _delete_router = delete_router
    _delete_handlers = delete_handlers
    _get_router = get_router
    _get_handlers = get_handlers
    _head_router = head_router
    _head_handlers = head_handlers
    _options_router = options_router
    _options_handlers = options_handlers
    _patch_router = patch_router
    _patch_handlers = patch_handlers
    _post_router = post_router
    _post_handlers = post_handlers
    _put_router = put_router
    _put_handlers = put_handlers
    _trace_router = trace_router
    _trace_handlers = trace_handlers

  fun ref apply(
    req: Request,
    id: RequestID)
  =>
    let method = req.method()
    let path = req.uri().path
    let headers = recover Array[Header val] .> concat(req.headers()) end
    (let handler_pair: _HandlerPair, let captures: Array[(String val, String val)] val) =
      match method
      | CONNECT =>
        match _connect_router.find(path)
        | (let idx: USize val, let captures': Array[(String val, String val)] val) =>
          try
            let handler_pair' = _connect_handlers(idx)?
            (handler_pair', captures')
          else
            (_not_found, captures')
          end
        else
          (_not_found, [])
        end
      | DELETE =>
        match _delete_router.find(path)
        | (let idx: USize val, let captures': Array[(String val, String val)] val) =>
          try
            let handler_pair' = _delete_handlers(idx)?
            (handler_pair', captures')
          else
            (_not_found, captures')
          end
        else
          (_not_found, [])
        end
      | GET =>
        match _get_router.find(path)
        | (let idx: USize val, let captures': Array[(String val, String val)] val) =>
          try
            let handler_pair' = _get_handlers(idx)?
            (handler_pair', captures')
          else
            (_not_found, captures')
          end
        else
          (_not_found, [])
        end
      | HEAD =>
        match _head_router.find(path)
        | (let idx: USize val, let captures': Array[(String val, String val)] val) =>
          try
            let handler_pair' = _head_handlers(idx)?
            (handler_pair', captures')
          else
            (_not_found, captures')
          end
        else
          (_not_found, [])
        end
      | OPTIONS =>
        match _options_router.find(path)
        | (let idx: USize val, let captures': Array[(String val, String val)] val) =>
          try
            let handler_pair' = _options_handlers(idx)?
            (handler_pair', captures')
          else
            (_not_found, captures')
          end
        else
          (_not_found, [])
        end
      | PATCH =>
        match _patch_router.find(path)
        | (let idx: USize val, let captures': Array[(String val, String val)] val) =>
          try
            let handler_pair' = _patch_handlers(idx)?
            (handler_pair', captures')
          else
            (_not_found, captures')
          end
        else
          (_not_found, [])
        end
      | POST =>
        match _post_router.find(path)
        | (let idx: USize val, let captures': Array[(String val, String val)] val) =>
          try
            let handler_pair' = _post_handlers(idx)?
            (handler_pair', captures')
          else
            (_not_found, captures')
          end
        else
          (_not_found, [])
        end
      | PUT =>
        match _put_router.find(path)
        | (let idx: USize val, let captures': Array[(String val, String val)] val) =>
          try
            let handler_pair' = _put_handlers(idx)?
            (handler_pair', captures')
          else
            (_not_found, captures')
          end
        else
          (_not_found, [])
        end
      | TRACE =>
        match _trace_router.find(path)
        | (let idx: USize val, let captures': Array[(String val, String val)] val) =>
          try
            let handler_pair' = _trace_handlers(idx)?
            (handler_pair', captures')
          else
            (_not_found, captures')
          end
        else
          (_not_found, [])
        end
      else
        (_not_found, [])
      end
    _reqs(id) = (handler_pair, method, req.uri(), consume headers, captures, ByteArrays)

  fun ref chunk(
    data: ByteSeq val,
    id: RequestID)
  =>
    try
      (let req) = _reqs(id)?
      _reqs(id) = (req._1, req._2, req._3, req._4, req._5, req._6 + data)
    end

  fun tag _send_response(
    session: Session,
    id: RequestID,
    response: ResponseData)
  =>
    let builder: ResponseBuilder = Responses.builder()
    let head_builder: ResponseBuilderHeaders = builder.set_status(response._1)
    for (key, value) in response._2.values() do
      head_builder.add_header(key, value)
    end
    head_builder.add_header("Content-Length", response._3.size().string())
    let body_builder: ResponseBuilderBody = head_builder.finish_headers()
    body_builder.add_chunk(response._3.array())
    session.send_raw(body_builder.build(), id)
    session.send_finished(id)

  fun ref finished(
    id: RequestID)
  =>
    try
      (_, ((let request_handler, let middlewares), let method, let uri, let headers, let captures, let body)) = _reqs.remove(id)?
      let p: Promise[ResponseData] = _RouteHandler(method, uri, headers, captures, body, request_handler, middlewares)?
      p.next[None]({(x: ResponseData)(self: _Handler tag = this) =>
        self._send_response(_session, id, x)
      })
    else
      _session.dispose()
    end

  fun ref cancelled(
    id: RequestID)
  =>
    try _reqs.remove(id)? end

  fun ref failed(
    reason: RequestParseError,
    id: RequestID)
  =>
    try
      _reqs.remove(id)?
      _session.dispose()
    end

class val _HandlerFactory is HandlerFactory
  let _logger: Logger[String]
  let _not_found: _HandlerPair
  let _connect_router: Router val
  let _connect_handlers: Array[_HandlerPair] val
  let _delete_router: Router
  let _delete_handlers: Array[_HandlerPair] val
  let _get_router: Router
  let _get_handlers: Array[_HandlerPair] val
  let _head_router: Router
  let _head_handlers: Array[_HandlerPair] val
  let _options_router: Router
  let _options_handlers: Array[_HandlerPair] val
  let _patch_router: Router
  let _patch_handlers: Array[_HandlerPair] val
  let _post_router: Router
  let _post_handlers: Array[_HandlerPair] val
  let _put_router: Router
  let _put_handlers: Array[_HandlerPair] val
  let _trace_router: Router
  let _trace_handlers: Array[_HandlerPair] val

  new val create(
    logger: Logger[String] val,
    routes: Array[Route] val)
  =>
    _logger = logger
    _not_found = (_NotFoundHandler~apply(), [])
    let connect_router: Router trn = Router
    let connect_handlers: Array[_HandlerPair] trn = recover trn Array[_HandlerPair] end
    let delete_router: Router trn = Router
    let delete_handlers: Array[_HandlerPair] trn = recover trn Array[_HandlerPair] end
    let get_router: Router trn = Router
    let get_handlers: Array[_HandlerPair] trn = recover trn Array[_HandlerPair] end
    let head_router: Router trn = Router
    let head_handlers: Array[_HandlerPair] trn = recover trn Array[_HandlerPair] end
    let options_router: Router trn = Router
    let options_handlers: Array[_HandlerPair] trn = recover trn Array[_HandlerPair] end
    let patch_router: Router trn = Router
    let patch_handlers: Array[_HandlerPair] trn = recover trn Array[_HandlerPair] end
    let post_router: Router trn = Router
    let post_handlers: Array[_HandlerPair] trn = recover trn Array[_HandlerPair] end
    let put_router: Router trn = Router
    let put_handlers: Array[_HandlerPair] trn = recover trn Array[_HandlerPair] end
    let trace_router: Router trn = Router
    let trace_handlers: Array[_HandlerPair] trn = recover trn Array[_HandlerPair] end
    for route in routes.values() do
      let method = route._1
      let path = route._2
      let handler = route._3
      let middlewares = route._4
      match method
      | CONNECT =>
        match connect_router.add(path)
        | let err: String val =>
          _logger(Error) and _logger.log(method.string() + " " + path + ": " + err)
        else
          connect_handlers.push((handler, middlewares))
        end
      | DELETE =>
        match delete_router.add(path)
        | let err: String val =>
          _logger(Error) and _logger.log(method.string() + " " + path + ": " + err)
        else
          delete_handlers.push((handler, middlewares))
        end
      | GET =>
        match get_router.add(path)
        | let err: String val =>
          _logger(Error) and _logger.log(method.string() + " " + path + ": " + err)
        else
          get_handlers.push((handler, middlewares))
        end
      | HEAD =>
        match head_router.add(path)
        | let err: String val =>
          _logger(Error) and _logger.log(method.string() + " " + path + ": " + err)
        else
          head_handlers.push((handler, middlewares))
        end
      | OPTIONS =>
        match options_router.add(path)
        | let err: String val =>
          _logger(Error) and _logger.log(method.string() + " " + path + ": " + err)
        else
          options_handlers.push((handler, middlewares))
        end
      | PATCH =>
        match patch_router.add(path)
        | let err: String val =>
          _logger(Error) and _logger.log(method.string() + " " + path + ": " + err)
        else
          patch_handlers.push((handler, middlewares))
        end
      | POST =>
        match post_router.add(path)
        | let err: String val =>
          _logger(Error) and _logger.log(method.string() + " " + path + ": " + err)
        else
          post_handlers.push((handler, middlewares))
        end
      | PUT =>
        match put_router.add(path)
        | let err: String val =>
          _logger(Error) and _logger.log(method.string() + " " + path + ": " + err)
        else
          put_handlers.push((handler, middlewares))
        end
      | TRACE =>
        match trace_router.add(path)
        | let err: String val =>
          _logger(Error) and _logger.log(method.string() + " " + path + ": " + err)
        else
          trace_handlers.push((handler, middlewares))
        end
      end
    end
    _connect_router = consume connect_router
    _connect_handlers = consume connect_handlers
    _delete_router = consume delete_router
    _delete_handlers = consume delete_handlers
    _get_router = consume get_router
    _get_handlers = consume get_handlers
    _head_router = consume head_router
    _head_handlers = consume head_handlers
    _options_router = consume options_router
    _options_handlers = consume options_handlers
    _patch_router = consume patch_router
    _patch_handlers = consume patch_handlers
    _post_router = consume post_router
    _post_handlers = consume post_handlers
    _put_router = consume put_router
    _put_handlers = consume put_handlers
    _trace_router = consume trace_router
    _trace_handlers = consume trace_handlers

  fun apply(
    session: Session)
  : Handler ref^ =>
    recover ref _Handler(
      session,
      _not_found,
      _connect_router,
      _connect_handlers,
      _delete_router,
      _delete_handlers,
      _get_router,
      _get_handlers,
      _head_router,
      _head_handlers,
      _options_router,
      _options_handlers,
      _patch_router,
      _patch_handlers,
      _post_router,
      _post_handlers,
      _put_router,
      _put_handlers,
      _trace_router,
      _trace_handlers
    ) end

primitive _NotFoundHandler
  fun val apply(
    method: Method val,
    uri: URL val,
    headers: Array[Header val] val,
    captures: Array[(String val, String val)] val,
    body: ByteArrays val)
  : Promise[ResponseData] =>
    let p: Promise[ResponseData] = Promise[ResponseData]
    p((StatusNotFound, [], ByteArrays))
    p

primitive _RouteHandler
  fun val before(
    index: USize,
    method: Method val,
    uri: URL val,
    headers: Array[Header val] val,
    captures: Array[(String val, String val)] val,
    body: ByteArrays val,
    handler: RequestHandler val,
    middlewares: Array[Middleware val] val)
  : Promise[(USize val, ResponseData)]? =>
    if index == middlewares.size() then
      let p: Promise[ResponseData] = handler(method, uri, headers, captures, body)
      p.next[(USize val, ResponseData)]({(x: ResponseData): (USize val, ResponseData) =>
        (index, x)
      })
    else
      let p: Promise[(ResponseData | RequestData)] = middlewares(index)?._1(method, uri, headers, captures, body)
      p.flatten_next[(USize val, ResponseData)]({(x: (ResponseData | RequestData))(self: _RouteHandler val = this): Promise[(USize val, ResponseData)]? =>
        match x
        | let x': ResponseData =>
          let p': Promise[(USize val, ResponseData)] = Promise[(USize val, ResponseData)]
          p'((index, x'))
          p'
        | let x': RequestData =>
          self.before(index + 1, x'._1, x'._2, x'._3, x'._4, x'._5, handler, middlewares)?
        end
      })
    end

  fun val after(
    index: USize,
    status: Status val,
    headers: Array[Header val] val,
    body: ByteArrays val,
    middlewares: Array[Middleware val] val)
  : Promise[ResponseData]? =>
    if index == -1 then
      let p: Promise[ResponseData] = Promise[ResponseData]
      p((status, headers, body))
      p
    else
      let p = middlewares(index)?._2(status, headers, body)
      p.flatten_next[ResponseData]({(x: ResponseData)(self: _RouteHandler val = this): Promise[ResponseData]? =>
        self.after(index - 1, x._1, x._2, x._3, middlewares)?
      })
    end

  fun val apply(
    method: Method val,
    uri: URL val,
    headers: Array[Header val] val,
    captures: Array[(String val, String val)] val,
    body: ByteArrays val,
    handler: RequestHandler val,
    middlewares: Array[Middleware val] val)
  : Promise[ResponseData]? =>
    let p: Promise[(USize val, ResponseData)] = before(0, method, uri, headers, captures, body, handler, middlewares)?
    p.flatten_next[ResponseData]({(x: (USize val, ResponseData))(self: _RouteHandler val = this): Promise[ResponseData]? =>
      self.after(x._1 - 1, x._2._1, x._2._2, x._2._3, middlewares)?
    })
