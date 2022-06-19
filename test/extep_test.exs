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
    test "when the given function returns ok" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> :ok end) == %Extep{
               status: :ok,
               context: %{key: "value"},
               halted: nil,
               error: nil
             }
    end

    test "doesn't modify the context when the given function returns an ok tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> {:ok, "return"} end) == %Extep{
               status: :ok,
               context: %{key: "value"},
               halted: nil,
               error: nil
             }
    end

    test "when the given function returns halt" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> :halt end) == %Extep{
               status: :halted,
               context: %{key: "value"},
               halted: nil,
               error: nil
             }
    end

    test "when the given function returns a halt tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> {:halt, "message"} end) == %Extep{
               status: :halted,
               context: %{key: "value"},
               halted: "message",
               error: nil
             }
    end

    test "when the given function returns error" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> :error end) == %Extep{
               status: :error,
               context: %{key: "value"},
               halted: nil,
               error: nil
             }
    end

    test "when the given function returns an error tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> {:error, "message"} end) == %Extep{
               status: :error,
               context: %{key: "value"},
               halted: nil,
               error: "message"
             }
    end
  end

  describe "run/3" do
    test "raises when the given function returns ok" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert_raise FunctionClauseError, fn -> Extep.run(extep, fn _context -> :ok end, :key) end
    end

    test "updates the context when the given function returns an ok tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> {:ok, "new value"} end, :key) == %Extep{
               status: :ok,
               context: %{key: "new value"},
               halted: nil,
               error: nil
             }
    end

    test "adds a new value to context when the given function returns an ok tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> {:ok, "another value"} end, :another_key) == %Extep{
               status: :ok,
               context: %{key: "value", another_key: "another value"},
               halted: nil,
               error: nil
             }
    end

    test "doesn't modify context when the given function returns halt" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> :halt end, :key) == %Extep{
               status: :halted,
               context: %{key: "value"},
               halted: nil,
               error: nil
             }
    end

    test "doesn't modify context when the given function returns halt tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> {:halt, "message"} end, :key) == %Extep{
               status: :halted,
               context: %{key: "value"},
               halted: "message",
               error: nil
             }
    end

    test "doesn't modify context when the given function returns error" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> :error end, :key) == %Extep{
               status: :error,
               context: %{key: "value"},
               halted: nil,
               error: nil
             }
    end

    test "doesn't modify context when the given function returns an error tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.run(extep, fn _context -> {:error, "message"} end, :key) == %Extep{
               status: :error,
               context: %{key: "value"},
               halted: nil,
               error: "message"
             }
    end
  end

  describe "return/2 for context key" do
    test "returns the value from the given context key as an ok tuple" do
      context = %{key: "value", another_key: "antother value"}
      extep = %Extep{status: :ok, context: context, error: nil}

      assert Extep.return(extep, :key) == {:ok, "value"}
    end

    test "returns the halted value when `%Extep{}` status is `:halted`" do
      extep = %Extep{status: :halted, context: %{key: "value"}, halted: "message"}

      assert Extep.return(extep, :key) == {:ok, "message"}
    end

    test "returns an error tuple when the `%Extep{}` status is `:error`" do
      extep = %Extep{status: :error, context: %{key: "value"}, error: "message"}

      assert Extep.return(extep, :key) == {:error, "message"}
    end
  end

  describe "return/2 for function" do
    test "returns the result of the given function" do
      extep = %Extep{status: :ok, context: %{key: "value"}, error: nil}

      assert Extep.return(extep, &Map.get(&1, :key)) == "value"
    end

    test "returns the halted value when `%Extep{}` status is `:halted`" do
      extep = %Extep{status: :halted, context: %{key: "value"}, halted: "message"}

      assert Extep.return(extep, &Map.get(&1, :key)) == {:ok, "message"}
    end

    test "returns an error tuple when the `%Extep{}` status is `:error`" do
      extep = %Extep{status: :error, context: %{key: "value"}, error: "message"}

      assert Extep.return(extep, &Map.get(&1, :key)) == {:error, "message"}
    end
  end
end
