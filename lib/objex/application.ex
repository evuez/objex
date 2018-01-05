defmodule Objex.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Registry, [:unique, Objex.Registry]),
    ]

    opts = [strategy: :one_for_one, name: Objex.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
