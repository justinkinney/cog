defmodule Probe.TolerantFile do
  require Logger

  @moduledoc """
  Encapsulates file path, inode, and file descriptor information
  together, allowing transparent writing to a given path in the face
  of file closing / moving.

  Supports the logging of data to files which will be rotated by
  another system process.

  *NOTE*: As currently coded, this is geared specifically toward the
  needs of Probe (e.g., files are opened in `append` mode, writing
  UTF8, etc.) and no attempt is made to create a complete and
  general-purpose tool.
  """

  @file_modes [:append, :sync, :raw]

  @typedoc """
  A file that is tolerant of the underlying filesystem device closing
  underneath it.

  # Fields

  * `path`: the absolute path to the file
  * `fd`: an open file descriptor to the file
  * `inode`: the inode of the file that `fd` is pointed at
  """
  @type t :: %__MODULE__{path: String.t,
                         fd: :file.fd,
                         inode: term}
  defstruct [path: nil,
             fd: nil,
             inode: nil]

  @doc """
  Constructor function.

  When given a file path, a new `#{inspect __MODULE__}` instance is
  created.

  When given a `#{inspect __MODULE__}` instance, if the underlying
  file is determined to have changed (the current inode associated
  with the path does not match the inode of the instance) the open
  file descriptor of the instance is closed and a "fresh" instance is
  returned, with a new open file descriptor.

  (Note that, depending on the environment, it is possible that the
  same inode will get reused between an "old" `#{inspect __MODULE__}`
  and one that has been "refreshed" in this way; we have observed this
  in Docker, for instance. This can happen if the underlying file has
  been deleted, and the `#{inspect __MODULE__}` re-creates it in the
  process of being refreshed. In such a situation, however, the file
  descriptor that is opened will be different.)

  Always opens files with the modes `#{inspect @file_modes}`. See
  `File.open/2` for details.
  """
  def open(path) when is_binary(path) do
    path = Path.expand(path)
    case File.open(path, @file_modes) do
      {:ok, fd} ->
        inode = File.stat!(path).inode
        {:ok, %__MODULE__{path: path, fd: fd, inode: inode}}
      {:error, _}=error ->
        error
    end
  end
  def open(%__MODULE__{}=file) do
    if changed?(file) do
      close(file)
      open(file.path)
    else
      {:ok, file}
    end
  end

  @doc """
  Closes the underlying file descriptor of `file`.
  """
  def close(%__MODULE__{}=file),
    do: File.close(file.fd)

  @doc """
  Appends `content` to `file`, respecting underlying file closings. A
  newline is appended after `content`.

  Returns a possibly-new instance of `#{inspect __MODULE__}` in case
  the underlying file has changed.
  """
  def puts(%__MODULE__{}=file, content) do
    {:ok, refreshed} = open(file)
    case do_put(refreshed.fd, content) do
      :ok ->
        {:ok, refreshed}
      {:error, _} = error ->
        Logger.warn("Failed to write to `#{refreshed.path}`: #{inspect error}; retrying the write one time")
        {:ok, refreshed_again} = open(refreshed)
        case do_put(refreshed_again.fd, content) do
          :ok ->
            Logger.info("Retried write to `#{refreshed_again.path}` succeeded")
            {:ok, refreshed_again}
          {:error, _} = error ->
            Logger.error("Retried write to `#{refreshed_again.path}` failed: #{inspect error}")
            error
        end
    end
  end

  # Ensure unicode and intervening newlines
  defp do_put(fd, content),
    do: :file.write(fd, to_string(content <> "\n"))

  @doc """
  Heuristically determine whether or not a TolerantFile still points
  to the same file on the filesystem, or if that file has been rotated
  out from under it.
  """
  def changed?(%__MODULE__{inode: inode, path: path}) do
    case File.stat(path) do
      {:ok, %File.Stat{inode: ^inode}} ->
        # We're still looking at the same file
        false
      {:ok, %File.Stat{}} ->
        # The file exists, but it's a different one from what we were
        # looking at originally
        true
      {:error, :enoent} ->
        # The file went away (so it definitely changed!)
        true
    end
  end

end
