
interface _ParameterFetcher
  fun get_or_else(
    values: Array[(String val, String val)] val,
    key: String val,
    default: String val = "")
  : String val =>
    for value in values.values() do
      if key == value._1 then
        return value._2
      end
    end
    default

primitive _InitState

primitive _KeyState

primitive _ValueState

type _ParameterParseState is
  ( _InitState
  | _KeyState
  | _ValueState
  )

primitive QueryHelper is _ParameterFetcher
  fun parse(
    query: String val)
  : Array[(String val, String val)] val =>
    var state: _ParameterParseState = _InitState
    var buf: String ref = String
    var key: String val = ""
    var value: String val = ""
    let result: Array[(String val, String val)] trn = recover trn Array[(String val, String val)] end
    for c in query.values() do
      match state
      | _InitState =>
        match c
        | '+' =>
          buf.push(' ')
          state = _KeyState
        | '=' =>
          state = _ValueState
        | '&' =>
          state = _KeyState
        else
          buf.push(c)
          state = _KeyState
        end
      | _KeyState =>
        match c
        | '+' =>
          buf.push(' ')
        | '&' =>
          key = buf.clone()
          buf.clear()
          result.push((key, ""))
          key = ""
        | '=' =>
          key = buf.clone()
          buf.clear()
          state = _ValueState
        else
          buf.push(c)
        end
      | _ValueState =>
        match c
        | '+' =>
          buf.push(' ')
        | '&' =>
          value = buf.clone()
          buf.clear()
          result.push((key, value))
          key = ""
          value = ""
          state = _InitState
        else
          buf.push(c)
        end
      end
    end
    match state
    | _KeyState =>
      result.push((buf.clone(), ""))
    | _ValueState =>
      result.push((key, buf.clone()))
      key = ""
    end
    consume result

primitive HeaderHelper is _ParameterFetcher
