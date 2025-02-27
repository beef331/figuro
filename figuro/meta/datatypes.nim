
import std/[options, tables, sets, macros, hashes]
import std/times

# import pkg/threading/channels

# import equeues
import protocol

when defined(nimscript):
  import std/json
  import ../runtime/jsonutils_lite
  export json
elif defined(useJsonSerde):
  import std/json
  import std/jsonutils
  export json
else:
  import pkg/variant

export protocol
export sets
export options
export variant

type
  Agent* = ref object of RootObj
    agentId*: int = 0
    listeners*: Table[string, OrderedSet[(Agent, AgentProc)]]

  # Context for servicing an RPC call 
  RpcContext* = Agent

  # Procedure signature accepted as an RPC call by server
  AgentProc* = proc(context: RpcContext,
                    params: RpcParams,
                    ) {.nimcall.}

  SignalTypes* = distinct object

when defined(nimscript):
  proc getAgentId(a: Agent): int = discard
  proc getAgentId(a: AgentProc): int = discard
  var lastUId {.compileTime.}: int = 1
else:
  proc getAgentId(a: Agent): int = cast[int](cast[pointer](a))
  proc getAgentId(a: AgentProc): int = cast[int](cast[pointer](a))
  var lastUId: int = 0

proc nextAgentId*(): int =
  lastUId.inc()
  lastUId

proc new*[T: Agent](tp: typedesc[T]): T =
  result = T()
  result.agentId = nextAgentId()

proc hash*(a: Agent): Hash = hash(getAgentId(a))
proc hash*(a: AgentProc): Hash = hash(getAgentId(a))

type

  ConversionError* = object of CatchableError
  AgentSlotError* = object of CatchableError

  AgentErrorStackTrace* = object
    code*: int
    msg*: string
    stacktrace*: seq[string]

  AgentBindError* = object of ValueError
  AgentAddressUnresolvableError* = object of ValueError

  AgentRouter* = ref object
    procs*: Table[string, AgentProc]
    sysprocs*: Table[string, AgentProc]
    # subEventProcs*: Table[Event, RpcSubClients]
    # subNames*: Table[string, Event]
    stacktraces*: bool
    subscriptionTimeout*: Duration
    # inQueue*: EventQueue[Variant]
    # outQueue*: EventQueue[Variant]
    # registerQueue*: EventQueue[InetQueueItem[RpcSubOpts]]

proc pack*[T](ss: var Variant, val: T) =
  echo "Pack Type: ", getTypeId(T), " <- ", typeof(val)
  ss = newVariant(val)

proc unpack*[T](ss: Variant, obj: var T) =
  if ss.ofType(T):
    obj = ss.get(T)
  else:
    raise newException(ConversionError, "couldn't convert to: " & $(T))

proc newAgentRouter*(
    inQueueSize = 2,
    outQueueSize = 2,
    registerQueueSize = 2,
): AgentRouter =
  new(result)
  result.procs = initTable[string, AgentProc]()
  result.sysprocs = initTable[string, AgentProc]()
  result.stacktraces = true

proc listMethods*(rt: AgentRouter): seq[string] =
  ## list the methods in the given router. 
  result = newSeqOfCap[string](rt.procs.len())
  for name in rt.procs.keys():
    result.add name

proc listSysMethods*(rt: AgentRouter): seq[string] =
  ## list the methods in the given router. 
  result = newSeqOfCap[string](rt.sysprocs.len())
  for name in rt.sysprocs.keys():
    result.add name

proc rpcPack*(res: RpcParams): RpcParams {.inline.} =
  result = res

proc rpcPack*[T](res: T): RpcParams =
  when defined(nimscript) or defined(useJsonSerde):
    let jn = toJson(res)
    result = RpcParams(buf: jn)
  else:
    result = RpcParams(buf: newVariant(res))

proc rpcUnpack*[T](obj: var T, ss: RpcParams) =
  try:
    when defined(nimscript) or defined(useJsonSerde):
      obj.fromJson(ss.buf)
      discard
    else:
      ss.buf.unpack(obj)
  except ConversionError as err:
    raise newException(ConversionError,
                       "unable to parse parameters: " & err.msg)
  except AssertionDefect as err:
    raise newException(ConversionError,
                       "unable to parse parameters: " & err.msg)

proc initAgentRequest*[T](
  procName: string,
  args: T,
  rkind: AgentType = Request,
  id = AgentId(0),
): AgentRequest =
  # echo "AgentRequest: ", procName, " args: ", args.repr
  result = AgentRequest(
    kind: Request,
    id: AgentId(0),
    procName: procName,
    params: rpcPack(args)
  )

proc getAgentListeners*(obj: Agent,
                        sig: string
                        ): OrderedSet[(Agent, AgentProc)] =
  # echo "FIND:LISTENERS: ", obj.listeners
  if obj.listeners.hasKey(sig):
    result = obj.listeners[sig]

proc addAgentListeners*(obj: Agent,
                        sig: string,
                        tgt: Agent,
                        slot: AgentProc
                        ) =
  # echo "add agent listener: ", sig, " obj: ", obj.agentId, " tgt: ", tgt.agentId
  # if obj.listeners.hasKey(sig):
  #   echo "listener:count: ", obj.listeners[sig].len()
  assert slot != nil
  obj.listeners.
    mgetOrPut(sig, initOrderedSet[(Agent, AgentProc)]()).
    incl((tgt, slot))
  # echo "LISTENERS: ", obj.listeners
