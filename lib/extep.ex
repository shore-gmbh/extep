defmodule Extep do
  @moduledoc """
  A tiny and friendly step runner for Elixir pipelines.

  Extep is a simple and dependency-free utility that helps you compose Elixir pipelines using a shared context.
  It's useful for building multi-step workflows that can gracefully **halt** or **error** along the way.
  Extep is an implementation of the Railway-oriented programming and was inspired by
  [Ecto.Multi](https://hexdocs.pm/ecto/Ecto.Multi.html) and [Sage](https://hexdocs.pm/sage/readme.html).

  ## Example

      iex> params = %{user_id: 1, plan: "super-power-plus"}
      iex> Extep.new(%{params: params})
      ...> |> Extep.run(:params, &validate_params/1)
      ...> |> Extep.run(:user, &fetch_user/1)
      ...> |> Extep.run(:items, &fetch_items/1)
      ...> |> Extep.return(&create_subscription/1)
      {:ok, %{id: 123, object: "subscription", user_id: 1, items: [%{code: "item1"}, %{code: "item2"}]}}
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
  @type opts :: keyword()

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
  Runs a checker function on the context without modifying it.

  This function is useful for validation, checking conditions, or performing side effects
  without changing the pipeline context. The context remains unchanged regardless of the
  function's return value.

  ## Function Return Values

  The checker function must return one of these values:

  - `:ok` - Pipeline continues with unchanged context
  - `{:ok, value}` - Pipeline continues with unchanged context (value is ignored)
  - `{:halt, reason}` - Pipeline stops with `:halted` status, reason stored in message
  - `{:error, reason}` - Pipeline stops with `:error` status, reason stored in message

  ## Error Message Labeling

  When errors occur, the message is stored differently based on the function type:

  - **Named functions**: Error labeled with function name (e.g., `%{validate_user: "error"}`)
  - **Anonymous functions**: Error labeled with `:no_label` (e.g., `%{no_label: "error"}`)

  ## Examples

  ### Successful Validation - Simple OK
  Basic validation that passes without returning a value:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(fn _ctx -> :ok end)
      %Extep{status: :ok, context: %{foo: 1}, message: nil}

  ### Successful Validation - OK tuple
  Validation that passes and returns an ok tuple (value is ignored, context unchanged):

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(fn _ctx -> {:ok, "is valid"} end)
      %Extep{status: :ok, context: %{foo: 1}, message: nil}

  ### Error with Named Function
  When a named function returns an error tuple, the error is labeled with the function name:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(&return_error_tuple/1)
      %Extep{status: :error, context: %{foo: 1}, message: %{return_error_tuple: "error message"}}

  ### Error with Anonymous Function
  When an anonymous function returns an error tuple, the error is labeled with `:no_label`:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(fn _ctx -> {:error, "error message"} end)
      %Extep{status: :error, context: %{foo: 1}, message: %{no_label: "error message"}}

  ### Halt Example
  When a function returns a halt tuple, the pipeline stops and the halt reason is stored:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(fn _ctx -> {:halt, {:ok, "halt message"}} end)
      %Extep{status: :halted, context: %{foo: 1}, message: {:ok, "halt message"}}

  It's useful when you want to stop the pipeline and return a specific message, like a
  cancel tuple for an Oban job, for example:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(fn _ctx -> {:halt, {:cancel, "cancel message"}} end)
      ...> |> Extep.return(fn ctx -> {:ok, ctx.bar + 2} end)
      {:cancel, "cancel message"}

  ## Pipeline Behavior

  - If the Extep struct already has `:halted` or `:error` status, this function does nothing
  - Only processes when the current status is `:ok`
  - The context is never modified by this function
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

  This function executes a mutator function and stores its result in the context under the
  specified key. Unlike `run/2`, this function is designed to modify the context by adding
  or updating values.

  ## Parameters

  - `extep` - The current Extep struct
  - `context_key` - An atom representing the key where the result will be stored
  - `fun` - A function that takes the context and returns a result

  ## Function Return Values

  The mutator function must return one of these values:

  - `{:ok, value}` - Pipeline continues, `value` is stored under `context_key`
  - `{:halt, reason}` - Pipeline stops with `:halted` status, reason stored in message
  - `{:error, reason}` - Pipeline stops with `:error` status, reason stored in message

  **Note**: Unlike `run/2`, this function does NOT accept plain `:ok` returns. It requires
  a tuple with a value to store in the context.

  ## Error Message Labeling

  When errors occur, the message is stored differently based on the function type:

  - **Named functions**: Error labeled with function name (e.g., `%{fetch_user: "error"}`)
  - **Anonymous functions**: Error labeled with the context key (e.g., `%{user: "error"}`)

  ## Examples

  ### Successful Context Updates
  This example shows how values are stored and can be used by subsequent steps:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:foo, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 2} end)
      %Extep{status: :ok, context: %{foo: 2, bar: 4}, message: nil}

  **Explanation**:
  - First `run/3` updates `:foo` from 1 to 2
  - Second `run/3` adds `:bar` with value 4 (using the updated foo value: 2 + 2)
  - Both operations succeed, context now contains both updated values

  ### Error with Named Function - Pipeline Stops
  When a named function returns an error, the pipeline stops and subsequent steps are skipped:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:foo, &return_error_tuple/1)
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 2} end)
      %Extep{status: :error, context: %{foo: 1}, message: %{return_error_tuple: "error message"}}

  **Explanation**:
  - First `run/3` calls `return_error_tuple/1` which returns `{:error, "error message"}`
  - Pipeline status becomes `:error`, original context is preserved
  - Error message is labeled with function name (`return_error_tuple`)
  - Second `run/3` is skipped because pipeline is already in error state

  ### Error with Anonymous Function - Pipeline Stops
  When an anonymous function returns an error, the error is labeled with the context key:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:foo, fn _ctx -> {:error, "error message"} end)
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 2} end)
      %Extep{status: :error, context: %{foo: 1}, message: %{foo: "error message"}}

  **Explanation**:
  - First `run/3` tries to update `:foo` but returns an error
  - Pipeline status becomes `:error`, original context is preserved
  - Error message is labeled with the context key (`:foo`)
  - Second `run/3` is skipped because pipeline is already in error state

  ### Halt with Custom Message - Pipeline Stops
  When a function returns halt, the pipeline stops gracefully with the halt message:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:foo, fn _ctx -> {:halt, {:ok, "halt message"}} end)
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 2} end)
      %Extep{status: :halted, context: %{foo: 1}, message: {:ok, "halt message"}}

  **Explanation**:
  - First `run/3` returns a halt tuple with `{:ok, "halt message"}`
  - Pipeline status becomes `:halted`, original context is preserved
  - Halt message can be any term (here it's `{:ok, "halt message"}`)
  - Second `run/3` is skipped because pipeline is already halted

  ## Pipeline Behavior

  - If the Extep struct already has `:halted` or `:error` status, this function does nothing
  - Only processes when the current status is `:ok`
  - On success, the context is updated with the new value under the specified key
  - On failure or halt, the context remains unchanged
  - Context keys can be new (adding) or existing (updating)
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
  Returns a final result from your pipeline with optional configuration.

  This function extracts the final result from your pipeline based on the pipeline's status:

  - **`:ok` status**: Executes the given function or returns the context value for the given key
  - **`:halted` status**: Returns the halt message (ignores all options)
  - **`:error` status**: Returns an error tuple, optionally with or without context labels

  ## Parameters

  - `extep` - The Extep struct containing your pipeline state
  - `fun_or_key` - Either a function `(context -> result)` or an atom key to extract from context
  - `opts` - Keyword list of options (defaults to `[]`)

  ## Options

  - `label_error` (boolean, default: `false`):
    - When `false`: Returns clean error messages like `{:error, "message"}`
    - When `true`: Returns labeled errors like `{:error, %{fun_name_or_step_name: "message"}}`

  ## Examples

  ### Successful Pipeline with Function
  When the pipeline succeeds, the function is executed with the context:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.return(fn ctx -> {:ok, ctx.bar + 2} end)
      {:ok, 4}

  ### Successful Pipeline with Context Key
  When the pipeline succeeds, the value for the given key is returned:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.run(:baz, fn ctx -> {:ok, ctx.bar + 2} end)
      ...> |> Extep.return(:bar)
      {:ok, 2}

  ### Error Pipeline with Default Behavior (Clean Errors)
  When the pipeline errors and no options are provided, returns clean error messages:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn _ctx -> {:error, "error message"} end)
      ...> |> Extep.return(:foo)
      {:error, "error message"}

  ### Error Pipeline with Function and Labeled Errors
  When `label_error: true` is set and a named function causes the error,
  the error is labeled with the function name:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.return(&return_error_tuple/1, label_error: true)
      {:error, %{return_error_tuple: "error message"}}

  ### Error Pipeline with Anonymous Function and Labeled Errors
  When `label_error: true` is set and an anonymous function causes the error,
  the error is labeled with `:no_label`:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.return(fn _ctx -> {:error, "error message"} end, label_error: true)
      {:error, %{no_label: "error message"}}

  ### Error Pipeline with Context Key and Labeled Errors
  When `label_error: true` is set and a step with a context key caused the error,
  the error is labeled with that step's name:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn _ctx -> {:error, "error message"} end)
      ...> |> Extep.return(:foo, label_error: true)
      {:error, %{bar: "error message"}}

  ### Halted Pipeline Returning Function Result
  When a function in the pipeline halts with a result, that result is returned directly:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.return(fn _ctx -> {:halt, {:ok, "halt message"}} end)
      {:ok, "halt message"}

  ### Halted Pipeline Returning Custom Tuple
  Halt messages can be any term, not just ok tuples:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.return(fn _ctx -> {:halt, {:cancel, "cancel message"}} end)
      {:cancel, "cancel message"}

  ### Previously Halted Pipeline
  When the pipeline was already halted in a previous step, the halt message is returned
  regardless of what you're trying to return:

      iex> Extep.new(%{foo: 1})
      ...> |> Extep.run(:bar, fn ctx -> {:ok, ctx.foo + 1} end)
      ...> |> Extep.run(:baz, fn _ctx -> {:halt, {:ok, "halt message"}} end)
      ...> |> Extep.return(:bar)
      {:ok, "halt message"}
  """
  @spec return(t(), context_mutator_fun() | context_key(), opts()) :: any()
  def return(extep, fun_or_key, opts \\ [])

  def return(%Extep{status: :ok, context: context} = extep, fun, opts) when is_function(fun, 1) do
    case apply(fun, [context]) do
      {:ok, _} = return ->
        return

      return ->
        handle_halt_or_error_return(return, extep, fun, nil)
        |> return_interrupted(opts)
    end
  end

  def return(%Extep{} = extep, fun, opts) when is_function(fun, 1) do
    return_interrupted(extep, opts)
  end

  def return(%Extep{status: :ok, context: context}, context_key, _opts)
      when is_atom(context_key) do
    {:ok, Map.fetch!(context, context_key)}
  end

  def return(%Extep{} = extep, context_key, opts) when is_atom(context_key) do
    return_interrupted(extep, opts)
  end

  defp handle_halt_or_error_return({:halt, message}, extep, _fun, _context_key) do
    %{extep | status: :halted, message: message}
  end

  defp handle_halt_or_error_return({:error, message}, extep, fun, context_key) do
    message_key = handle_message_key(fun, context_key)

    %{extep | status: :error, message: Map.new([{message_key, message}])}
  end

  defp return_interrupted(%Extep{status: :halted, message: message}, _opts), do: message

  defp return_interrupted(%Extep{status: :error, message: message}, opts) do
    case Keyword.get(opts, :label_error, false) do
      true -> {:error, message}
      false -> extract_error_message(message)
    end
  end

  defp extract_error_message(message) when is_map(message) do
    case Map.to_list(message) do
      [{_key, error_message}] -> {:error, error_message}
      _ -> {:error, message}
    end
  end

  defp extract_error_message(message), do: {:error, message}

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

  defp handle_context_key(nil), do: :no_label
  defp handle_context_key(context_key) when is_atom(context_key), do: context_key
end
