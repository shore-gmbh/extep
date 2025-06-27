defmodule ExtepTest do
  use ExUnit.Case

  describe "new/0" do
    test "returns an `Extep` struct with default values" do
      assert Extep.new() == %Extep{status: :ok, context: %{}, message: nil}
    end
  end

  describe "new/1" do
    test "returns an `Extep` struct when given a Map" do
      context = %{key: "value"}

      assert Extep.new(context) == %Extep{status: :ok, context: context, message: nil}
    end
  end

  describe "run/2 doesn't modify the context" do
    test "when the given function returns an ok tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, fn _context -> {:ok, "return"} end) == %Extep{
               status: :ok,
               context: %{key: "value"},
               message: nil
             }
    end

    test "when the given function returns ok" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, fn _context -> :ok end) == %Extep{
               status: :ok,
               context: %{key: "value"},
               message: nil
             }
    end

    test "when the given function returns halt" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, fn _context -> :halt end) == %Extep{
               status: :halted,
               context: %{key: "value"},
               message: nil
             }
    end

    test "when the given function returns a halt tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, fn _context -> {:halt, "message"} end) == %Extep{
               status: :halted,
               context: %{key: "value"},
               message: "message"
             }
    end

    test "when the given function returns an error atom" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, &return_error_atom/1) == %Extep{
               status: :error,
               context: %{key: "value"},
               message: %{return_error_atom: nil}
             }
    end

    test "when the given function returns an error tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, &return_error_tuple/1) == %Extep{
               status: :error,
               context: %{key: "value"},
               message: %{return_error_tuple: "message"}
             }
    end
  end

  describe "run/3 modifies the context" do
    test "raises when the given function returns ok" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert_raise FunctionClauseError, fn -> Extep.run(extep, :key, fn _context -> :ok end) end
    end

    test "updates the context when the given function returns an ok tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, :key, fn _context -> {:ok, "new value"} end) == %Extep{
               status: :ok,
               context: %{key: "new value"},
               message: nil
             }
    end

    test "adds a new value to context when the given function returns an ok tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, :another_key, fn _context -> {:ok, "another value"} end) == %Extep{
               status: :ok,
               context: %{key: "value", another_key: "another value"},
               message: nil
             }
    end

    test "doesn't modify context when the given function returns halt" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, :key, fn _context -> :halt end) == %Extep{
               status: :halted,
               context: %{key: "value"},
               message: nil
             }
    end

    test "doesn't modify context when the given function returns halt tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, :key, fn _context -> {:halt, "message"} end) == %Extep{
               status: :halted,
               context: %{key: "value"},
               message: "message"
             }
    end

    test "doesn't modify context when the given function returns an error atom" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, :key, &return_error_atom/1) == %Extep{
               status: :error,
               context: %{key: "value"},
               message: %{return_error_atom: nil}
             }
    end

    test "doesn't modify context when the given function returns an error tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, :key, &return_error_tuple/1) == %Extep{
               status: :error,
               context: %{key: "value"},
               message: %{return_error_tuple: "message"}
             }
    end
  end

  describe "return/2 for context key" do
    test "returns the value from the given context key as an ok tuple" do
      context = %{key: "value", another_key: "antother value"}
      extep = %Extep{status: :ok, context: context, message: nil}

      assert Extep.return(extep, :key) == {:ok, "value"}
    end

    test "returns the halted value when `%Extep{}` status is `:halted`" do
      extep = %Extep{status: :halted, context: %{key: "value"}, message: "message"}

      assert Extep.return(extep, :key) == {:ok, "message"}
    end

    test "returns an error tuple when the `%Extep{}` status is `:error`" do
      extep = %Extep{status: :error, context: %{key: "value"}, message: "message"}

      assert Extep.return(extep, :key) == {:error, "message"}
    end
  end

  describe "return/2 for function" do
    test "returns the result of the given function" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.return(extep, fn _context -> {:ok, "new value"} end) == {:ok, "new value"}
    end

    test "returns the halted value when `%Extep{}` status is `:halted`" do
      extep = %Extep{status: :halted, context: %{key: "value"}, message: "message"}

      assert Extep.return(extep, fn _context -> {:ok, "new value"} end) == {:ok, "message"}
    end

    test "returns an error tuple when the `%Extep{}` status is `:error`" do
      extep = %Extep{status: :error, context: %{key: "value"}, message: "message"}

      assert Extep.return(extep, fn _context -> {:ok, "new value"} end) == {:error, "message"}
    end
  end

  def return_error_atom(_ctx), do: :error
  def return_error_tuple(_ctx), do: {:error, "message"}
end
