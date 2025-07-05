defmodule ExtepTest do
  use ExUnit.Case, async: true
  doctest Extep

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

  describe "run/2" do
    test "doesn't modify the context when the given function returns an ok tuple" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, fn _context -> {:ok, "return"} end) == %Extep{
               status: :ok,
               context: %{key: "value"},
               message: nil
             }
    end

    test "doesn't modify the context when the given function returns `:ok`" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, fn _context -> :ok end) == %Extep{
               status: :ok,
               context: %{key: "value"},
               message: nil
             }
    end

    test "doesn't modify the context when the given function returns a halt tuple and updates the message field" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, fn _context -> {:halt, {:ok, "halt message"}} end) == %Extep{
               status: :halted,
               context: %{key: "value"},
               message: {:ok, "halt message"}
             }
    end

    test "doesn't modify context when the given function returns an error tuple and puts the error message
          under a key with the name of the functions when it's a defined module function" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.run(extep, &return_error_tuple/1) == %Extep{
               status: :error,
               context: %{key: "value"},
               message: %{return_error_tuple: "error message"}
             }
    end

    test "doesn't modify context when the given function returns an error tuple and and updates the message field" do
      extep = %Extep{status: :ok, context: %{}, message: nil}

      assert Extep.run(extep, fn _context -> {:error, "error message"} end) == %Extep{
               status: :error,
               context: %{},
               message: %{no_label: "error message"}
             }
    end
  end

  describe "run/3" do
    test "raises when the given function returns ok" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert_raise FunctionClauseError, fn -> Extep.run(extep, :key, fn _context -> :ok end) end
    end

    test "updates an existing context field when the given function returns an ok tuple" do
      extep = %Extep{status: :ok, context: %{existing_key: "value"}, message: nil}

      assert Extep.run(extep, :existing_key, fn _context -> {:ok, "new value"} end) == %Extep{
               status: :ok,
               context: %{existing_key: "new value"},
               message: nil
             }
    end

    test "adds a new context context field when the given function returns an ok tuple" do
      extep = %Extep{status: :ok, context: %{existing_key: "value"}, message: nil}

      assert Extep.run(extep, :new_key, fn _context -> {:ok, "new value"} end) == %Extep{
               status: :ok,
               context: %{existing_key: "value", new_key: "new value"},
               message: nil
             }
    end

    test "doesn't modify context when the given function returns halt tuple" do
      extep = %Extep{status: :ok, context: %{existing_key: "value"}, message: nil}

      assert Extep.run(extep, :existing_key, fn _context -> {:halt, {:ok, "halt message"}} end) ==
               %Extep{
                 status: :halted,
                 context: %{existing_key: "value"},
                 message: {:ok, "halt message"}
               }
    end

    test "doesn't modify context when the given function returns an error tuple and puts the error message
          under a key with the name of the functions when it's a defined module function" do
      extep = %Extep{status: :ok, context: %{}, message: nil}

      assert Extep.run(extep, :new_key, &return_error_tuple/1) == %Extep{
               status: :error,
               context: %{},
               message: %{return_error_tuple: "error message"}
             }
    end

    test "doesn't modify context when the given function returns an error tuple and puts the error message
          under a key with the name of the step when it's anonymous function" do
      extep = %Extep{status: :ok, context: %{}, message: nil}

      assert Extep.run(extep, :new_key, fn _context -> {:error, "error message"} end) == %Extep{
               status: :error,
               context: %{},
               message: %{new_key: "error message"}
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
      extep = %Extep{status: :halted, context: %{key: "value"}, message: {:ok, "halt message"}}

      assert Extep.return(extep, :key) == {:ok, "halt message"}
    end

    test "returns an unlabeled error tuple when the `%Extep{}` status is `:error` (default behavior)" do
      extep = %Extep{
        status: :error,
        context: %{key: "value"},
        message: %{some_key: "error message"}
      }

      assert Extep.return(extep, :key) == {:error, "error message"}
    end
  end

  describe "return/2 for function" do
    test "returns the result of the given function" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.return(extep, fn _context -> {:ok, "new value"} end) == {:ok, "new value"}
    end

    test "returns the halted value when `%Extep{}` status is `:halted`" do
      extep = %Extep{status: :halted, context: %{key: "value"}, message: {:ok, "halt message"}}

      assert Extep.return(extep, fn _context -> {:ok, "new value"} end) == {:ok, "halt message"}
    end

    test "returns an unlabeled error tuple when the `%Extep{}` status is `:error` (default behavior)" do
      extep = %Extep{
        status: :error,
        context: %{key: "value"},
        message: %{some_key: "error message"}
      }

      assert Extep.return(extep, fn _context -> {:ok, "new value"} end) ==
               {:error, "error message"}
    end
  end

  describe "return/3 with label_error option" do
    test "returns unlabeled error by default (label_error defaults to false)" do
      extep = %Extep{
        status: :error,
        context: %{key: "value"},
        message: %{some_key: "error message"}
      }

      assert Extep.return(extep, :key) == {:error, "error message"}
    end

    test "returns unlabeled error when label_error: false (explicit)" do
      extep = %Extep{
        status: :error,
        context: %{key: "value"},
        message: %{some_key: "error message"}
      }

      assert Extep.return(extep, :key, label_error: false) == {:error, "error message"}
    end

    test "returns labeled error when label_error: true" do
      extep = %Extep{
        status: :error,
        context: %{key: "value"},
        message: %{some_key: "error message"}
      }

      assert Extep.return(extep, :key, label_error: true) ==
               {:error, %{some_key: "error message"}}
    end

    test "works with functions when label_error: false" do
      extep = %Extep{
        status: :error,
        context: %{key: "value"},
        message: %{some_key: "error message"}
      }

      assert Extep.return(extep, fn _ctx -> {:ok, "result"} end, label_error: false) ==
               {:error, "error message"}
    end

    test "works with functions when label_error: true" do
      extep = %Extep{
        status: :error,
        context: %{key: "value"},
        message: %{some_key: "error message"}
      }

      assert Extep.return(extep, fn _ctx -> {:ok, "result"} end, label_error: true) ==
               {:error, %{some_key: "error message"}}
    end

    test "returns labeled error when a named function returns an error tuple and label_error: true" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.return(extep, &return_error_tuple/1, label_error: true) ==
               {:error, %{return_error_tuple: "error message"}}
    end

    test "returns labeled error when an anonymous function returns an error tuple and label_error: true" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.return(extep, fn _ctx -> {:error, "error message"} end, label_error: true) ==
               {:error, %{no_label: "error message"}}
    end

    test "halted status ignores label_error option" do
      extep = %Extep{status: :halted, context: %{key: "value"}, message: {:ok, "halt message"}}

      assert Extep.return(extep, :key, label_error: true) == {:ok, "halt message"}
      assert Extep.return(extep, :key, label_error: false) == {:ok, "halt message"}
    end

    test "ok status ignores label_error option and returns context value" do
      extep = %Extep{status: :ok, context: %{key: "value"}, message: nil}

      assert Extep.return(extep, :key, label_error: true) == {:ok, "value"}
      assert Extep.return(extep, :key, label_error: false) == {:ok, "value"}
    end
  end

  # Test helpers

  def return_error_tuple(_ctx), do: {:error, "error message"}

  # Doctests helpers

  def validate_params(ctx), do: {:ok, ctx.params}
  def fetch_user(_ctx), do: {:ok, %{id: 1, name: "Alice"}}
  def fetch_items(_ctx), do: {:ok, [%{code: "item1"}, %{code: "item2"}]}

  def create_subscription(_ctx) do
    {:ok,
     %{id: 123, object: "subscription", user_id: 1, items: [%{code: "item1"}, %{code: "item2"}]}}
  end
end
