defmodule Extep do
  @moduledoc """
  A tiny, friendly step runner for managing pipeline-style operations
  where you can halt or error out at any point.

  `Extep` helps you chain together multiple mutations and checks on a shared context map.
  Each step can decide to continue, halt, or error, and you can inspect the result at the end.

  ## Example

      iex> params = %{user_id: 1, plan: "super-power-plus"}
      iex> Extep.new(%{params: params})
      ...> |> Extep.run(:params, &validate_params/1)
      ...> |> Extep.run(:user, &fetch_user/1)
      ...> |> Extep.run(:items, &fetch_items/1)
      ...> |> Extep.return(&create_subscription/1)
      {:ok, %{id: 123, object: "subscription"}}
  """

  alias __MODULE__

  defstruct status: :ok, context: %{}, message: nil

  @type status :: :ok | :halted | :error
  @type context :: map()
  @type t :: %__MODULE__{status: status(), context: context(), message: any()}

  @type context_key :: atom()
  @type context_checker_fun :: (context() ->
                                  :ok | {:ok, any()} | {:halt, any()} | {:error, any()})
  @type context_mutator_fun :: (context() -> {:ok, any()} | {:halt, any()} | {:error, any()})

  @doc """
  Creates a new `Extep` struct with an empty context.

  ## Examples

      iex> Extep.new()
      %Extep{status: :ok, context: %{}, message: nil}
  """
  @spec new :: t()
  def new do
    %Extep{}
  end

  @doc """
  Creates a new `Extep` struct with an initial context map.

  ## Examples

      iex> Extep.new(%{foo: "bar"})
      %Extep{status: :ok, context: %{foo: "bar"}, message: nil}
  """
  @spec new(map()) :: t()
  def new(context) when is_map(context) do
    %Extep{context: context}
  end

  @doc """
  Runs a checker function on the context. This version of `run/2` doesn't change
  the context, it just checks something.

  If the function returns `:ok` or `{:ok, "value"}`, the pipeline continues.
  If it returns `{:halt, "reason"}` or `{:error, "reason"}`, the pipeline stops and saves
  the reason in the `:message` field of the Extep struct.

  ## Examples

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(fn _ctx -> :ok end)
      %Extep{status: :ok, context: %{foo: 1}, message: nil}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(fn _ctx -> {:ok, "is valid"} end)
      %Extep{status: :ok, context: %{foo: 1}, message: nil}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(&return_error_tuple/1)
      %Extep{status: :error, context: %{foo: 1}, message: %{return_error_tuple: "error message"}}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(fn _ctx -> {:error, "error message"} end)
      %Extep{status: :error, context: %{foo: 1}, message: %{no_context_key: "error message"}}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:foo, fn _ctx -> {:halt, "halt message"} end)
      %Extep{status: :halted, context: %{foo: 1}, message: "halt message"}
  """
  @spec run(t(), context_checker_fun()) :: t()
  def run(%Extep{status: :ok, context: context} = extep, fun) when is_function(fun, 1) do
    case apply(fun, [context]) do
      :ok -> extep
      {:ok, _} -> extep
      return -> handle_halt_or_error_return(return, extep, fun, nil)
    end
  end

  def run(%Extep{status: status} = extep, fun)
      when status in [:halted, :error] and is_function(fun, 1) do
    extep
  end

  @doc """
  Runs a mutator function that updates the context with the result under the given key.

  If the function returns `{:ok, "value"}`, "value" is set to the given key and the
  pipeline continues.
  If it returns `{:halt, "reason"}` or `{:error, "reason"}`, the pipeline stops and saves
  the reason in the `:message` field of the Extep struct.

  ## Examples

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:foo, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 2} end)
      %Extep{status: :ok, context: %{foo: 2, bar: 4}, message: nil}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:foo, &return_error_tuple/1)
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 2} end)
      %Extep{status: :error, context: %{foo: 1}, message: %{return_error_tuple: "error message"}}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:foo, fn _ctx -> {:error, "error message"} end)
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 2} end)
      %Extep{status: :error, context: %{foo: 1}, message: %{foo: "error message"}}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:foo, fn _ctx -> {:halt, "halt message"} end)
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 2} end)
      %Extep{status: :halted, context: %{foo: 1}, message: "halt message"}
  """
  @spec run(t(), context_key(), context_mutator_fun()) :: t()
  def run(%Extep{status: :ok, context: context} = extep, context_key, fun)
      when is_atom(context_key) and is_function(fun, 1) do
    case apply(fun, [context]) do
      {:ok, value} -> %{extep | context: Map.put(context, context_key, value)}
      return -> handle_halt_or_error_return(return, extep, fun, context_key)
    end
  end

  def run(%Extep{status: status} = extep, context_key, fun)
      when status in [:halted, :error] and is_atom(context_key) and is_function(fun, 1) do
    extep
  end

  @doc """
  Returns a final result from your pipeline.

  If your `Extep` status is `:ok` and you pass a function, it calls the function
  with the context and returns whatever it returns. If you pass a context key,
  it fetches the value for that key and returns it in an ok tuple.

  If the pipeline was halted, it returns `{:ok, message}`.
  If the pipeline errored, it returns `{:error, message}`.

  ## Examples

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.run(:baz, fn ctx -> {:ok, ctx.bar + 2} end)
      ...> |> Extep.return(:bar)
      {:ok, 2}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.return(fn ctx -> {:ok, ctx.bar + 2} end)
      {:ok, 4}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, &return_error_tuple/1)
      ...> |> Extep.return(:bar)
      {:error, %{return_error_tuple: "error message"}}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn _ctx -> {:error, "error message"} end)
      ...> |> Extep.return(:bar)
      {:error, %{bar: "error message"}}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.run(:baz, fn _ctx -> {:halt, "halt message"} end)
      ...> |> Extep.return(:bar)
      {:ok, "halt message"}

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.return(fn _ctx -> {:halt, "halt message"} end)
      {:ok, "halt message"}
  """
  @spec return(t(), context_mutator_fun() | context_key()) :: any()
  def return(%Extep{status: :ok, context: context} = extep, fun) when is_function(fun, 1) do
    case apply(fun, [context]) do
      {:ok, _} = return ->
        return

      return ->
        handle_halt_or_error_return(return, extep, fun, nil)
        |> return_interrupted()
    end
  end

  def return(%Extep{} = extep, fun) when is_function(fun, 1) do
    return_interrupted(extep)
  end

  def return(%Extep{status: :ok, context: context}, context_key) when is_atom(context_key) do
    {:ok, Map.fetch!(context, context_key)}
  end

  def return(%Extep{} = extep, context_key) when is_atom(context_key) do
    return_interrupted(extep)
  end

  defp handle_halt_or_error_return({:halt, message}, extep, _fun, _context_key) do
    %{extep | status: :halted, message: message}
  end

  defp handle_halt_or_error_return({:error, message}, extep, fun, context_key) do
    message_key = handle_message_key(fun, context_key)

    %{extep | status: :error, message: Map.new([{message_key, message}])}
  end

  defp return_interrupted(%Extep{status: :halted, message: message}), do: {:ok, message}
  defp return_interrupted(%Extep{status: :error, message: message}), do: {:error, message}

  defp handle_message_key(fun, context_key) when is_function(fun) do
    info = Function.info(fun)
    type = Keyword.fetch!(info, :type)
    env = Keyword.fetch!(info, :env)
    name = Keyword.fetch!(info, :name)
    context_key = handle_context_key(context_key)

    cond do
      type == :external ->
        name

      type == :local and is_atom(name) and String.contains?(Atom.to_string(name), "-fun-") ->
        context_key

      type == :local and env != [] ->
        context_key

      true ->
        name
    end
  end

  defp handle_context_key(nil), do: :no_context_key
  defp handle_context_key(context_key) when is_atom(context_key), do: context_key
end
