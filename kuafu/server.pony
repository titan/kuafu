use "http_server"
use "logger"
use "promises"
use "valbytes"

class _ServerNotify
  let _logger: Logger[String] val

  new iso create(
    logger: Logger[String] val)
  =>
    _logger = logger

  fun ref listening(
    server: Server ref)
  =>
    try
      (let host, let service) = server.local_address().name()?
      _logger(Info) and _logger.log("Listening on " + host + ":" + service)
    else
      _logger(Error) and _logger.log("Couldn't get local address.")
      server.dispose()
    end

  fun ref not_listening(
    server: Server ref)
  =>
    _logger(Error) and _logger.log("Failed to listen.")

  fun ref closed(
    server: Server ref)
  =>
    _logger(Info) and _logger.log("Shutdown.")
