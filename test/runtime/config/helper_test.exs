defmodule Runtime.Config.Helper.Test do
  require Logger

  use ExUnit.Case

  import Mox

  @system_mock Runtime.Config.Helper.System.Wrapper.Mock

  alias Runtime.Config.Helper

  defmodule CustomValidator do
    def valid(value, _opt) do
      value
    end

    def invalid(_value, _opt) do
      {:error, "That is not what I expected!"}
    end
  end

  describe "get_env/2" do
    test "gets a string by default" do
      expect(@system_mock, :get_env, 1, fn _ -> "string_val" end)
      assert(Helper.get_env("STRING_VAR") == "string_val")
    end

    test "supports type :string" do
      expect(@system_mock, :get_env, 1, fn _ -> "string_val" end)
      assert(Helper.get_env("STRING_VAR", type: :string) == "string_val")
    end

    test "supports type :integer" do
      expect(@system_mock, :get_env, 1, fn _ -> "23" end)
      assert(Helper.get_env("INTEGER_VAR", type: :integer) == 23)
    end

    test "supports type :float" do
      expect(@system_mock, :get_env, 1, fn _ -> "3.14" end)
      assert(Helper.get_env("FLOAT_VAR", type: :float) == 3.14)
    end

    test "supports type :boolean" do
      expect(@system_mock, :get_env, 1, fn _ -> "true" end)
      assert(Helper.get_env("BOOLEAN_VAR", type: :boolean) == true)
    end

    test "supports type :atom" do
      expect(@system_mock, :get_env, 1, fn _ -> "atom" end)
      assert(Helper.get_env("ATOM_VAR", type: :atom) == :atom)
    end

    test "supports type :module" do
      expect(@system_mock, :get_env, 1, fn _ -> "Elixir.Runtime.Config.Helpers" end)
      assert(Helper.get_env("MODULE_VAR", type: :module) == Runtime.Config.Helpers)
    end

    test "supports type :charlist" do
      expect(@system_mock, :get_env, 1, fn _ -> "Mott the Hoople" end)
      assert(Helper.get_env("CHARLIST_VAR", type: :charlist) == 'Mott the Hoople')
    end

    test "supports type :list" do
      expect(@system_mock, :get_env, 2, fn _ -> "fish,cut,bait" end)
      assert(Helper.get_env("LIST_VAR", type: :list) == ["fish", "cut", "bait"])
      assert(Helper.get_env("LIST_VAR", type: :list, subtype: :string) == ["fish", "cut", "bait"])
    end

    test "supports type list of atoms" do
      expect(@system_mock, :get_env, 1, fn _ -> "fish,cut,bait" end)
      assert(Helper.get_env("LIST_VAR", type: :list, subtype: :atom) == [:fish, :cut, :bait])
    end

    test "supports type list of integers" do
      expect(@system_mock, :get_env, 1, fn _ -> "1,2,3" end)
      assert(Helper.get_env("LIST_VAR", type: :int_list) == [1, 2, 3])
    end

    test "supports type :tuple" do
      expect(@system_mock, :get_env, 2, fn _ -> "fish,cut,bait" end)
      assert(Helper.get_env("TUPLE_VAR", type: :tuple) == {"fish", "cut", "bait"})
      assert(Helper.get_env("TUPLE_VAR", type: :tuple, subtype: :string) == {"fish", "cut", "bait"})
    end

    test "supports type :atom_tuple" do
      expect(@system_mock, :get_env, 1, fn _ -> "fish,cut,bait" end)
      assert(Helper.get_env("TUPLE_VAR", type: :tuple, subtype: :atom) == {:fish, :cut, :bait})
    end

    test "supports type :int_tuple" do
      expect(@system_mock, :get_env, 1, fn _ -> "1,2,3" end)
      assert(Helper.get_env("TUPLE_VAR", type: :tuple, subtype: :integer) == {1, 2, 3})
    end

    test "supports default values for unset variables" do
      expect(@system_mock, :get_env, 6, fn _ -> nil end)
      assert(Helper.get_env("INTEGER_VAR", default: 17, type: :integer) == 17)
      assert(Helper.get_env("FLOAT_VAR", default: 98.6, type: :float) == 98.6)
      assert(Helper.get_env("BOOLEAN_VAR", default: true, type: :boolean) == true)
      assert(Helper.get_env("ATOM_VAR", default: :ant, type: :atom) == :ant)
      assert(Helper.get_env("MODULE_VAR", default: Runtime.Config, type: :module) == Runtime.Config)
      assert(Helper.get_env("STRING_VAR", default: "narf", type: :string) == "narf")
      assert(Helper.get_env("LIST_VAR", default: ~w(winkin blinkin nod), type: :list) == ~w(winkin blinkin nod))
      assert(Helper.get_env("TUPLE_VAR", default: {"winkin", "blinkin", "nod"}, type: :tuple) == {"winkin", "blinkin", "nod"})
    end

    test "supports validation :in_set" do
      expect(@system_mock, :get_env, 4, fn _ -> "2" end)
      assert(Helper.get_env("STRING_VAR", in_set: ~w(1 2 3)) == "2")
      assert({:error, _} = Helper.get_env("STRING_VAR", in_set: ~w(nope not in there)))
      assert(Helper.get_env("INTEGER_VAR", type: :integer, in_set: [1, 2, 3]) == 2)
      assert({:error, _} = Helper.get_env("INTEGER_VAR", type: :integer, in_set: [1, 0, 3]))

      expect(@system_mock, :get_env, 2, fn _ -> "2.0" end)
      assert(Helper.get_env("FLOAT_VAR", type: :float, in_set: [1.0, 2.0, 3.0]) == 2.0)
      assert({:error, _} = Helper.get_env("FLOAT_VAR", type: :float, in_set: [1.0, 0.0, 3.0]))
    end

    test "supports validation :in_range" do
      expect(@system_mock, :get_env, 2, fn _ -> "23" end)
      assert(Helper.get_env("INTEGER_VAR", type: :integer, in_range: 1..100) == 23)
      assert({:error, _} = Helper.get_env("INTEGER_VAR", type: :integer, in_range: 50..100))
    end

    test "supports validation :regex" do
      expect(@system_mock, :get_env, 2, fn _ -> "string_val" end)
      assert(Helper.get_env("STRING_VAR", type: :string, regex: ~r/^.*_val$/) == "string_val")
      assert({:error, _} = Helper.get_env("STRING_VAR", type: :string, regex: ~r/^.*_flurshinger$/))
    end

    test "supports custom validation" do
      expect(@system_mock, :get_env, 2, fn _ -> "string_val" end)
      assert(Helper.get_env("STRING_VAR", custom: {CustomValidator, :valid}) == "string_val")
      assert({:error, _} = Helper.get_env("STRING_VAR", custom: {CustomValidator, :invalid}))
    end

    test "returns nil if no default given, variable is unset in the environment and no validations are specified" do
      expect(@system_mock, :get_env, 1, fn _ -> nil end)
      assert(is_nil(Helper.get_env("UNDEFINED_VAR")))
    end
  end

  describe "determine_type/1" do
    test "type defaults to string" do
      assert(Helper.determine_type([]) == :string)
    end

    test "is float if default value is float" do
      assert(Helper.determine_type(default: 3.14) == :float)
    end

    test "is integer if default value is integer" do
      assert(Helper.determine_type(default: 3) == :integer)
    end

    test "is boolean if default value is boolean" do
      assert(Helper.determine_type(default: true) == :boolean)
      assert(Helper.determine_type(default: false) == :boolean)
    end

    test "is atom if default value is atom" do
      assert(Helper.determine_type(default: :atomic) == :atom)
    end

    test "is module if default value is a module" do
      assert(Helper.determine_type(default: Application.Config.Helper) == :module)
    end

    test "is list if default value is a list" do
      assert(Helper.determine_type(default: ~w(one two three)) == :list)
    end

    test "is tuple if default value is a tuple" do
      assert(Helper.determine_type(default: {1, 2, 3}) == :tuple)
    end

    test "is type of first in_set element if in_set validation provided" do
      assert(Helper.determine_type(in_set: ~w(a b c)) == :string)
      assert(Helper.determine_type(in_set: [:alpha, :beta]) == :atom)
      assert(Helper.determine_type(in_set: [1, 2]) == :integer)
      assert(Helper.determine_type(in_set: [1.1, 1.2]) == :float)
    end
  end
end
