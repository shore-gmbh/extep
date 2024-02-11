defmodule Extep do
  defstruct status: :ok, context: %{}, last_step: nil, last_step_idx: nil

  @tag_status_dict %{ok: :ok, halt: :halted, error: :error}

  @type status :: :ok | :halted | :error

  @type context :: map()

  @type t :: %Extep{
          status: status(),
          context: context(),
          last_step: atom(),
          last_step_idx: nil | non_neg_integer()
        }

  @type ctx_key :: atom() | non_neg_integer() | {atom(), non_neg_integer()}

  @type return_tag :: :ok | :halt | :error
  @type return_type :: return_tag() | {return_tag(), any()}
  @type ctx_mod_fun :: (context() -> return_type())

  @type opts :: keyword()

  defguardp is_halted(status) when status in [:halted, :error]

  defguardp is_ctx_key(key) when is_atom(key) or is_integer(key) or is_tuple(key)

  defguardp is_valid_return_tag(tag) when tag in [:ok, :halt, :error]

  @doc """
  Returns an `%Extep{}` struct with empty context.
  """
  @spec new :: t()
  def new, do: %Extep{}

  @doc """
  Returns an `%Extep{}` struct with context.
  """
  @spec new(map()) :: t()
  def new(context) when is_map(context), do: %Extep{context: context}

  @doc """
  Refer to run/3
  """
  @spec run(t(), ctx_mod_fun()) :: t()
  def run(extep, fun), do: run(extep, fun, [])

  @doc """
  Executes the given function and sets its return to an index key in the context.
  """
  @spec run(t(), ctx_mod_fun(), keyword()) :: t()
  def run(%Extep{status: :ok, last_step_idx: idx} = extep, fun, opts) when is_function(fun, 1) do
    run(extep, handle_idx(idx), fun, opts)
  end

  def run(%Extep{status: status} = extep, _fun, _opts) when is_halted(status), do: extep

  @doc """
  Executes the given function and sets its return to the given context key.
  """
  @spec run(t(), ctx_key(), ctx_mod_fun(), keyword()) :: t()
  def run(extep, ctx_key, fun, opts \\ [])

  def run(%Extep{status: :ok, context: context} = extep, ctx_key, fun, opts)
      when is_ctx_key(ctx_key) do
    context
    |> fun.()
    |> update_extep(extep, ctx_key, opts)
  end

  def run(%Extep{status: status} = extep, _ctx_key, _fun, _opts) when is_halted(status), do: extep

  @doc """
  Returns the value of the last step
  """
  @spec return(t()) :: return_type()
  def return(%Extep{} = extep), do: handle_return(extep, extep.last_step, [])

  @spec return(t(), keyword()) :: return_type()
  def return(%Extep{} = extep, opts) when is_list(opts) do
    handle_return(extep, extep.last_step, opts)
  end

  @doc """
  Returns the value of the context key
  """
  @spec return(t(), ctx_key(), keyword()) :: return_type()
  def return(extep, ctx_key, opts \\ [])

  def return(%Extep{status: :ok} = extep, ctx_key, opts) when is_ctx_key(ctx_key) do
    handle_return(extep, ctx_key, opts)
  end

  def return(%Extep{status: status} = extep, _ctx_key, opts) when is_halted(status) do
    handle_return(extep, extep.last_step, opts)
  end

  @spec update_extep({return_tag(), any()}, t(), ctx_key(), keyword()) :: t()
  defp update_extep({tag, value}, %Extep{} = extep, ctx_key, opts)
       when is_valid_return_tag(tag) do
    status = Map.get(@tag_status_dict, tag)

    Map.merge(extep, %{
      status: status,
      context: update_context(extep.context, status, ctx_key, value, opts),
      last_step: ctx_key,
      last_step_idx: handle_idx(extep.last_step_idx)
    })
  end

  @spec update_extep(return_tag(), t(), ctx_key(), keyword()) :: t()
  defp update_extep(tag, %Extep{} = extep, ctx_key, opts) when is_valid_return_tag(tag) do
    update_extep({tag, tag}, extep, ctx_key, opts)
  end

  defp update_extep(_tag, _extep, _ctx_key, _opts), do: raise(Extep.InvalidFunctionReturn)

  defp update_context(context, :ok, ctx_key, value, opts) do
    case Keyword.get(opts, :set, ctx_key) do
      ^ctx_key -> Map.put(context, ctx_key, value)
      set -> context |> Map.put(set, value) |> Map.put(ctx_key, {:set_to, set})
    end
  end

  defp update_context(context, _status, ctx_key, value, _opts) do
    Map.put(context, ctx_key, value)
  end

  @spec handle_return(t(), ctx_key(), opts()) :: return_type()
  defp handle_return(%Extep{status: status, context: context}, ctx_key, opts) do
    case Map.get(context, ctx_key) do
      :ok -> :ok
      :halt -> :ok
      :error -> handle_error(:error, ctx_key, opts)
      step_return when status in [:ok, :halted] -> {:ok, step_return}
      step_return when status == :error -> handle_error(step_return, ctx_key, opts)
    end
  end

  defp handle_idx(nil), do: 0
  defp handle_idx(idx), do: idx + 1

  defp handle_error(:error, ctx_key, opts) do
    if Keyword.get(opts, :label_error, false),
      do: {:error, ctx_key},
      else: :error
  end

  defp handle_error(step_return, ctx_key, opts) do
    if Keyword.get(opts, :label_error, false),
      do: {:error, Map.new([{ctx_key, step_return}])},
      else: {:error, step_return}
  end
end

# TODO:
#   [X] Add `:set` option
#   [X] Add `:label_error` option
#   [ ] Add `:async?` option
