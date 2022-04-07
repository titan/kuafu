use "collections"
use "http_server"
use "itertools"
use "logger"
use "pony_test"
use "promises"
use "valbytes"

primitive \nodoc\ _FormatLoc
  fun apply(
    loc: SourceLoc)
  : String =>
    loc.file() + ":" + loc.line().string() + ": "

actor \nodoc\ Main is TestList
  new create(
    env: Env)
  =>
    PonyTest(env, this)

  fun tag tests(
    test: PonyTest)
  =>
    test(_TestNotFound)
    test(_TestNormal)
    test(_TestMiddlewareBefore)
    test(_TestMiddlewareAfter)
    test(_TestMultiMiddleware)
    test(_TestParseQuery)

actor \nodoc\ _TestHTTPSession is Session
  let h: TestHelper
  let _promise: Promise[String]
  new create(
    h': TestHelper,
    promise: Promise[String])
  =>
    h = h'
    _promise = promise

  be _receive_start(request: Request val, request_id: RequestID) => None
  be _receive_chunk(data: Array[U8] val, request_id: RequestID) => None
  be _receive_finished(request_id: RequestID) => None
  be dispose() => None
  be _mute() => None
  be _unmute() => None
  be send_start(response: Response val, request_id: RequestID) => None
  be send_cancel(request_id: RequestID) => None
  be send_finished(request_id: RequestID) => None
  be send(response: Response val, body: ByteArrays, request_id: RequestID) => None
  be send_chunk(data: ByteSeq val, request_id: RequestID) => None
  be send_no_body(response: Response val, request_id: RequestID) => None
  be send_raw(
    raw: ByteSeqIter,
    request_id: RequestID,
    close_session: Bool = false)
  =>
    let rawstr: String trn = recover trn String end
    for r in raw.values() do
      match r
      | let r': String =>
        rawstr.append(r'.array())
      | let r': Array[U8] val =>
        rawstr.append(r')
      end
    end
    let rawstr': String val = consume rawstr
    _promise(rawstr')

class \nodoc\ _TestNotFound is UnitTest
  fun name()
  : String =>
    "Not found"

  fun apply(
    h: TestHelper) ?
  =>
    let logger = StringLogger(Info, h.env.out, _TimestampLogFormatter)
    let factory = _HandlerFactory(logger, [])
    let promise: Promise[String] = Promise[String]
    promise.next[None](recover this~_fulfill(h) end)
    let handler = factory(_TestHTTPSession(h, promise))
    let request = BuildableRequest(where uri' = URL.build("/")?)
    handler(consume request, 1)
    handler.finished(1)
    h.long_test(1_000_000_000)

  fun tag _fulfill(
    h: TestHelper,
    value: String)
  =>
    h.assert_eq[Bool](value.contains("404"), true)
    h.complete(true)

  fun timed_out(
    h: TestHelper)
  =>
    h.complete(false)

primitive _FooBarHandler
  fun val apply(
    method: Method val,
    uri: URL val,
    headers: Array[Header val] val,
    captures: Array[(String val, String val)] val,
    body: ByteArrays val)
  : Promise[ResponseData] =>
    let p: Promise[ResponseData] = Promise[ResponseData]
    var bar: String val = ""
    for (key, value) in captures.values() do
      if key == "bar" then
        bar = value
        break
      end
    end
    p((StatusOK, headers, ByteArrays(bar.array())))
    p

class \nodoc\ _TestNormal is UnitTest
  fun name()
  : String =>
    "Normal"

  fun apply(
    h: TestHelper) ?
  =>
    _test(h, CONNECT)?
    _test(h, DELETE)?
    _test(h, GET)?
    _test(h, HEAD)?
    _test(h, OPTIONS)?
    _test(h, PATCH)?
    _test(h, POST)?
    _test(h, PUT)?
    _test(h, TRACE)?

  fun _test(
    h: TestHelper,
    method: Method) ?
  =>
    let logger = StringLogger(Info, h.env.out, _TimestampLogFormatter)
    let factory = _HandlerFactory(logger, [(method, "/foo/:bar", _FooBarHandler, [])])
    let promise: Promise[String] = Promise[String]
    promise.next[None](recover this~_fulfill(h) end)
    let handler = factory(_TestHTTPSession(h, promise))
    let request = BuildableRequest(where method' = method, uri' = URL.build("/foo/bar")?)
    handler(consume request, 1)
    handler.finished(1)
    h.long_test(1_000_000_000)

  fun tag _fulfill(
    h: TestHelper,
    value: String)
  =>
    h.assert_eq[Bool](value.contains("200"), true)
    h.assert_eq[Bool](value.contains("bar"), true)
    h.complete(true)

  fun timed_out(
    h: TestHelper)
  =>
    h.complete(false)

primitive _FooBarMiddlewareBefore is Middleware
  fun val before(
    method: Method val,
    uri: URL val,
    headers: Array[Header val] val,
    captures: Array[(String val, String val)] val,
    body: ByteArrays val)
  : Promise[(ResponseData | RequestData)] =>
    let p: Promise[(ResponseData | RequestData)] = Promise[(ResponseData | RequestData)]
    let headers': Array[Header val] trn = recover trn Array[Header val](headers.size() + 1) end
    for header in headers.values() do
      headers'.push(header)
    end
    headers'.push(("Authoriation", "Any"))
    p((method, uri, consume headers', captures, body))
    p

class \nodoc\ _TestMiddlewareBefore is UnitTest
  fun name()
  : String =>
    "Middleware-before"

  fun apply(
    h: TestHelper) ?
  =>
    let logger = StringLogger(Info, h.env.out, _TimestampLogFormatter)
    let factory = _HandlerFactory(logger, [(GET, "/foo/:bar", _FooBarHandler, [_FooBarMiddlewareBefore])])
    let promise: Promise[String] = Promise[String]
    promise.next[None](recover this~_fulfill(h) end)
    let handler = factory(_TestHTTPSession(h, promise))
    let request = BuildableRequest(where method' = GET, uri' = URL.build("/foo/bar")?)
    handler(consume request, 1)
    handler.finished(1)
    h.long_test(1_000_000_000)

  fun tag _fulfill(
    h: TestHelper,
    value: String)
  =>
    h.assert_eq[Bool](value.contains("200"), true)
    h.assert_eq[Bool](value.contains("Authoriation: Any"), true)
    h.assert_eq[Bool](value.contains("bar"), true)
    h.complete(true)

  fun timed_out(
    h: TestHelper)
  =>
    h.complete(false)

primitive _FooBarMiddlewareAfter is Middleware
  fun val after(
    status: Status val,
    headers: Array[Header val] val,
    body: ByteArrays val)
  : Promise[ResponseData] =>
    let p: Promise[ResponseData] = Promise[ResponseData]
    let headers': Array[Header val] trn = recover trn Array[Header val](headers.size() + 1) end
    for header in headers.values() do
      if header._1 != "Location" then
        headers'.push(header)
      end
    end
    headers'.push(("Location", "localhost"))

    p((StatusMovedPermanently, consume headers', body))
    p

class \nodoc\ _TestMiddlewareAfter is UnitTest
  fun name()
  : String =>
    "Middleware-after"

  fun apply(
    h: TestHelper) ?
  =>
    let logger = StringLogger(Info, h.env.out, _TimestampLogFormatter)
    let factory = _HandlerFactory(logger, [(GET, "/foo/:bar", _FooBarHandler, [_FooBarMiddlewareAfter])])
    let promise: Promise[String] = Promise[String]
    promise.next[None](recover this~_fulfill(h) end)
    let handler = factory(_TestHTTPSession(h, promise))
    let request = BuildableRequest(where method' = GET, uri' = URL.build("/foo/bar")?)
    handler(consume request, 1)
    handler.finished(1)
    h.long_test(1_000_000_000)

  fun tag _fulfill(
    h: TestHelper,
    value: String)
  =>
    h.assert_eq[Bool](value.contains("301"), true)
    h.assert_eq[Bool](value.contains("Location: localhost"), true)
    h.assert_eq[Bool](value.contains("bar"), true)
    h.complete(true)

  fun timed_out(
    h: TestHelper)
  =>
    h.complete(false)

class \nodoc\ _TestMultiMiddleware is UnitTest
  fun name()
  : String =>
    "MultiMiddleware"

  fun apply(
    h: TestHelper) ?
  =>
    let logger = StringLogger(Info, h.env.out, _TimestampLogFormatter)
    let factory = _HandlerFactory(logger, [(GET, "/foo/:bar", _FooBarHandler, [_FooBarMiddlewareBefore; _FooBarMiddlewareAfter])])
    let promise: Promise[String] = Promise[String]
    promise.next[None](recover this~_fulfill(h) end)
    let handler = factory(_TestHTTPSession(h, promise))
    let request = BuildableRequest(where method' = GET, uri' = URL.build("/foo/bar")?)
    handler(consume request, 1)
    handler.finished(1)
    h.long_test(1_000_000_000)

  fun tag _fulfill(
    h: TestHelper,
    value: String)
  =>
    h.assert_eq[Bool](value.contains("301"), true)
    h.assert_eq[Bool](value.contains("Authoriation: Any"), true)
    h.assert_eq[Bool](value.contains("Location: localhost"), true)
    h.assert_eq[Bool](value.contains("bar"), true)
    h.complete(true)

  fun timed_out(
    h: TestHelper)
  =>
    h.complete(false)

class \nodoc\ _TestParseQuery is UnitTest
  fun name()
  : String =>
    "Parse query"

  fun apply(
    h: TestHelper) ?
  =>
    _test(
      h,
      "http://test?foo=bar",
      [
        ("foo", "bar")
      ]
    )?
    _test(
      h,
      "http://test?foo1=bar1&foo2=bar2",
      [
        ("foo1", "bar1")
        ("foo2", "bar2")
      ]
    )?
    _test(
      h,
      "http://test?foo=&=bar",
      [
        ("foo", "")
        ("", "bar")
      ]
    )?
    _test(
      h,
      "http://test?foo",
      [
        ("foo", "")
      ]
    )?
    _test(
      h,
      "http://test?=",
      [
        ("", "")
      ]
    )?

  fun _test(
    h: TestHelper,
    url: String val,
    expect: Array[(String val, String val)] val,
    loc: SourceLoc = __loc) ?
  =>
    let actual = QueryHelper.parse(URL.build(url)?.query)
    _assert_parameter_array_eq(h, expect, actual where loc = loc)

  fun _print_parameter_array(
    array: ReadSeq[(String val, String val)])
  : String =>
    "[" + ", ".join(Iter[(String val, String val)](array.values()).map[String]({(x: (String val, String val)): String => "(" + x._1 + ", " + x._2 + ")"})) + "]"

  fun _assert_parameter_array_eq(
    h: TestHelper,
    expect: ReadSeq[(String val, String val)],
    actual: ReadSeq[(String val, String val)],
    msg: String = "",
    loc: SourceLoc = __loc)
  : Bool =>
    var ok = true

    if expect.size() != actual.size() then
      ok = false
    else
      try
        var i: USize = 0
        while i < expect.size() do
          if (expect(i)?._1 != actual(i)?._1) or (expect(i)?._2 != actual(i)?._2) then
            ok = false
            break
          end

          i = i + 1
        end
      else
        ok = false
      end
    end

    if not ok then
      h.fail(_FormatLoc(loc) + "Assert EQ failed. " + msg + " Expected ("
        + _print_parameter_array(expect) + ") == (" + _print_parameter_array(actual) + ")")
      return false
    end

    true
