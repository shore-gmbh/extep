defmodule Extep.InvalidFunctionReturn do
  defexception message: "The context modification function return is invalid. \
                          It must be on of `:ok`, {:ok, \"value\"}, `:halt`, \
                          {:halt, \"halt reason\"}, `:error` or {:error, \"error reason\"}"
end
