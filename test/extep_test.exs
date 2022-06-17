defmodule ExtepTest do
  use ExUnit.Case

  describe "new/" do
    test "returns an `Extep` struct with default values" do
      assert Extep.new() == %Extep{status: :ok, context: %{}, error: nil}
    end
  end

  describe "new/1" do
    test "returns an `Extep` struct with the given context" do
      context = %{key: "value"}

      assert Extep.new(context) == %Extep{status: :ok, context: context, error: nil}
    end
  end

  describe "run/2" do
    test "executes the given function" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn context -> Map.put(context, :key, "new_value") end) == %Extep{
               status: :ok,
               context: %{key: "new_value"},
               error: nil
             }
    end

    test "when the given function returns an error" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> {:error, "message"} end) == %Extep{
               status: :halted,
               context: %{key: "value"},
               error: "message"
             }
    end
  end

  describe "return/2" do
    test "returns the value from the given context key as an `:ok` tuple" do
      context = %{key: "value", another_key: "antother value"}
      extep = %Extep{status: :ok, context: context, error: nil}

      assert Extep.return(extep, :key) == {:ok, "value"}
    end

    test "returns an `:error` tuple when the `%Extep{}` is halted" do
      extep = %Extep{status: :halted, context: %{key: "value"}, error: "message"}

      assert Extep.return(extep, :key) == {:error, "message"}
    end
  end
end
