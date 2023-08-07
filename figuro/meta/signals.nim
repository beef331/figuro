import tables, strutils, macros
import std/times


import datatypes
export datatypes
export times

proc wrapResponse*(id: AgentId, resp: RpcParams, kind = Response): AgentResponse = 
  result.kind = kind
  result.id = id
  result.result = resp

proc wrapResponseError*(id: AgentId, err: AgentError): AgentResponse = 
  result.kind = Error
  result.id = id
  var ss: Variant
  ss.pack(err)
  result.result = RpcParams(buf: ss)

proc wrapResponseError*(
    id: AgentId,
    code: FastErrorCodes,
    msg: string,
    err: ref Exception,
    stacktraces: bool
): AgentResponse = 
  let errobj = AgentError(code: code, msg: msg)
  if stacktraces and not err.isNil():
    errobj.trace = @[]
    for se in err.getStackTraceEntries():
      let file: string = rsplit($(se.filename), '/', maxsplit=1)[^1]
      errobj.trace.add( ($se.procname, file, se.line, ) )
  result = wrapResponseError(id, errobj)

proc parseError*(ss: Variant): AgentError = 
  ss.unpack(result)

proc parseParams*[T](ss: Variant, val: var T) = 
  ss.unpack(val)

proc createRpcRouter*(): AgentRouter =
  result = new(AgentRouter)
  result.procs = initTable[string, AgentProc]()

proc register*(router: var AgentRouter, path, name: string, call: AgentProc) =
  router.procs[path] = call
  echo "registering: ", path

proc sysRegister*(router: var AgentRouter, path, name: string, call: AgentProc) =
  router.sysprocs[path] = call
  echo "registering: sys: ", path

var globalRouter {.global.} = AgentRouter()

proc register*(path, name: string, call: AgentProc) =
  globalRouter.procs[path] = call
  echo "registering: ", name, " @ ", path

proc clear*(router: var AgentRouter) =
  router.procs.clear

proc hasMethod*(router: AgentRouter, methodName: string): bool =
  router.procs.hasKey(methodName)

proc callMethod*(
        router: AgentRouter,
        ctx: RpcContext,
        req: AgentRequest,
        clientId: ClientId,
      ): AgentResponse {.gcsafe.} =
    ## Route's an rpc request. 
    var rpcProc: AgentProc 
    case req.kind:
    of Request:
      rpcProc = router.procs.getOrDefault(req.procName)
    of SystemRequest:
      rpcProc = router.sysprocs.getOrDefault(req.procName)
    of Subscribe:
      echo "CALL:METHOD: SUBSCRIBE"
      let hasSubProc = req.procName in router.subNames
      if not hasSubProc:
        let methodNotFound = req.procName & " is not a registered RPC method."
        return wrapResponseError(req.id, METHOD_NOT_FOUND,
                                 methodNotFound, nil,
                                 router.stacktraces)
    else:
      return wrapResponseError(
                  req.id,
                  SERVER_ERROR,
                  "unimplemented request typed",
                  nil, 
                  router.stacktraces)

    if rpcProc.isNil:
      let msg = req.procName & " is not a registered RPC method."
      let err = AgentError(code: METHOD_NOT_FOUND, msg: msg)
      result = wrapResponseError(req.id, err)
    else:
      try:
        # Handle rpc request the `context` variable is different
        # based on whether the rpc request is a system/regular/subscription
        rpcProc(ctx, req.params)
        let res = RpcParams(buf: newVariant(true)) 

        result = AgentResponse(kind: Response, id: req.id, result: res)
      except ConversionError as err:
        result = wrapResponseError(
                    req.id,
                    INVALID_PARAMS,
                    req.procName & " raised an exception",
                    err, 
                    router.stacktraces)
      except CatchableError as err:
        result = wrapResponseError(
                    req.id,
                    INTERNAL_ERROR,
                    req.procName & " raised an exception: " & err.msg,
                    err, 
                    router.stacktraces)
 
template packResponse*(res: AgentResponse): Variant =
  var so = newVariant()
  so.pack(res)
  so

proc callMethod*(router: AgentRouter,
                 ctx: RpcContext,
                 buffer: Variant,
                 clientId: ClientId,
                 ): Variant =
  # logDebug("msgpack processing")
  var req: AgentRequest
  buffer.unpack(req)
  var res: AgentResponse = router.callMethod(ctx, req, clientId)
  return newVariant(res)

template connect*[T: RootRef](
    a: T,
    signal: typed,
    b: T,
    slot: typed
) =
  echo "connect!a: ", repr typeof a
  echo "connect!a: ", repr typeof signal
  echo "connect!b: ", repr typeof b
  echo "connect!b: ", repr typeof slot

proc callSlots*(obj: Agent, req: AgentRequest) {.gcsafe.} =
  {.cast(gcsafe).}:
    let res = globalRouter.callMethod(obj, req, ClientId(0))

    # variantMatch case res.result.buf as u
    # of AgentError:
    # else:

var
  router {.global.}: AgentRouter
