defmodule Extep do
  alias __MODULE__

  defstruct status: :ok, context: %{}, error: nil

  @type status :: :ok | :halted
  @type context :: map()
  @type error :: any()
  @type context_key :: atom()
  @type context_checker_fun :: (context() -> :ok | {:ok, any()} | error())
  @type context_mutator_fun :: (context() -> {:ok, any()} | error())
  @type t :: %__MODULE__{status: status, context: context, error: error}

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
      {:error, error} -> %{extep | status: :halted, error: error}
    end
  end

  def run(%Extep{status: :halted} = extep, fun) when is_function(fun, 1), do: extep

  @spec run(t(), context_mutator_fun(), context_key()) :: t()
  def run(%Extep{status: :ok, context: context} = extep, fun, context_key)
      when is_function(fun, 1) and is_atom(context_key) do
    case apply(fun, [context]) do
      {:ok, return} ->
        context = Map.put(context, context_key, return)

        %{extep | context: context}

      {:error, error} ->
        %{extep | status: :halted, error: error}
    end
  end

  def run(%Extep{status: :halted} = extep, fun, context_key)
      when is_function(fun, 1) and is_atom(context_key) do
    extep
  end

  @spec return(t(), context_key()) :: {:ok, any()} | {:error, any()}
  def return(%Extep{status: :ok, context: context}, context_key) when is_atom(context_key) do
    {:ok, Map.fetch!(context, context_key)}
  end

  def return(%Extep{status: :halted, error: error}, context_key) when is_atom(context_key) do
    {:error, error}
  end
end
