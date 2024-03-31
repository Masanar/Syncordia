defmodule Syncordian.Test_Git_Supervisor do
  @moduledoc """
    This module provides functionality for managing test edits in a Git repository.

    ## Usage

    1. Start the supervisor by calling `Syncordian.Test_Git_Supervisor.init/0`.
    2. The supervisor will parse the Git log and retrieve a list of commits.
    3. For each commit, the supervisor will retrieve the author and the position changes.
    4. The position changes will be applied to the corresponding peer using `parse_edits/2`.
    5. Finally, the supervisor will terminate all the processes.

    ## Functions

    - `parse_edit/2`: Parses a single edit and applies it to the specified peer.
    - `parse_edits/2`: Parses a list of edits and applies them to the specified peer.
    - `start_edits/4`: Starts the process of applying edits for a list of commits.
    - `init_peers/1`: Initializes the peers based on the list of authors.
    - `init/0`: Initializes the supervisor and starts the process of applying edits.
    - `kill/0`: Terminates all the processes started by the supervisor.

  """
  import Syncordian.Peer
  import Syncordian.Test_Git

  @doc """
    Parses a single edit and applies it to the specified peer.

    ## Parameters

    - `edit`: A map representing the edit to be parsed. It should contain the following
      keys:
      - `:op`: The operation to be performed. It can be `:insert` or `:delete`.
      - `:content`: The content to be inserted (required for `:insert` operation).
      - `:index`: The index of the line to be deleted (required for `:delete` operation).
    - `peer_pid`: The process identifier (PID) of the peer to apply the edit to.
  """
  def parse_edit(edit, peer_pid) do
    case Map.get(edit, :op) do
      :insert -> insert(peer_pid, Map.get(edit, :content), Map.get(edit, :index))
      :delete -> delete_line(peer_pid, Map.get(edit, :index))
    end
  end

  @doc """
    Parses a list of edits and applies them to the specified peer.
  """
  def parse_edits(edits, peer_pid) do
    Enum.each(edits, fn edit ->
      parse_edit(edit, peer_pid)
      Process.sleep(900)
    end)
  end

  @doc """
    Starts the process of applying edits for a list of commits.

    ## Parameters

    - `commits`: A list of commit hashes representing the commits to be processed.
    - `commit_group_map`: A map containing commit hashes as keys and commit groups as
      values. Each commit group should contain the following keys:
      - `:author_id`: The ID of the author who made the commit.
      - `:position_changes`: A list of position changes to be applied.
    - `map_peer_id_authors`: A map that maps author IDs(string) to peer IDs(integer).
    - `pid_list_author_peers`: A list of peer PIDs corresponding to each author
      ID(integer).

    The function loops through the commits in order, retrieves the corresponding commit
    group, and applies the position changes to the specified peer. The author ID is used
    to determine the peer ID, which is then used to retrieve the peer PID from the
    `pid_list_author_peers`. The position changes are applied using the `parse_edits/2`
    function.

  """
  def start_edits(commits, commit_group_map, map_peer_id_authors, pid_list_author_peers) do
    Enum.each(commits, fn commit_hash ->
      [commit_group] = Map.get(commit_group_map, commit_hash)
      author_id = Map.get(commit_group, :author_id)
      position_changes = Map.get(commit_group, :position_changes)
      peer_id = Map.get(map_peer_id_authors, author_id)
      peer_pid = Enum.at(pid_list_author_peers, peer_id)
      parse_edits(position_changes, peer_pid)
    end)

    Process.sleep(400)
    print_content(Enum.at(pid_list_author_peers,0))
    Process.sleep(400)
    print_content(Enum.at(pid_list_author_peers,1))
    Process.sleep(400)
    print_content(Enum.at(pid_list_author_peers,2))
    Process.sleep(400)
    print_content(Enum.at(pid_list_author_peers, 3))
    # raw_print(Enum.at(pid_list_author_peers,:rand.uniform(29)))
    Process.sleep(400)
  end

  @doc """
    Initializes the peers for the Syncordian system based on the list of authors.

    ## Parameters

    - `authors_list`: A list of author IDs representing the authors in the system.

    ## Returns

    A tuple containing two elements:
    - The list of peer PIDs in reverse order.
    - A map that maps author IDs(string) to peer IDs(integer).

    The function initializes the peers by creating a network of processes. Each author
    is assigned a unique peer ID, and a corresponding peer process is started. The
    author IDs are mapped to their respective peer IDs in the resulting map.

  """
  def init_peers(authors_list) do
    network_size = authors_list |> length()

    values =
      authors_list
      |> Enum.reduce({0, [], %{}}, fn author_id, {acc, add_pid, map_ids} ->
        {acc + 1, [start(acc, network_size) | add_pid], Map.put(map_ids, author_id, acc)}
      end)

    {elem(values, 1) |> Enum.reverse(), elem(values, 2)}
  end

  @doc """
    Initializes the supervisor and starts the process of applying edits.

    The function initializes the supervisor by parsing the Git log and retrieving the list
    of commits. It then groups the commits by author and starts the process of applying
    edits for each commit. Finally, it terminates all the processes started by the
    supervisor.

  """
  def init() do
    parsed_git_log = parser_git_log("test")
    list_of_commits = get_list_of_commits("test")
    commit_group_map = group_by_commit(parsed_git_log)

    ######## Temporary code to test the supervisor
    temporal_git_log = parser_git_log("ohmyzsh_README_git_log")
    {_, authors_list} = group_by_author(temporal_git_log)

    temp_authors_list = [
      Enum.at(authors_list, 0),
      Enum.at(authors_list, 1),
      Enum.at(authors_list, 2),
      Enum.at(authors_list, 17)
    ]

    # IO.inspect(authors_list)
    # IO.inspect(Enum.at(authors_list, 17))

    {pid_list_author_peers, map_peer_id_authors} = init_peers(temp_authors_list)
    # {pid_list_author_peers, map_peer_id_authors} = init_peers(authors_list)

    start_edits(list_of_commits, commit_group_map, map_peer_id_authors, pid_list_author_peers)
    kill()
  end

  @doc """
    Terminates all the processes started by the supervisor.
  """
  def kill do
    :global.registered_names()
    |> Enum.map(fn x -> :global.whereis_name(x) |> Process.exit(:kill) end)
  end
end