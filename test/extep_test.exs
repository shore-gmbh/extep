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

  describe "run/3" do
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

    test "given the `set: :ctx_key` option, sets function return to the given context key" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, fn _context -> {:ok, "second"} end, set: :foo) == %Extep{
               status: :ok,
               context: %{
                 :initial => "value",
                 0 => "first",
                 1 => {:set_to, :foo},
                 :foo => "second"
               },
               last_step: 1,
               last_step_idx: 1
             }
    end

    test "executes next steps when function returns an `{:ok, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      extep =
        extep
        |> Extep.run(fn _context -> {:ok, "second"} end)
        |> Extep.run(fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :ok,
               context: %{:initial => "value", 0 => "first", 1 => "second", 2 => "third"},
               last_step: 2,
               last_step_idx: 2,
               halted_at_step: nil
             }
    end

    test "when function returns `:halt`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, fn _context -> :halt end) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", 1 => :halt},
               last_step: 1,
               last_step_idx: 1,
               halted_at_step: 1
             }
    end

    test "ignores `set: :ctx_key` option when function returns `:halt`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, fn _context -> :halt end, set: :foo) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", 1 => :halt},
               last_step: 1,
               last_step_idx: 1,
               halted_at_step: 1
             }
    end

    test "skips next steps when function returns `:halt`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      extep =
        extep
        |> Extep.run(fn _context -> :halt end)
        |> Extep.run(fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", 1 => :halt},
               last_step: 1,
               last_step_idx: 1,
               halted_at_step: 1
             }
    end

    test "when function returns a `{:halt, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, fn _context -> {:halt, "halted in second"} end) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", 1 => "halted in second"},
               last_step: 1,
               last_step_idx: 1,
               halted_at_step: 1
             }
    end

    test "skips next steps when function returns a `{:halt, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      extep =
        extep
        |> Extep.run(fn _context -> {:halt, "halted in second"} end)
        |> Extep.run(fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", 1 => "halted in second"},
               last_step: 1,
               last_step_idx: 1,
               halted_at_step: 1
             }
    end

    test "when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, fn _context -> :error end) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", 1 => :error},
               last_step: 1,
               last_step_idx: 1,
               halted_at_step: 1
             }
    end

    test "ignores `set: :ctx_key` option when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, fn _context -> :error end, set: :foo) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", 1 => :error},
               last_step: 1,
               last_step_idx: 1,
               halted_at_step: 1
             }
    end

    test "skips next steps when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      extep =
        extep
        |> Extep.run(fn _context -> :error end)
        |> Extep.run(fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", 1 => :error},
               last_step: 1,
               last_step_idx: 1,
               halted_at_step: 1
             }
    end

    test "when function returns a `{:erorr, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, fn _context -> {:error, "error in second"} end) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", 1 => "error in second"},
               last_step: 1,
               last_step_idx: 1,
               halted_at_step: 1
             }
    end

    test "skips next steps when function returns a `{:erorr, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      extep =
        extep
        |> Extep.run(fn _context -> {:error, "error in second"} end)
        |> Extep.run(fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", 1 => "error in second"},
               last_step: 1,
               last_step_idx: 1,
               halted_at_step: 1
             }
    end

    test "raises `Extep.InvalidFunctionReturn` when function return is invalid" do
      extep = %Extep{status: :ok, context: %{}, last_step: nil, last_step_idx: nil}

      assert_raise Extep.InvalidFunctionReturn, fn ->
        Extep.run(extep, fn _context -> :invalid_return end)
      end
    end
  end

  describe "run/3 with `async: true` option" do
    test "sets an async step to the `async_steps` key" do
      extep = %Extep{}

      assert %Extep{
               status: :ok,
               context: %{},
               last_step: 0,
               last_step_idx: 0,
               halted_at_step: nil,
               async_steps: [%Task{}]
             } = Extep.run(extep, fn _context -> :ok end, async: true)
    end

    test "await and clear async_steps in the next sync step" do
      extep = %Extep{}

      extep =
        extep
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.run(fn _context -> :ok end)

      assert %Extep{
               status: :ok,
               context: %{0 => :ok, 1 => :ok, 2 => :ok},
               last_step: 2,
               last_step_idx: 2,
               async_steps: []
             } = extep
    end

    test "sets the halted_at_step for an async step `:error`" do
      extep = %Extep{}

      extep =
        extep
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.run(fn _context -> :error end, async: true)
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.run(fn _context -> :ok end)

      assert %Extep{
               status: :error,
               context: %{0 => :ok, 1 => :error, 2 => :ok},
               last_step: 2,
               last_step_idx: 2,
               halted_at_step: 1,
               async_steps: []
             } = extep
    end

    test "sets the halted_at_step for an async step `{:error, _}` tuple" do
      extep = %Extep{}

      extep =
        extep
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.run(fn _context -> {:error, "error in second"} end, async: true)
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.run(fn _context -> :ok end)

      assert %Extep{
               status: :error,
               context: %{0 => :ok, 1 => "error in second", 2 => :ok},
               last_step: 2,
               last_step_idx: 2,
               halted_at_step: 1,
               async_steps: []
             } = extep
    end

    test "sets the halted_at_step for an async step `halt`" do
      extep = %Extep{}

      extep =
        extep
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.run(fn _context -> :halt end, async: true)
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.run(fn _context -> :ok end)

      assert %Extep{
               status: :halted,
               context: %{0 => :ok, 1 => :halt, 2 => :ok},
               last_step: 2,
               last_step_idx: 2,
               halted_at_step: 1,
               async_steps: []
             } = extep
    end

    test "sets the halted_at_step for an async step `{:halt, _}` tuple" do
      extep = %Extep{}

      extep =
        extep
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.run(fn _context -> {:halt, "halted in second"} end, async: true)
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.run(fn _context -> :ok end)

      assert %Extep{
               status: :halted,
               context: %{0 => :ok, 1 => "halted in second", 2 => :ok},
               last_step: 2,
               last_step_idx: 2,
               halted_at_step: 1,
               async_steps: []
             } = extep
    end
  end

  describe "run/4" do
    test "when function returns `:ok`" do
      extep = %Extep{status: :ok, context: %{}, last_step: nil, last_step_idx: nil}

      assert Extep.run(extep, :first, fn _context -> :ok end) == %Extep{
               status: :ok,
               context: %{:first => :ok},
               last_step: :first,
               last_step_idx: 0
             }
    end

    test "given the `set: :ctx_key` option, sets function return `:ok` to the given context key" do
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

    test "given the `set: :ctx_key` option, sets function return to the given context key" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0
      }

      assert Extep.run(extep, :second, fn _context -> {:ok, "second"} end, set: :foo) == %Extep{
               status: :ok,
               context: %{
                 :initial => "value",
                 0 => "first",
                 :second => {:set_to, :foo},
                 :foo => "second"
               },
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
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, :second, fn _context -> :halt end) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", :second => :halt},
               last_step: :second,
               last_step_idx: 1,
               halted_at_step: :second
             }
    end

    test "ignores `set: :ctx_key` option when function returns `:halt`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, :second, fn _context -> :halt end, set: :foo) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", :second => :halt},
               last_step: :second,
               last_step_idx: 1,
               halted_at_step: :second
             }
    end

    test "skips next steps when function returns `:halt`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      extep =
        extep
        |> Extep.run(:second, fn _context -> :halt end)
        |> Extep.run(:third, fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", :second => :halt},
               last_step: :second,
               last_step_idx: 1,
               halted_at_step: :second
             }
    end

    test "when function returns a `:halt` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, :second, fn _context -> {:halt, "halted in second"} end) == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", :second => "halted in second"},
               last_step: :second,
               last_step_idx: 1,
               halted_at_step: :second
             }
    end

    test "ignores `set: :ctx_key` option when function returns a `:halt` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, :second, fn _context -> {:halt, "halted in second"} end, set: :foo) ==
               %Extep{
                 status: :halted,
                 context: %{:initial => "value", 0 => "first", :second => "halted in second"},
                 last_step: :second,
                 last_step_idx: 1,
                 halted_at_step: :second
               }
    end

    test "skips next steps when function returns a `:halt` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      extep =
        extep
        |> Extep.run(:second, fn _context -> {:halt, "halted in second"} end)
        |> Extep.run(:third, fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :halted,
               context: %{:initial => "value", 0 => "first", :second => "halted in second"},
               last_step: :second,
               last_step_idx: 1,
               halted_at_step: :second
             }
    end

    test "when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, :second, fn _context -> :error end) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", :second => :error},
               last_step: :second,
               last_step_idx: 1,
               halted_at_step: :second
             }
    end

    test "ignores `set: :ctx_key` option when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, :second, fn _context -> :error end, set: :foo) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", :second => :error},
               last_step: :second,
               last_step_idx: 1,
               halted_at_step: :second
             }
    end

    test "skips next steps when function returns `:error`" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      extep =
        extep
        |> Extep.run(:second, fn _context -> :error end)
        |> Extep.run(:thitd, fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", :second => :error},
               last_step: :second,
               last_step_idx: 1,
               halted_at_step: :second
             }
    end

    test "when function returns a `:error` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, :second, fn _context -> {:error, "error in second"} end) == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", :second => "error in second"},
               last_step: :second,
               last_step_idx: 1,
               halted_at_step: :second
             }
    end

    test "ignores `set: :ctx_key` option when function returns an `{:error, _}` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      assert Extep.run(extep, :second, fn _context -> {:error, "error in second"} end, set: :foo) ==
               %Extep{
                 status: :error,
                 context: %{:initial => "value", 0 => "first", :second => "error in second"},
                 last_step: :second,
                 last_step_idx: 1,
                 halted_at_step: :second
               }
    end

    test "skips next steps when function returns a `:error` tuple" do
      extep = %Extep{
        status: :ok,
        context: %{:initial => "value", 0 => "first"},
        last_step: 0,
        last_step_idx: 0,
        halted_at_step: nil
      }

      extep =
        extep
        |> Extep.run(:second, fn _context -> {:error, "error in second"} end)
        |> Extep.run(:third, fn _context -> {:ok, "third"} end)

      assert extep == %Extep{
               status: :error,
               context: %{:initial => "value", 0 => "first", :second => "error in second"},
               last_step: :second,
               last_step_idx: 1,
               halted_at_step: :second
             }
    end

    test "raises `Extep.InvalidFunctionReturn` when function return is invalid" do
      extep = %Extep{status: :ok, context: %{}, last_step: nil, last_step_idx: nil}

      assert_raise Extep.InvalidFunctionReturn, fn ->
        Extep.run(extep, :first, fn _context -> :invalid_return end)
      end
    end
  end

  describe "run/4 with `async: true` option" do
    test "sets an async step to the `async_steps` key" do
      extep = %Extep{}

      assert %Extep{
               status: :ok,
               context: %{},
               last_step: :first,
               last_step_idx: 0,
               halted_at_step: nil,
               async_steps: [%Task{}]
             } = Extep.run(extep, :first, fn _context -> :ok end, async: true)
    end

    test "await and clear async_steps in the next sync step" do
      extep = %Extep{}

      extep =
        extep
        |> Extep.run(:first, fn _context -> :ok end, async: true)
        |> Extep.run(:second, fn _context -> :ok end, async: true)
        |> Extep.run(:third, fn _context -> :ok end)

      assert %Extep{
               status: :ok,
               context: %{:first => :ok, :second => :ok, :third => :ok},
               last_step: :third,
               last_step_idx: 2,
               async_steps: []
             } = extep
    end

    test "sets the halted_at_step for an async step error" do
      extep = %Extep{}

      extep =
        extep
        |> Extep.run(:first, fn _context -> :ok end, async: true)
        |> Extep.run(:second, fn _context -> :error end, async: true)
        |> Extep.run(:third, fn _context -> :ok end, async: true)
        |> Extep.run(:fourth, fn _context -> :ok end)

      assert %Extep{
               status: :error,
               context: %{:first => :ok, :second => :error, :third => :ok},
               last_step: :third,
               last_step_idx: 2,
               halted_at_step: :second,
               async_steps: []
             } = extep
    end

    test "sets the halted_at_step for an async step `{:error, _}` tuple" do
      extep = %Extep{}

      extep =
        extep
        |> Extep.run(:first, fn _context -> :ok end, async: true)
        |> Extep.run(:second, fn _context -> {:error, "error in second"} end, async: true)
        |> Extep.run(:third, fn _context -> :ok end, async: true)
        |> Extep.run(:fourth, fn _context -> :ok end)

      assert %Extep{
               status: :error,
               context: %{:first => :ok, :second => "error in second", :third => :ok},
               last_step: :third,
               last_step_idx: 2,
               halted_at_step: :second,
               async_steps: []
             } = extep
    end

    test "sets the halted_at_step for an async step halt" do
      extep = %Extep{}

      extep =
        extep
        |> Extep.run(:first, fn _context -> :ok end, async: true)
        |> Extep.run(:second, fn _context -> :halt end, async: true)
        |> Extep.run(:third, fn _context -> :ok end, async: true)
        |> Extep.run(:fourth, fn _context -> :ok end)

      assert %Extep{
               status: :halted,
               context: %{:first => :ok, :second => :halt, :third => :ok},
               last_step: :third,
               last_step_idx: 2,
               halted_at_step: :second,
               async_steps: []
             } = extep
    end

    test "sets the halted_at_step for an async step `{:halt, _}` tuple" do
      extep = %Extep{}

      extep =
        extep
        |> Extep.run(:first, fn _context -> :ok end, async: true)
        |> Extep.run(:second, fn _context -> {:halt, "halted in second"} end, async: true)
        |> Extep.run(:third, fn _context -> :ok end, async: true)
        |> Extep.run(:fourth, fn _context -> :ok end)

      assert %Extep{
               status: :halted,
               context: %{:first => :ok, :second => "halted in second", :third => :ok},
               last_step: :third,
               last_step_idx: 2,
               halted_at_step: :second,
               async_steps: []
             } = extep
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
        last_step_idx: 1,
        halted_at_step: :second
      }

      assert Extep.return(extep) == {:ok, "halted in second"}
    end

    test "returns `:error` atom when the `%Extep{}` status is `:error`" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: :error},
        last_step: :second,
        last_step_idx: 1,
        halted_at_step: :second
      }

      assert Extep.return(extep) == :error
    end

    test "given the `label_error: true` option, returns an error tuple with the step name" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: :error},
        last_step: :second,
        last_step_idx: 1,
        halted_at_step: :second
      }

      assert Extep.return(extep, label_error: true) == {:error, %{second: :error}}
    end

    test "returns an error tuple when the `%Extep{}` status is `:error`" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: "error in second"},
        last_step: :second,
        last_step_idx: 1,
        halted_at_step: :second
      }

      assert Extep.return(extep) == {:error, "error in second"}
    end

    test "given the `label_error: true` option, returns a labeled error tuple" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: "error in second"},
        last_step: :second,
        last_step_idx: 1,
        halted_at_step: :second
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
        last_step_idx: 1,
        halted_at_step: :second
      }

      assert Extep.return(extep, :third, label_error: true) == {:error, %{second: :error}}
    end

    test "returns the halted value when `%Extep{}` status is `:halted`" do
      extep = %Extep{
        status: :halted,
        context: %{first: "first", second: "halted in second"},
        last_step: :second,
        last_step_idx: 1,
        halted_at_step: :second
      }

      assert Extep.return(extep, :third) == {:ok, "halted in second"}
    end

    test "returns an error tuple when the `%Extep{}` status is `:error`" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: "error in second"},
        last_step: :second,
        last_step_idx: 1,
        halted_at_step: :second
      }

      assert Extep.return(extep, :third) == {:error, "error in second"}
    end

    test "given the `label_error: true` option, returns a labeled error tuple" do
      extep = %Extep{
        status: :error,
        context: %{first: "first", second: "error in second"},
        last_step: :second,
        last_step_idx: 1,
        halted_at_step: :second
      }

      assert Extep.return(extep, :third, label_error: true) ==
               {:error, %{second: "error in second"}}
    end
  end

  describe "full flow - steps without names - last step async - return without index" do
    test "returns the last step when it's `:ok`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.return()

      assert extep == :ok
    end

    test "returns the last step when it's an `{:ok, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return()

      assert extep == {:ok, "step two result with initial state"}
    end

    test "when an async step returns `:error`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> :error end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return()

      assert extep == :error
    end

    test "when an async step returns `:error` and `label_error` option is set" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> :error end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(label_error: true)

      assert extep == {:error, %{0 => :error}}
    end

    test "when an async step returns an `{:error, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> {:error, "step one error"} end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return()

      assert extep == {:error, "step one error"}
    end

    test "when an async step returns an `{:error, _}` tuple and `label_error` option is set" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> {:error, "step one error"} end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(label_error: true)

      assert extep == {:error, %{0 => "step one error"}}
    end

    test "when an async step returns `:halt`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn _context -> :halt end, async: true)
        |> Extep.return()

      assert extep == :ok
    end

    test "when an async step returns an `{:halt, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn _context -> {:halt, "step two halted"} end, async: true)
        |> Extep.return()

      assert extep == {:ok, "step two halted"}
    end
  end

  describe "full flow - steps without names - last step async - return with index" do
    test "returns the last step when it's `:ok`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn _context -> :ok end, async: true)
        |> Extep.return(0)

      assert extep == {:ok, "step one result with initial state"}
    end

    test "returns the last step when it's an `{:ok, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(1)

      assert extep == {:ok, "step two result with initial state"}
    end

    test "when an async step returns `:error`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> :error end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(1)

      assert extep == :error
    end

    test "when an async step returns `:error` and `label_error` option is set" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> :error end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(1, label_error: true)

      assert extep == {:error, %{0 => :error}}
    end

    test "when an async step returns an `{:error, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> {:error, "step one error"} end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(1)

      assert extep == {:error, "step one error"}
    end

    test "when an async step returns an `{:error, _}` tuple and `label_error` option is set" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> {:error, "step one error"} end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(1, label_error: true)

      assert extep == {:error, %{0 => "step one error"}}
    end

    test "when an async step returns `:halt`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn _context -> :halt end, async: true)
        |> Extep.return(1)

      assert extep == :ok
    end

    test "when an async step returns an `{:halt, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn _context -> {:halt, "step two halted"} end, async: true)
        |> Extep.return(1)

      assert extep == {:ok, "step two halted"}
    end
  end

  describe "full flow - steps without names - last step sync - return without index" do
    test "returns the last step when it's `:ok`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn _context -> :ok end)
        |> Extep.return()

      assert extep == :ok
    end

    test "returns the last step when it's an `{:ok, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end)
        |> Extep.return()

      assert extep == {:ok, "step two result with initial state"}
    end

    test "when an async step returns `:error`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> :error end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end)
        |> Extep.return()

      assert extep == :error
    end

    test "when an async step returns `:error` and `label_error` option is set" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> :error end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end)
        |> Extep.return(label_error: true)

      assert extep == {:error, %{0 => :error}}
    end

    test "when an async step returns an `{:error, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> {:error, "step one error"} end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end)
        |> Extep.return()

      assert extep == {:error, "step one error"}
    end

    test "when an async step returns an `{:error, _}` tuple and `label_error` option is set" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn _context -> {:error, "step one error"} end, async: true)
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end)
        |> Extep.return(label_error: true)

      assert extep == {:error, %{0 => "step one error"}}
    end

    test "when an async step returns `:halt`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn _context -> :halt end)
        |> Extep.return()

      assert extep == :ok
    end

    test "when an async step returns an `{:halt, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.run(fn _context -> {:halt, "step two halted"} end)
        |> Extep.return()

      assert extep == {:ok, "step two halted"}
    end
  end

  describe "full flow - steps with names - last step async - return without step name" do
    test "returns the last step when it's `:ok`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(:second, fn _context -> :ok end, async: true)
        |> Extep.return()

      assert extep == :ok
    end

    test "returns the last step when it's an `{:ok, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return()

      assert extep == {:ok, "step two result with initial state"}
    end

    test "when an async step returns `:error`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> :error end, async: true)
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return()

      assert extep == :error
    end

    test "when an async step returns `:error` and `label_error` option is set" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> :error end, async: true)
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(label_error: true)

      assert extep == {:error, %{first: :error}}
    end

    test "when an async step returns an `{:error, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> {:error, "step one error"} end, async: true)
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return()

      assert extep == {:error, "step one error"}
    end

    test "when an async step returns an `{:error, _}` tuple and `label_error` option is set" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> {:error, "step one error"} end, async: true)
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(label_error: true)

      assert extep == {:error, %{first: "step one error"}}
    end

    test "when an async step returns `:halt`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(:second, fn _context -> :halt end, async: true)
        |> Extep.return()

      assert extep == :ok
    end

    test "when an async step returns an `{:halt, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.run(:second, fn _context -> {:halt, "step two halted"} end, async: true)
        |> Extep.return()

      assert extep == {:ok, "step two halted"}
    end
  end

  describe "full flow - steps with names - last step async - return with step name" do
    test "returns the last step when it's `:ok`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(:second, fn _context -> :ok end, async: true)
        |> Extep.return(:first)

      assert extep == {:ok, "step one result with initial state"}
    end

    test "returns the last step when it's an `{:ok, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(:first)

      assert extep == {:ok, "step one result with initial state"}
    end

    test "when an async step returns `:error`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> :error end, async: true)
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(:second)

      assert extep == :error
    end

    test "when an async step returns `:error` and `label_error` option is set" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> :error end, async: true)
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(:second, label_error: true)

      assert extep == {:error, %{first: :error}}
    end

    test "when an async step returns an `{:error, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> {:error, "step one error"} end, async: true)
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(:second)

      assert extep == {:error, "step one error"}
    end

    test "when an async step returns an `{:error, _}` tuple and `label_error` option is set" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> {:error, "step one error"} end, async: true)
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(:second, label_error: true)

      assert extep == {:error, %{first: "step one error"}}
    end

    test "when an async step returns `:halt`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(:second, fn _context -> :halt end, async: true)
        |> Extep.return(:second)

      assert extep == :ok
    end

    test "when an async step returns an `{:halt, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.run(:second, fn _context -> {:halt, "step two halted"} end, async: true)
        |> Extep.return(:second)

      assert extep == {:ok, "step two halted"}
    end
  end

  describe "full flow - steps with names - last step sync - return with step name - with `:set` option" do
    test "returns custom ctx key when it's `:ok`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true,
          set: :custom_ctx_key
        )
        |> Extep.run(:second, fn _context -> :ok end, async: true)
        |> Extep.return(:custom_ctx_key)

      assert extep == {:ok, "step one result with initial state"}
    end

    test "overwrites and returns a step ctx_key when it's an `{:ok, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true
        )
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true,
          set: :initial
        )
        |> Extep.return(:initial)

      assert extep == {:ok, "step two result with initial state"}
    end

    test "when an async step returns `:error`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> :error end, async: true, set: :custom_ctx_key)
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(:custom_ctx_key)

      assert extep == :error
    end

    test "when an async step returns `:error` and `label_error` option is set, does not set the custom key" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> :error end, async: true, set: :custom_ctx_key)
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(:custom_ctx_key, label_error: true)

      assert extep == {:error, %{first: :error}}
    end

    test "when an async step returns an `{:error, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> {:error, "step one error"} end,
          async: true,
          set: :custom_ctx_key
        )
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(:custom_ctx_key)

      assert extep == {:error, "step one error"}
    end

    test "when an async step returns an `{:error, _}` tuple and `label_error` option is set, does not set the custom key" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(:first, fn _context -> {:error, "step one error"} end,
          async: true,
          set: :custome_ctx_key
        )
        |> Extep.run(
          :second,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true
        )
        |> Extep.return(:custome_ctx_key, label_error: true)

      assert extep == {:error, %{first: "step one error"}}
    end

    test "when an async step returns `:halt`" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step one result with #{initial}"} end,
          async: true,
          set: :custom_ctx_key
        )
        |> Extep.run(:second, fn _context -> :halt end, async: true)
        |> Extep.return(:custom_ctx_key)

      assert extep == :ok
    end

    test "when an async step returns an `{:halt, _}` tuple" do
      extep =
        %{initial: "initial state"}
        |> Extep.new()
        |> Extep.run(
          :first,
          fn %{initial: initial} -> {:ok, "step two result with #{initial}"} end,
          async: true,
          set: :custom_ctx_key
        )
        |> Extep.run(:second, fn _context -> {:halt, "step two halted"} end, async: true)
        |> Extep.return(:custom_ctx_key)

      assert extep == {:ok, "step two halted"}
    end
  end
end
