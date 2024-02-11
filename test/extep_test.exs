defmodule ExtepTest do
  use ExUnit.Case

  describe "new/0" do
    test "returns an `Extep` struct with default values" do
      assert Extep.new() == %Extep{status: :ok, context: %{}, last_step: nil, last_step_idx: nil}
    end
  end

  describe "new/1" do
    test "returns an `Extep` struct with given context" do
      context = %{key: "value"}

      assert Extep.new(context) == %Extep{
               status: :ok,
               context: context,
               last_step: nil,
               last_step_idx: nil
             }
    end
  end

  describe "run/2" do
    test "when function returns `:ok`" do
      extep = %Extep{status: :ok, context: %{}, last_step: nil, last_step_idx: nil}

      assert Extep.run(extep, fn _context -> :ok end) == %Extep{
               status: :ok,
               context: %{0 => :ok},
               last_step: 0,
               last_step_idx: 0
             }
    end

    test "given the `set: :ctx_key` option, sets the return of the function to the given context key" do
      extep = %Extep{status: :ok, context: %{}, last_step: nil, last_step_idx: nil}

      assert Extep.run(extep, fn _context -> :ok end, set: :foo) == %Extep{
               status: :ok,
               context: %{0 => {:set_to, :foo}, :foo => :ok},
               last_step: 0,
               last_step_idx: 0
             }
    end

    test "executes next steps when function returns `:ok`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value"},
        last_step: nil,
        last_step_idx: nil
      }

      extep =
        extep
        |> Extep.run(fn _context -> :ok end)
        |> Extep.run(fn _context -> :ok end)

      assert extep == %Extep{
               status: :ok,
               context: %{:initial => "value", 0 => :ok, 1 => :ok},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "when function returns an `{:ok, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, fn _context -> {:ok, "second"} end) == %Extep{
               status: :ok,
               context: %{:initial => "value", 0 => "first", 1 => "second"},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "executes next steps when function returns an `{:ok, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      extep =
        extep
        |> Extep.run(fn _context -> {:ok, "second"} end)
        |> Extep.run(fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :ok,
               context: %{:initial => "value", 0 => "first", 1 => "second", 2 => "third"},
               last_step: 2,
               last_step_idx: 2
             }
    end

    test "when function returns `:halt`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, fn _context -> :halt end) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", 1 => :halt},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "ignores `set: :ctx_key` option when function returns `:halt`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, fn _context -> :halt end, set: :foo) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", 1 => :halt},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "skips next steps when function returns `:halt`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      extep =
        extep
        |> Extep.run(fn _context -> :halt end)
        |> Extep.run(fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", 1 => :halt},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "when function returns a `{:halt, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, fn _context -> {:halt, "halted in second"} end) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", 1 => "halted in second"},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "skips next steps when function returns a `{:halt, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      extep =
        extep
        |> Extep.run(fn _context -> {:halt, "halted in second"} end)
        |> Extep.run(fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", 1 => "halted in second"},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, fn _context -> :error end) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", 1 => :error},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "ignores `set: :ctx_key` option when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, fn _context -> :error end, set: :foo) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", 1 => :error},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "skips next steps when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      extep =
        extep
        |> Extep.run(fn _context -> :error end)
        |> Extep.run(fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", 1 => :error},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "when function returns a `{:erorr, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, fn _context -> {:error, "error in second"} end) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", 1 => "error in second"},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "skips next steps when function returns a `{:erorr, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      extep =
        extep
        |> Extep.run(fn _context -> {:error, "error in second"} end)
        |> Extep.run(fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", 1 => "error in second"},
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "raises `Extep.InvalidFunctionReturn` when function return is invalid" do
      extep = %Extep{status: :ok, context: %{}, last_step: nil, last_step_idx: nil}

      assert_raise Extep.InvalidFunctionReturn, fn ->
        Extep.run(extep, fn _context -> :invalid_return end)
      end
    end
  end

  describe "run/3" do
    test "when function returns `:ok`" do
      extep = %Extep{status: :ok, context: %{}, last_step: nil, last_step_idx: nil}

      assert Extep.run(extep, :first, fn _context -> :ok end) == %Extep{
               status: :ok,
               context: %{:first => :ok},
               last_step: :first,
               last_step_idx: 0
             }
    end

    test "given the `set: :ctx_key` option, sets the return of the function to the given context key" do
      extep = %Extep{status: :ok, context: %{}, last_step: nil, last_step_idx: nil}

      assert Extep.run(extep, :first, fn _context -> :ok end, set: :foo) == %Extep{
               status: :ok,
               context: %{:first => {:set_to, :foo}, :foo => :ok},
               last_step: :first,
               last_step_idx: 0
             }
    end

    test "when context key is a tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value"},
        last_step: nil,
        last_step_idx: nil
      }

      assert Extep.run(extep, {:second, 1}, fn _context -> :ok end) == %Extep{
               status: :ok,
               context: %{:initial => "value", {:second, 1} => :ok},
               last_step: {:second, 1},
               last_step_idx: 0
             }
    end

    test "executes next steps when function returns `:ok`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value"},
        last_step: nil,
        last_step_idx: nil
      }

      extep =
        extep
        |> Extep.run(:first, fn _context -> :ok end)
        |> Extep.run(:second, fn _context -> :ok end)

      assert extep == %Extep{
               status: :ok,
               context: %{:initial => "value", :first => :ok, :second => :ok},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "when function returns an `:ok` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, :second, fn _context -> {:ok, "second"} end) == %Extep{
               status: :ok,
               context: %{:initial => "value", 0 => "first", :second => "second"},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "executes next steps when function returns an `:ok` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      extep =
        extep
        |> Extep.run(:second, fn _context -> {:ok, "second"} end)
        |> Extep.run(:third, fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :ok,
               context: %{
                 :initial => "value",
                 0 => "first",
                 :second => "second",
                 :third => "third"
               },
               last_step: :third,
               last_step_idx: 2
             }
    end

    test "when function returns `:halt`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, :second, fn _context -> :halt end) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", :second => :halt},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "ignores `set: :ctx_key` option when function returns `:halt`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, :second, fn _context -> :halt end, set: :foo) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", :second => :halt},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "skips next steps when function returns `:halt`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      extep =
        extep
        |> Extep.run(:second, fn _context -> :halt end)
        |> Extep.run(:third, fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", :second => :halt},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "when function returns a `:halt` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, :second, fn _context -> {:halt, "halted in second"} end) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", :second => "halted in second"},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "ignores `set: :ctx_key` option when function returns a `:halt` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, :second, fn _context -> {:halt, "halted in second"} end, set: :foo) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", :second => "halted in second"},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "skips next steps when function returns a `:halt` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      extep =
        extep
        |> Extep.run(:second, fn _context -> {:halt, "halted in second"} end)
        |> Extep.run(:third, fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", :second => "halted in second"},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, :second, fn _context -> :error end) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", :second => :error},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "ignores `set: :ctx_key` option when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, :second, fn _context -> :error end, set: :foo) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", :second => :error},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "skips next steps when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      extep =
        extep
        |> Extep.run(:second, fn _context -> :error end)
        |> Extep.run(:thitd, fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", :second => :error},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "when function returns a `:error` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, :second, fn _context -> {:error, "error in second"} end) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", :second => "error in second"},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "ignores `set: :ctx_key` option when function returns an `{:error, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, :second, fn _context -> {:error, "error in second"} end, set: :foo) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", :second => "error in second"},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "skips next steps when function returns a `:error` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      extep =
        extep
        |> Extep.run(:second, fn _context -> {:error, "error in second"} end)
        |> Extep.run(:third, fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", :second => "error in second"},
               last_step: :second,
               last_step_idx: 1
             }
    end

    test "raises `Extep.InvalidFunctionReturn` when function return is invalid" do
      extep = %Extep{status: :ok, context: %{}, last_step: nil, last_step_idx: nil}

      assert_raise Extep.InvalidFunctionReturn, fn ->
        Extep.run(extep, :first, fn _context -> :invalid_return end)
      end
    end
  end

  describe "return/1" do
    test "returns the value of the last step" do
      extep = %Extep{
        status: :ok,
        context: %{first: "first", second: "second"},
        last_step: :second,
        last_step_idx: 1
      }

      assert Extep.return(extep) == {:ok, "second"}
    end

    test "returns the halted value when `%Extep{}` status is `:halted`" do
      extep = %Extep{
        status: :halted,
        context: %{first: "first", second: "halted in second"},
        last_step: :second,
        last_step_idx: 1
      }

      assert Extep.return(extep) == {:ok, "halted in second"}
    end

    test "returns `:error` atom when the `%Extep{}` status is `:error`" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: :error},
        last_step: :second,
        last_step_idx: 1
      }

      assert Extep.return(extep) == :error
    end

    test "given the `label_error: true` option, returns an error tuple with the step name" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: :error},
        last_step: :second,
        last_step_idx: 1
      }

      assert Extep.return(extep, label_error: true) == {:error, :second}
    end

    test "returns an error tuple when the `%Extep{}` status is `:error`" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: "error in second"},
        last_step: :second,
        last_step_idx: 1
      }

      assert Extep.return(extep) == {:error, "error in second"}
    end

    test "given the `label_error: true` option, returns a labeled error tuple" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: "error in second"},
        last_step: :second,
        last_step_idx: 1
      }

      assert Extep.return(extep, label_error: true) == {:error, %{second: "error in second"}}
    end
  end

  describe "return/2" do
    test "returns the value from context key as an `:ok` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{first: "first", second: "second", third: "third"},
        last_step: :third,
        last_step_idx: 2
      }

      assert Extep.return(extep, :second) == {:ok, "second"}
    end

    test "when context key is a tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:first => "first", {:second, 1} => "second", :third => "third"},
        last_step: :third,
        last_step_idx: 2
      }

      assert Extep.return(extep, {:second, 1}) == {:ok, "second"}
    end

    test "given the `label_error: true` option, returns an error tuple with the step name" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: :error},
        last_step: :second,
        last_step_idx: 1
      }

      assert Extep.return(extep, :third, label_error: true) == {:error, :second}
    end

    test "returns the halted value when `%Extep{}` status is `:halted`" do
      extep = %Extep{
        status: :halted,
        context: %{first: "first", second: "halted in second"},
        last_step: :second,
        last_step_idx: 1
      }

      assert Extep.return(extep, :third) == {:ok, "halted in second"}
    end

    test "returns an error tuple when the `%Extep{}` status is `:error`" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: "error in second"},
        last_step: :second,
        last_step_idx: 1
      }

      assert Extep.return(extep, :third) == {:error, "error in second"}
    end

    test "given the `label_error: true` option, returns a labeled error tuple" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: "error in second"},
        last_step: :second,
        last_step_idx: 1
      }

      assert Extep.return(extep, :third, label_error: true) == {:error, %{second: "error in second"}}
    end
  end
end
