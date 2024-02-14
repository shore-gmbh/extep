defmodule Extep do
  defstruct status: :ok,
            context: %{},
            last_step: nil,
            last_step_idx: nil,
            halted_at_step: nil,
            async_steps: []

  @tag_status_dict %{ok: :ok, halt: :halted, error: :error}

  @type status :: :ok | :halted | :error
  @type context :: map()

  @type t :: %Extep{
          status: status(),
          context: context(),
          last_step: any(),
          last_step_idx: nil | non_neg_integer(),
          halted_at_step: any(),
          async_steps: list(Task.t())
        }

  @type ctx_key :: atom() | non_neg_integer() | {atom(), non_neg_integer()}

  @type return_tag :: :ok | :halt | :error
  @type ctx_mod_fun_return_type :: return_tag() | {return_tag(), any()}
  @type ctx_mod_fun :: (context() -> ctx_mod_fun_return_type())

  @type opts :: keyword()

  defguardp is_halted(status) when status in [:halted, :error]

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
  Executes the given function and sets its result to an index key in the context.
  """
  @spec run(t(), ctx_mod_fun(), keyword()) :: t()
  def run(%Extep{status: :ok, last_step_idx: idx} = extep, fun, opts) when is_function(fun, 1) do
    run(extep, handle_idx(idx), fun, opts)
  end

  def run(%Extep{status: status} = extep, _fun, _opts) when is_halted(status), do: extep

  @doc """
  Executes the given function and sets its result to the given context key.
  """
  @spec run(t(), ctx_key(), ctx_mod_fun(), keyword()) :: t()
  def run(extep, ctx_key, fun, opts \\ [])

  def run(%Extep{status: :ok} = extep, ctx_key, fun, opts) do
    if Keyword.get(opts, :async, false),
      do: run_async(extep, ctx_key, fun, opts),
      else: run_sync(extep, ctx_key, fun, opts)
  end

  def run(%Extep{status: status} = extep, _ctx_key, _fun, _opts) when is_halted(status), do: extep

  @doc """
  Returns the value of the last step.
  """
  @spec return(t()) :: ctx_mod_fun_return_type()
  def return(%Extep{status: :ok} = extep) do
    handle_return(extep, extep.last_step, [])
  end

  def return(%Extep{status: status} = extep) when is_halted(status) do
    handle_return(extep, extep.halted_at_step, [])
  end

  @spec return(t(), keyword()) :: ctx_mod_fun_return_type()
  def return(%Extep{status: :ok} = extep, opts) when is_list(opts) do
    handle_return(extep, extep.last_step, opts)
  end

  def return(%Extep{status: status} = extep, opts) when is_list(opts) and is_halted(status) do
    handle_return(extep, extep.halted_at_step, opts)
  end

  @doc """
  Returns the value of the context key.
  """
  @spec return(t(), ctx_key(), keyword()) :: ctx_mod_fun_return_type()
  def return(extep, ctx_key, opts \\ [])

  def return(%Extep{status: :ok} = extep, ctx_key, opts) do
    handle_return(extep, ctx_key, opts)
  end

  def return(%Extep{status: status} = extep, _ctx_key, opts) when is_halted(status) do
    handle_return(extep, extep.halted_at_step, opts)
  end

  defp run_async(extep, ctx_key, fun, opts) do
    async_step =
      Task.async(fn ->
        step_result = fun.(extep.context)
        %{ctx_key: ctx_key, step_result: step_result, opts: opts}
      end)

    extep
    |> Map.put(:async_steps, [async_step | extep.async_steps])
    |> put_last_step(ctx_key)
  end

  defp run_sync(%Extep{status: :ok, async_steps: []} = extep, ctx_key, fun, opts) do
    step_result = fun.(extep.context)

    extep
    |> put_context(step_result, ctx_key, opts)
    |> put_halted_at_step(step_result, ctx_key)
    |> put_status(step_result)
    |> put_last_step(ctx_key)
  end

  defp run_sync(%Extep{status: :ok} = extep, ctx_key, fun, opts) do
    extep
    |> await_async_steps()
    |> run_sync(ctx_key, fun, opts)
  end

  defp run_sync(%Extep{status: status} = extep, _ctx_key, _fun, _opts) when is_halted(status) do
    extep
  end

  defp await_async_steps(extep) do
    extep.async_steps
    |> Task.await_many()
    |> Enum.reduce(extep, fn %{ctx_key: ctx_key, step_result: step_result, opts: opts}, acc ->
      acc
      |> put_context(step_result, ctx_key, opts)
      |> put_halted_at_step(step_result, ctx_key)
      |> put_status(step_result)
    end)
    |> Map.put(:async_steps, [])
  end

  defp put_context(%Extep{} = extep, step_result, ctx_key, opts) do
    status = fetch_status!(step_result)
    result = fetch_result!(step_result)

    %{extep | context: update_context(extep.context, status, ctx_key, result, opts)}
  end

  defp put_status(%Extep{status: :ok} = extep, step_result) do
    %{extep | status: fetch_status!(step_result)}
  end

  defp put_status(%Extep{status: status} = extep, _step_result) when is_halted(status), do: extep

  defp put_halted_at_step(%Extep{status: :ok} = extep, step_result, ctx_key) do
    case fetch_status!(step_result) do
      :ok -> extep
      _ -> %{extep | halted_at_step: ctx_key}
    end
  end

  defp put_halted_at_step(%Extep{status: status} = extep, _step_result, _ctx_key)
       when is_halted(status) do
    extep
  end

  @spec fetch_status!(ctx_mod_fun_return_type()) :: status()
  defp fetch_status!({tag, _result}), do: fetch_status!(tag)

  defp fetch_status!(tag) do
    Map.fetch!(@tag_status_dict, tag)
  rescue
    KeyError -> raise(Extep.InvalidFunctionReturn)
  end

  @spec fetch_result!(ctx_mod_fun_return_type()) :: any()
  defp fetch_result!({tag, result}) do
    fetch_status!(tag)
    result
  end

  defp fetch_result!(tag), do: fetch_result!({tag, tag})

  defp put_last_step(%Extep{} = extep, ctx_key) do
    %{
      extep
      | last_step: ctx_key,
        last_step_idx: handle_idx(extep.last_step_idx)
    }
  end

  defp update_context(context, :ok, ctx_key, result, opts) do
    case Keyword.get(opts, :set, ctx_key) do
      ^ctx_key -> Map.put(context, ctx_key, result)
      set -> context |> Map.put(set, result) |> Map.put(ctx_key, {:set_to, set})
    end
  end

  defp update_context(context, _status, ctx_key, result, _opts) do
    Map.put(context, ctx_key, result)
  end

  @spec handle_return(t(), ctx_key(), opts()) :: ctx_mod_fun_return_type()
  defp handle_return(%Extep{status: :ok, async_steps: []} = extep, ctx_key, _opts) do
    case Map.get(extep.context, ctx_key) do
      :ok -> :ok
      step_return -> {:ok, step_return}
    end
  end

  defp handle_return(%Extep{status: status, async_steps: []} = extep, _ctx_key, opts)
       when is_halted(status) do
    case Map.get(extep.context, extep.halted_at_step) do
      :halt ->
        :ok

      step_return when extep.status == :error ->
        handle_error(step_return, extep.halted_at_step, opts)

      step_return when extep.status == :halted ->
        {:ok, step_return}
    end
  end

  defp handle_return(extep, ctx_key, opts) do
    extep
    |> await_async_steps()
    |> handle_return(ctx_key, opts)
  end

  defp handle_idx(nil), do: 0
  defp handle_idx(idx), do: idx + 1

  defp handle_error(:error, ctx_key, opts) do
    if Keyword.get(opts, :label_error, false),
      do: {:error, Map.new([{ctx_key, :error}])},
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
#   [x] Add `:async` option
#   [ ] Add Task supervisor
