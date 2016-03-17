# Adz /_&#1237;dz_/

1. Noun: A woodworking tool used for smoothing or carving timbers.
1. Noun: A formatting library for Elixir's Logger.

Adz's primary contribution is transparently adding module name and line number to Elixir's Logger output. It can also format logs as valid JSON or plain text.

## Getting adz

Add `adz` to the `deps` section of `mix.exs`:

`{:adz, github: "operable/adz"}`

## Configuring adz output

### JSON

```elixir
config :logger, :console,
  metadata: [:module, :line],
  format: {Adz, :json}
```

Example output (line breaks and indentation added for readability):

```
{"timestamp":"2016-02-22T13:36:32.0838",
 "source":"Cog.Command.RuleCache",
 "message":"Ready. Command rule cache TTL is 10 seconds.",
 "line":33,
 "level":"info"}
```

### Text

```elixir
config :logger, :console,
  metadata: [:module, :line],
  format: {Adz, :text}
```

Example output:

```
2016-02-22T13:36:32.0838  (Cog.Command.RuleCache:33) [info] Ready. Command rule cache TTL is 10 seconds.
```

## Filing Issues

Adz issues are tracked centrally in [Cog's](https://github.com/operable/cog/issues) issue tracker.
