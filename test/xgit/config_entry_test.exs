defmodule Xgit.ConfigEntryTest do
  use ExUnit.Case, async: true

  alias Xgit.ConfigEntry

  @valid_sections ["test", "Test", "test-24", "test-2.3", nil]
  @invalid_sections ["", 'test', "", "test 24", "test:24", "test/more-test", 42, :test]

  @valid_subsections ["xgit", "", "xgit and more xgit", "test:24", "test/more-test", nil]
  @invalid_subsections ["xg\nit", "xg\0it", 'xgit', 42, :test]

  @valid_names ["random", "Random", "random9", "random-9"]
  @invalid_names ["", "9random", "random.24", "random:24", 42, nil, :test]

  @valid_values ["whatever", "", nil]
  @invalid_values ["what\0ever", 'whatever', 42, true, false, :test]

  @valid_entry %ConfigEntry{
    section: "test",
    subsection: "xgit",
    name: "random",
    value: "whatever"
  }

  describe "valid?/1" do
    test "valid cases" do
      for section <- @valid_sections do
        for subsection <- @valid_subsections do
          for name <- @valid_names do
            for value <- @valid_values do
              entry = %ConfigEntry{
                section: section,
                subsection: subsection,
                name: name,
                value: value
              }

              assert ConfigEntry.valid?(entry),
                     "improperly rejected valid case #{inspect(entry, pretty: true)}"
            end
          end
        end
      end
    end

    test "not a struct" do
      refute ConfigEntry.valid?(%{
               section: "test",
               subsection: "xgit",
               name: "random",
               value: "whatever"
             })

      refute ConfigEntry.valid?("[test] random=whatever")
    end

    test "invalid section" do
      for section <- @invalid_sections do
        entry = %{@valid_entry | section: section}

        refute ConfigEntry.valid?(entry),
               "improperly accepted invalid case #{inspect(entry, pretty: true)}"
      end
    end

    test "invalid subsection" do
      for subsection <- @invalid_subsections do
        entry = %{@valid_entry | subsection: subsection}

        refute ConfigEntry.valid?(entry),
               "improperly accepted invalid case #{inspect(entry, pretty: true)}"
      end
    end

    test "invalid name" do
      for name <- @invalid_names do
        entry = %{@valid_entry | name: name}

        refute ConfigEntry.valid?(entry),
               "improperly accepted invalid case #{inspect(entry, pretty: true)}"
      end
    end

    test "invalid value" do
      for value <- @invalid_values do
        entry = %{@valid_entry | value: value}

        refute ConfigEntry.valid?(entry),
               "improperly accepted invalid case #{inspect(entry, pretty: true)}"
      end
    end
  end

  describe "valid_section?/1" do
    test "valid section names" do
      for section <- @valid_sections do
        assert ConfigEntry.valid_section?(section),
               "improperly rejected valid case #{inspect(section)}"
      end
    end

    test "invalid section names" do
      for section <- @invalid_sections do
        refute ConfigEntry.valid_section?(section),
               "improperly accepted invalid case #{inspect(section)}"
      end
    end
  end

  describe "valid_subsection?/1" do
    test "valid subsection names" do
      for subsection <- @valid_subsections do
        assert ConfigEntry.valid_subsection?(subsection),
               "improperly rejected valid case #{inspect(subsection)}"
      end
    end

    test "invalid subsection names" do
      for subsection <- @invalid_subsections do
        refute ConfigEntry.valid_subsection?(subsection),
               "improperly accepted invalid case #{inspect(subsection)}"
      end
    end
  end

  describe "valid_name?/1" do
    test "valid names" do
      for name <- @valid_names do
        assert ConfigEntry.valid_name?(name),
               "improperly rejected valid case #{inspect(name)}"
      end
    end

    test "invalid names" do
      for name <- @invalid_names do
        refute ConfigEntry.valid_name?(name),
               "improperly accepted invalid case #{inspect(name)}"
      end
    end
  end

  describe "valid_value?/1" do
    test "valid values" do
      for value <- @valid_values do
        assert ConfigEntry.valid_value?(value),
               "improperly rejected valid case #{inspect(value)}"
      end
    end

    test "invalid values" do
      for value <- @invalid_values do
        refute ConfigEntry.valid_value?(value),
               "improperly accepted invalid case #{inspect(value)}"
      end
    end
  end
end
