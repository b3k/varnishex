defmodule Varnishex do
  use GenServer

  @initial_state %{socket: nil, host: 'localhost', port: 6082, secret: "1q2w3e4r\n"}

  def start_link(args \\ %{}) do
    GenServer.start_link(__MODULE__, args)
  end

  def init(args) do
    opts = [:binary, active: false]
    args = Map.merge(@initial_state, args)

    {:ok, socket} = :gen_tcp.connect(args.host, args.port, opts)
    args = %{args | socket: socket}

    {:ok, _} = banner(args)

    {:ok, args}
  end

  def command(pid, cmd) do
    GenServer.call(pid, {:command, cmd})
  end

  def handle_call({:command, cmd}, from, %{socket: socket} = state) do
    {:ok, send_command(socket, cmd), state}
  end

  defp banner(args) do
    {:ok, code, message} = read(args.socket)
    if code == 107 do
      authorize(args, message)
    end
    {:ok, args}
  end

  defp authorize(args, message) do
    challenge = String.slice(message, 0, 32)
    auth_hash = :crypto.hash(:sha256, challenge <> "\n" <> args.secret <> challenge <> "\n")
    |> Base.encode16
    |> String.downcase

    {:ok, 200, _} = send_command(args.socket, "auth " <> auth_hash)
  end

  defp decode(response) do
    [header, code, length] = Regex.run(~r/^(\d{3}) (\d+)\s{0,8}\n/, response)
    message = String.slice(response, String.length(header), length)
    {:ok, String.to_integer(code), message}
  end

  defp encode(msg) do
    msg <> "\n"
  end

  defp send_command(socket, cmd) do
    :ok = :gen_tcp.send(socket, encode(cmd))
    read(socket)
  end

  defp read_socket(socket, length \\ 0) do
    :gen_tcp.recv(socket, length)
  end

  defp read(socket) do
    {:ok, msg} = read_socket(socket)
    decode(msg)
  end

end
