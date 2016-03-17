defmodule Probe.TolerantFile.Test do
  use ExUnit.Case
  alias Probe.TolerantFile
  require Logger

  setup do
    new_empty_file = empty_file_path("tolerant_file.txt")
    on_exit(fn() -> File.rm_rf!(new_empty_file) end)
    {:ok, [path: new_empty_file]}
  end

  test "#open returns same instance if underlying file hasn't closed or moved", %{path: path} do
    {:ok, file} = TolerantFile.open(path)
    {:ok, refreshed} = TolerantFile.open(file)
    assert refreshed == file
  end

  test "#open returns different instance if underlying file has closed", %{path: path} do
    {:ok, original} = TolerantFile.open(path)
    File.rm!(path)
    {:ok, refreshed} = TolerantFile.open(original)

    # They point to the same file, but the internal details are
    # different
    refute original == refreshed
    assert original.path == refreshed.path
    refute original.fd == refreshed.fd
  end

  test "#open works when target file doesn't exist yet" do
    path = non_existent_file_path("easter_bunny.txt")
    refute File.exists?(path)

    {:ok, file} = TolerantFile.open(path)
    assert file.path == path
    assert File.exists?(path)
  end

  test "#open fails when target file exists but cannot be written to", %{path: path} do
    :ok = File.chmod(path, 0o100444) # file is read-only
    assert {:error, :eacces} == TolerantFile.open(path)
  end

  test "#open fails when the file does not exist and cannot be created" do
    dir = Path.join(System.tmp_dir!, "test_dir")
    :ok = File.mkdir!(dir)
    :ok = File.chmod(dir, 0o100444) # dir is read-only
    on_exit(fn() -> File.rm_rf!(dir) end)

    path = Path.join(dir, "cannot_create.txt")
    refute File.exists?(path)
    assert {:error, :eacces} = TolerantFile.open(path)
  end

  test "#puts works", %{path: path} do
    {:ok, file} = TolerantFile.open(path)
    TolerantFile.puts(file, "hello world")
    assert_content(path, ["hello world\n"])
  end

  test "#puts with intervening close works", %{path: path} do
    {:ok, file} = TolerantFile.open(path)
    TolerantFile.puts(file, "before close")
    File.rm!(path)
    TolerantFile.puts(file, "after close")
    assert_content(path, ["after close\n"])
  end

  test "#puts with intervening move works", %{path: original_path} do
    {:ok, file} = TolerantFile.open(original_path)
    TolerantFile.puts(file, "content before move")
    moved_path = move!(original_path, "move_test_file.txt")

    TolerantFile.puts(file, "content after move")
    assert_content(original_path, ["content after move\n"])
    assert_content(moved_path, ["content before move\n"])
  end

  test "#puts works with unicode characters", %{path: path} do
    {:ok, file} = TolerantFile.open(path)
    TolerantFile.puts(file, "My favorite character is 'þ'")
    assert_content(path, ["My favorite character is 'þ'\n"])
  end

  # Ensure a new, empty file named `basename` exists in a temporary
  # directory.
  defp empty_file_path(basename) do
    path = non_existent_file_path(basename)
    File.touch!(path)
    path
  end

  # Ensures that a file named `basename` does not exist in the
  # temporary directory. Returns the absolute path
  defp non_existent_file_path(basename) do
    path = Path.join(System.tmp_dir!, basename)
    File.rm_rf!(path)
    path
  end

  # Given the path to a file, assert that the lines of that file are
  # equal to `expected_lines`. Independent of any implementation
  # details of TolerantFile.
  defp assert_content(path, expected_lines) when is_binary(path) do
    lines = path |> File.stream! |> Enum.into([])
    assert lines == expected_lines
  end

  # Given a path to a file and a new basename, moves the contents from
  # the original to a new file named `basename` in the same directory.
  #
  # Returns the path of the new file.
  #
  # Example:
  #
  #     iex> move("/foo/bar/baz.txt", "hello_world.txt")
  #     "/foo/bar/hello_world.txt"
  #
  defp move!(original_path, new_basename) do
    dir = Path.dirname(original_path)
    new_path = Path.join(dir, new_basename)
    File.cp!(original_path, new_path)
    File.rm_rf!(original_path)
    new_path
  end
end
