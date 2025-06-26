defmodule Extep do
  alias __MODULE__

  defstruct status: :ok, context: %{}, halted: nil, error: nil

  @type status :: :ok | :halted | :error
  @type context :: map()
  @type t :: %__MODULE__{status: status(), context: context(), halted: any(), error: any()}

  @type context_key :: atom()

  @type halted_return :: :halted | {:halted, any()}
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

  @spec new(Keyword.t()) :: t()
  def new(context) when is_list(context) do
    %Extep{context: Map.new(context)}
  end

  @spec run(t(), context_checker_fun()) :: t()
  def run(%Extep{status: :ok, context: context} = extep, fun) when is_function(fun, 1) do
    case apply(fun, [context]) do
      :ok -> extep
      {:ok, _} -> extep
      return -> handle_fun_return(return, extep)
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
      {:ok, return} ->
        context = Map.put(context, context_key, return)

        %{extep | context: context}

      return ->
        handle_fun_return(return, extep)
    end
  end

  def run(%Extep{status: status} = extep, context_key, fun)
      when status in [:halted, :error] and is_atom(context_key) and is_function(fun, 1) do
    extep
  end

  defp handle_fun_return(:halt, extep), do: %{extep | status: :halted}
  defp handle_fun_return({:halt, halt}, extep), do: %{extep | status: :halted, halted: halt}
  defp handle_fun_return(:error, extep), do: %{extep | status: :error}
  defp handle_fun_return({:error, error}, extep), do: %{extep | status: :error, error: error}

  @spec return(t(), fun() | context_key()) :: any()
  def return(%Extep{status: :ok, context: context}, fun) when is_function(fun, 1) do
    apply(fun, [context])
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

  defp return_interrupted(%Extep{status: :halted, halted: halted}), do: {:ok, halted}
  defp return_interrupted(%Extep{status: :error, error: error}), do: {:error, error}
end
