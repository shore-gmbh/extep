# Extep

![**Extep**](https://raw.githubusercontent.com/shore-gmbh/extep/main/Extep.png)

**A tiny and friendly step runner for Elixir pipelines.**

Extep is a simple and dependency-free utility that helps you compose Elixir pipelines using a shared context. It's useful for building multi-step workflows that can gracefully **halt** or **error** along the way. Extep is an implementation of the Railway-oriented programming and was inspired by [Ecto.Multi](https://hexdocs.pm/ecto/Ecto.Multi.html) and [Sage](https://hexdocs.pm/sage/readme.html).

## Installation

Add `extep` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:extep, "~> 0.1.0"}
  ]
end
```

The full documentation can be found at https://hexdocs.pm/extep.

## Basic Usage

Each step is a function that either checks something or returns a value to be added to the context.

```elixir
params = %{user_id: 1, plan: "super-power-plus"}

Extep.new(%{params: params})
|> Extep.run(:params, &validate_params/1)
|> Extep.run(:user, &fetch_user/1)
|> Extep.run(:items, &fetch_items/1)
|> Extep.return(&create_subscription/1)
#=> {:ok, %{id: 123, object: "subscription", user_id: 1, items: [%{code: "item1"}, %{code: "item2"}]}}

def validate_params(%{params: %{user_id: _id}} = ctx), do: {:ok, ctx.params}

def fetch_user(%{params: %{user_id: id}}), do: {:ok, %{id: id, name: "Alice"}}

def fetch_items(_ctx), do: {:ok, [%{code: "item1"}, %{code: "item2"}]}

def create_subscription(%{user: user, items: items}) do
  {:ok, %{id: 123, object: "subscription", user_id: user.id, items: items}}
end
```

## API

### `Extep.new/0`

Creates a new, empty Extep struct:

```elixir
Extep.new()
#=> %Extep{status: :ok, context: %{}, message: nil}
```

### `Extep.new/1`

Creates a new Extep struct with a given context map:

```elixir
Extep.new(%{foo: "bar"})
#=> %Extep{status: :ok, context: %{foo: "bar"}, message: nil}
```

### `Extep.run/2`

Runs a checker function that must return one of the following:

- `:ok` continues the pipeline;
- `{:ok, value}` continues the pipeline;
- `{:halt, reason}` halts pipeline, stores `reason` in `:message`;
- `{:error, reason}` errors out, stores `reason` in `:message`.

```elixir
Extep.new(%{foo: 1})
|> Extep.run(&check_something/1)
#=> %Extep{status: :ok, context: %{foo: 1}, message: nil}
```

### `Extep.run/3`

Runs a mutator function and stores the result under the given key. It must return one of the following:

- `{:ok, value}` continues the pipeline, saves `value` under the given key;
- `{:halt, reason}` halts pipeline, stores `reason` in `:message`;
- `{:error, reason}` errors out, stores `reason` in `:message`.

```elixir
Extep.new(%{foo: 1})
|> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
#=> %Extep{status: :ok, context: %{foo: 1, bar: 2}, message: nil}
```

### `Extep.return/3`

Returns a final result from the pipeline:

- With a function:

```elixir
Extep.new(%{foo: 1})
|> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
|> Extep.return(fn ctx -> {:ok, ctx.bar + 2} end)
#=> {:ok, 4}
```

- With a context key:

```elixir
Extep.new(%{foo: 1})
|> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
|> Extep.run(:baz, fn ctx -> {:ok, ctx.bar + 2} end)
|> Extep.return(:bar)
#=> {:ok, 2}
```

## Error Messages

If a step fails or halts, Extep stores the reason in the `:message` field. For functions passed to `run/3`, the key is the same as the context key. For anonymous functions in `run/2`, the key is `:no_label`.

### Error Labeling with `label_error`

By default, `Extep.return/3` returns clean error messages. You can control error formatting using the `label_error` option:

```elixir
# Default behavior - clean error messages
Extep.new(%{foo: 1})
|> Extep.run(:user, fn _ctx -> {:error, "User not found"} end)
|> Extep.return(:foo)
#=> {:error, "User not found"}

# Named function return_error_tuple/1 example
Extep.new(%{foo: 1})
|> Extep.run(:user, &return_error_tuple/1)
|> Extep.return(:foo, label_error: true)
#=> {:error, %{return_error_tuple: "error message"}}

# With label_error: true - labeled error messages
Extep.new(%{foo: 1})
|> Extep.run(:user, fn _ctx -> {:error, "User not found"} end)
|> Extep.return(:foo, label_error: true)
#=> {:error, %{user: "User not found"}}
```

Labeled errors help you identify which step caused the failure, which is useful for debugging complex pipelines.

## License

MIT © [Shore GmbH]
