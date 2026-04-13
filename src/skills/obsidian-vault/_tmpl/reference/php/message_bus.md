# PHP MESSAGE BUS

## MUST

- Before any work involving the message bus (dispatching commands/events/queries, writing handlers/listeners, writing bus-related tests),
  read `vendor/get-e/message-bus/README.ai.md` in full

## Handler Integration Tests

- Must dispatch messages through the actual `get-e/message-bus` — never instantiate handlers directly
- Use `GetE\MessageBus\Support\Laravel\Test\MessageBusTestCaseTrait` and `QueueTestCaseTrait`:
    - **Command handlers**: `dispatchCommandAsync($command)`, process with `runQueueWorker($queueName)`, assert with `assertDispatched()`
    - **Event listeners**: `dispatchEvent($event, ListenerClass::class)`, assert with `assertDispatched()`
    - **Query handlers**: `dispatchQuery($query)`, assert returned read model
- Nested messages (dispatched by handler under test) are logged but not executed — assert with `assertDispatched()`, `assertDispatchedAsync()`, `assertNotDispatched()`
- Use `\GetE\MessageBus\Port\Context\MessageBusContext` when a `Context` implementation is needed in tests
