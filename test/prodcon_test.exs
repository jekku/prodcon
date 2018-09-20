defmodule ProdconTest do
  use ExUnit.Case
  doctest Prodcon

  test "greets the world" do
    assert Prodcon.hello() == :world
  end
end
