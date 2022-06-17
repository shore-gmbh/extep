defmodule Extep do
  alias __MODULE__

  defstruct status: :ok, context: %{}, error: nil

  @type status :: :ok | :halted
  @type context :: map() | struct()
  @type error :: any()
  @type t :: %__MODULE__{status: status, context: context, error: error}

  @spec new :: t()
  def new do
    %Extep{}
  end

  @spec new(map() | struct()) :: t()
  def new(context) when is_map(context) do
    %Extep{context: context}
  end

  @spec run(t(), fun(context())) :: t()
  def run(%Extep{status: :ok, context: context} = extep, fun) when is_function(fun, 1) do
    case apply(fun, [context]) do
      {:error, error} -> %{extep | status: :halted, error: error}
      context when is_map(context) -> %{extep | context: context}
    end
  end

  def run(%Extep{status: :halted} = extep, fun) when is_function(fun, 1) do
    extep
  end

  @spec return(t(), atom()) :: {:ok, any()} | {:error, any()}
  def return(%Extep{status: :ok, context: context}, context_key) when is_atom(context_key) do
    {:ok, Map.fetch!(context, context_key)}
  end

  def return(%Extep{status: :halted, error: error}, context_key) when is_atom(context_key) do
    {:error, error}
  end
end
