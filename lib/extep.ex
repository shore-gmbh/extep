defmodule Extep do
  alias __MODULE__

  defstruct status: :ok, context: %{}, message: nil

  @type status :: :ok | :halted | :error
  @type context :: map()
  @type t :: %__MODULE__{status: status(), context: context(), message: any()}

  @type context_key :: atom()

  @type halted_return :: :halt | {:halt, any()}
  @type error_return :: :error | {:error, any()}
  @type context_checker_fun ::
          (context() -> :ok | {:ok, any()} | halted_return() | error_return())
  @type context_mutator_fun :: (context() -> {:ok, any()} | halted_return() | error_return())

  @spec new :: t()
  def new do
    %Extep{}
  end

  @spec new(map()) :: t()
  def new(context) when is_map(context) do
    %Extep{context: context}
  end

  @spec run(t(), context_checker_fun()) :: t()
  def run(%Extep{status: :ok, context: context} = extep, fun) when is_function(fun, 1) do
    case apply(fun, [context]) do
      :ok -> extep
      {:ok, _} -> extep
      return -> handle_error_or_halt_return(return, extep, fun)
    end
  end

  def run(%Extep{status: status} = extep, fun)
      when status in [:halted, :error] and is_function(fun, 1) do
    extep
  end

  @spec run(t(), context_key(), context_mutator_fun()) :: t()
  def run(%Extep{status: :ok, context: context} = extep, context_key, fun)
      when is_atom(context_key) and is_function(fun, 1) do
    case apply(fun, [context]) do
      {:ok, value} -> %{extep | context: Map.put(context, context_key, value)}
      return -> handle_error_or_halt_return(return, extep, fun)
    end
  end

  def run(%Extep{status: status} = extep, context_key, fun)
      when status in [:halted, :error] and is_atom(context_key) and is_function(fun, 1) do
    extep
  end

  defp handle_error_or_halt_return({:error, message}, extep, fun) do
    fun_name = get_function_name(fun)
    %{extep | status: :error, message: Map.new([{fun_name, message}])}
  end

  defp handle_error_or_halt_return(:error, extep, fun) do
    fun_name = get_function_name(fun)
    %{extep | status: :error, message: Map.new([{fun_name, nil}])}
  end

  defp handle_error_or_halt_return({:halt, message}, extep, _fun) do
    %{extep | status: :halted, message: message}
  end

  defp handle_error_or_halt_return(:halt, extep, _fun) do
    %{extep | status: :halted}
  end

  defp get_function_name(fun) do
    Function.info(fun) |> Keyword.get(:name)
  end

  @spec return(t(), fun() | context_key()) :: any()
  def return(%Extep{status: :ok, context: context} = extep, fun) when is_function(fun, 1) do
    case apply(fun, [context]) do
      {:ok, _} = return ->
        return

      return ->
        handle_error_or_halt_return(return, extep, fun)
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

  defp return_interrupted(%Extep{status: :halted, message: message}), do: {:ok, message}
  defp return_interrupted(%Extep{status: :error, message: message}), do: {:error, message}
end
